.dates_unknown <- function(metadata) {
  isTRUE(metadata$datesInUnknownTimezone) ||
    tolower(metadata$dateFieldsTimeReference$timeZone %||% "") %in% c("unknown", "unspecified")
}

arcgis_parse <- function(features, metadata, fields) {
  schema <- metadata$fields[match(fields, .field_names(metadata))]
  unknown_dates <- .dates_unknown(metadata)
  edit_fields <- metadata[["editFieldsInfo", exact = TRUE]]
  if (!is.list(edit_fields)) edit_fields <- list()
  utc_editor_dates <- vapply(c("creationDateField", "editDateField"), function(name) {
    value <- edit_fields[[name, exact = TRUE]]
    if (is.character(value) && length(value) == 1L && !is.na(value) && nzchar(value)) {
      value
    } else {
      NA_character_
    }
  }, character(1))
  utc_editor_dates <- unname(utc_editor_dates[!is.na(utc_editor_dates)])
  raw_date <- vapply(schema, function(field) {
    identical(field$type, "esriFieldTypeDate") && !field$name %in% utc_editor_dates
  }, logical(1))
  if (unknown_dates && any(raw_date)) {
    warning("The source declares an unknown date time zone. Date fields other than UTC editor tracking fields remain raw epoch milliseconds; no UTC instant was assigned to them.", call. = FALSE)
  }
  cols <- lapply(schema, function(field) {
    .parse_arcgis_column(field, features,
                         unknown_dates = unknown_dates && !field$name %in% utc_editor_dates)
  })
  names(cols) <- fields
  tibble::as_tibble(cols, .name_repair = "minimal")
}

.parse_arcgis_column <- function(field, features, unknown_dates) {
  values <- lapply(features, function(x) x[["attributes", exact = TRUE]][[field$name]])
  missing <- vapply(values, is.null, logical(1))
  present <- values[!missing]
  if (any(lengths(present) != 1L) || any(vapply(present, is.list, logical(1)))) {
    if (field$type %in% c("esriFieldTypeBlob", "esriFieldTypeRaster", "esriFieldTypeXML")) return(values)
    .abort(paste0("Field `", field$name, "` contains nonscalar attributes."), subclass = "tampa_response_error")
  }

  strings <- c("esriFieldTypeString", "esriFieldTypeGUID", "esriFieldTypeGlobalID",
               "esriFieldTypeTimeOnly", "esriFieldTypeTimestampOffset", "esriFieldTypeDateOnly")
  numbers <- c("esriFieldTypeOID", "esriFieldTypeSmallInteger", "esriFieldTypeInteger",
               "esriFieldTypeSingle", "esriFieldTypeDouble", "esriFieldTypeDate")
  if (field$type %in% strings) {
    if (any(!vapply(present, is.character, logical(1)))) {
      .abort(paste0("Field `", field$name, "` does not match its declared string type."), subclass = "tampa_response_error")
    }
    result <- rep(NA_character_, length(values))
    result[!missing] <- unlist(present, use.names = FALSE)
    if (field$type == "esriFieldTypeDateOnly") return(.parse_arcgis_date_only(result, field$name))
    return(result)
  }
  if (field$type %in% numbers) {
    if (any(!vapply(present, is.numeric, logical(1)))) {
      .abort(paste0("Field `", field$name, "` does not match its declared numeric type."), subclass = "tampa_response_error")
    }
    result <- rep(NA_real_, length(values))
    result[!missing] <- unlist(present, use.names = FALSE)
    if (any(!is.na(result) & !is.finite(result))) .abort(paste0("Field `", field$name, "` contains nonfinite numbers."))
    if (field$type == "esriFieldTypeDate" && !unknown_dates) {
      return(as.POSIXct(result / 1000, origin = "1970-01-01", tz = "UTC"))
    }
    if (field$type %in% c("esriFieldTypeOID", "esriFieldTypeSmallInteger", "esriFieldTypeInteger")) {
      return(.parse_arcgis_integer(result, field$name))
    }
    return(result)
  }
  if (field$type == "esriFieldTypeBigInteger") {
    result <- rep(NA_character_, length(values))
    result[!missing] <- .parse_arcgis_big_integer(present, field$name)
    return(result)
  }
  # Preserve uncommon source types rather than guessing their meaning.
  values
}

.parse_arcgis_date_only <- function(values, name) {
  message <- paste0("Invalid date-only field `", name, "`.")
  if (any(!is.na(values) & !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", values))) .abort(message)
  parsed <- tryCatch(as.Date(values), error = function(e) .abort(message))
  if (any(!is.na(values) & (is.na(parsed) | format(parsed, "%Y-%m-%d") != values))) .abort(message)
  parsed
}

.parse_arcgis_integer <- function(values, name) {
  if (any(abs(values) > 2^53 - 1, na.rm = TRUE)) {
    .abort(paste0("Field `", name, "` exceeds exact JSON/R integer precision."))
  }
  if (any(values != floor(values), na.rm = TRUE)) .abort(paste0("Field `", name, "` contains fractional integers."))
  if (all(is.na(values) | (values <= .Machine$integer.max & values >= -.Machine$integer.max))) {
    return(as.integer(values))
  }
  values
}

.parse_arcgis_big_integer <- function(values, name) {
  # Preserve exact JSON string values without an integer64 dependency.
  if (any(vapply(values, function(x) is.numeric(x) &&
      (!is.finite(x) || x != floor(x)), logical(1)))) {
    .abort(paste0("Invalid big-integer field `", name, "`."))
  }
  if (any(vapply(values, function(x) is.numeric(x) && abs(x) > 2^53 - 1, logical(1)))) {
    .abort(paste0("Field `", name, "` exceeds exact JSON/R numeric precision."))
  }
  result <- vapply(values, function(x) {
    if (is.numeric(x)) sprintf("%.0f", x) else as.character(x)
  }, character(1))
  if (any(!is.na(result) & !grepl("^-?[0-9]+$", result))) .abort(paste0("Invalid big-integer field `", name, "`."))
  result
}

# One filter contract for checked and discovered rows. Publisher/jurisdiction
# can also narrow the configured portal scan before any HTTP requests.
.catalog_filter_values <- function(x, name, choices = NULL) {
  if (is.null(x)) return(NULL)
  if (!is.character(x) || !length(x) || anyNA(x) || any(!nzchar(trimws(x)))) {
    .abort(paste0("`", name, "` must contain nonempty, nonmissing strings."),
           subclass = "tampa_input_error")
  }
  values <- unique(tolower(trimws(x)))
  if (!is.null(choices) && any(!values %in% choices)) {
    .abort(paste0("Unknown `", name, "`. Available: ",
                  paste(choices, collapse = ", "), "."),
           subclass = "tampa_input_error")
  }
  values
}

.catalog_date_bound <- function(x, name, upper = FALSE) {
  if (is.null(x)) return(NULL)
  invalid <- function() .abort(paste0("`", name,
    "` must be one valid Date, UTC calendar date (YYYY-MM-DD), or POSIXct instant."),
    subclass = "tampa_input_error")
  day <- inherits(x, "Date") || is.character(x)
  if (length(x) != 1L || anyNA(x)) invalid()
  if (is.character(x)) {
    if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)) invalid()
    parsed <- tryCatch(as.Date(x), error = function(e) as.Date(NA))
    if (is.na(parsed) || !identical(format(parsed, "%Y-%m-%d"), x)) invalid()
    x <- parsed
  }
  if (!inherits(x, c("Date", "POSIXct")) || !is.finite(as.numeric(x))) invalid()
  seconds <- if (day) as.numeric(x) * 86400 else as.numeric(x)
  list(seconds = seconds + if (day && upper) 86400 else 0,
       exclusive = day && upper)
}

.catalog_filters <- function(jurisdiction, publisher, validation_status, spatial,
                             topic, category, modified_after, modified_before,
                             entries, configs) {
  jurisdictions <- .catalog_filter_values(jurisdiction, "jurisdiction")
  supported <- unique(c(vapply(entries, `[[`, character(1), "jurisdiction"),
                         vapply(configs, `[[`, character(1), "jurisdiction")))
  if (identical(jurisdictions, "all")) {
    jurisdictions <- NULL
  } else if (any(!jurisdictions %in% supported)) {
    .abort(paste0("Unsupported jurisdiction. Available: ",
                  paste(c(supported, "all"), collapse = ", "), "."),
           subclass = "tampa_input_error")
  }
  if (!is.null(spatial)) .flag(spatial, "spatial")
  after <- .catalog_date_bound(modified_after, "modified_after")
  before <- .catalog_date_bound(modified_before, "modified_before", upper = TRUE)
  if (!is.null(after) && !is.null(before) &&
      (after$seconds > before$seconds ||
       (before$exclusive && after$seconds == before$seconds))) {
    .abort("`modified_after` must not be later than `modified_before`.",
           subclass = "tampa_input_error")
  }
  list(jurisdiction = jurisdictions,
       publisher = .catalog_filter_values(publisher, "publisher"),
       validation_status = .catalog_filter_values(validation_status,
         "validation_status", c("checked", "discovered")),
       spatial = spatial, topic = .catalog_filter_values(topic, "topic"),
       category = .catalog_filter_values(category, "category"),
       modified_after = after, modified_before = before)
}

.catalog_selected_portals <- function(keys, configs, filters) {
  selected <- configs[keys]
  keep <- rep(TRUE, length(selected))
  if (!is.null(filters$jurisdiction)) {
    keep <- keep & vapply(selected, `[[`, character(1), "jurisdiction") %in%
      filters$jurisdiction
  }
  if (!is.null(filters$publisher)) {
    keep <- keep & tolower(vapply(selected, `[[`, character(1), "publisher")) %in%
      filters$publisher
  }
  keys[keep]
}

.catalog_row_topics <- function(catalog, i) {
  values <- c(catalog$tags[[i]], catalog$categories[[i]], catalog$category[[i]])
  unique(tolower(values[!is.na(values)]))
}

.filter_catalog <- function(catalog, filters) {
  keep <- rep(TRUE, nrow(catalog))
  for (name in c("jurisdiction", "publisher", "validation_status")) {
    if (!is.null(filters[[name]])) {
      keep <- keep & tolower(catalog[[name]]) %in% filters[[name]]
    }
  }
  if (!is.null(filters$spatial)) {
    geometry <- catalog$geometry_type
    known <- !is.na(geometry) & nzchar(geometry)
    keep <- keep & known & if (filters$spatial) geometry != "none" else geometry == "none"
  }
  if (!is.null(filters$topic)) {
    keep <- keep & vapply(seq_len(nrow(catalog)), function(i) {
      values <- .catalog_row_topics(catalog, i)
      any(vapply(filters$topic, function(word) any(grepl(word, values, fixed = TRUE)),
                  logical(1)))
    }, logical(1))
  }
  if (!is.null(filters$category)) {
    keep <- keep & vapply(seq_len(nrow(catalog)), function(i) {
      values <- tolower(c(catalog$categories[[i]], catalog$category[[i]]))
      labels <- sub("^.*/", "", sub("/+$", "", values))
      any(c(values, labels) %in% filters$category)
    }, logical(1))
  }
  modified <- as.numeric(catalog$modified)
  if (!is.null(filters$modified_after)) {
    keep <- keep & !is.na(modified) & modified >= filters$modified_after$seconds
  }
  if (!is.null(filters$modified_before)) {
    bound <- filters$modified_before
    earlier <- if (bound$exclusive) modified < bound$seconds else modified <= bound$seconds
    keep <- keep & !is.na(modified) & earlier
  }
  catalog[keep %in% TRUE, , drop = FALSE]
}

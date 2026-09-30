.read_registry <- function() {
  path <- system.file("extdata", "datasets.json", package = "tampaBayOpenData")
  if (!nzchar(path)) .abort("The bundled dataset registry is missing. Reinstall the package.")
  entries <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
                      error = function(e) .abort("The bundled dataset registry is invalid JSON."))
  .validate_registry(entries)
  entries
}

.validate_registry <- function(entries) {
  required <- c("id", "title", "description", "jurisdiction", "publisher",
                "source_url", "service_url", "layer_id", "geometry_type",
                "date_fields", "category", "tags", "verified", "terms")
  if (!is.list(entries) || !length(entries)) .abort("The dataset registry must contain records.")
  for (entry in entries) {
    if (!is.list(entry) || !all(required %in% names(entry))) {
      .abort("A registry record is missing required metadata.")
    }
    strings <- setdiff(required, c("layer_id", "date_fields", "tags"))
    for (name in strings) .string(entry[[name]], paste0("registry.", name), allow_empty = name == "description")
    if (!grepl("^[a-z][a-z0-9]*(-[a-z0-9]+)*$", entry$id)) .abort("Registry IDs must be stable hyphenated slugs.")
    .number(entry$layer_id, "registry.layer_id", integer = TRUE)
    if (entry$layer_id > .Machine$integer.max) {
      .abort("`registry.layer_id` must fit in an R integer.")
    }
    if (!grepl("^https://[^?#]+/(FeatureServer|MapServer)$", entry$service_url)) {
      .abort("Registry service URLs must be HTTPS ArcGIS service roots.")
    }
    if (!grepl("^https://", entry$source_url)) .abort("Registry source pages must use HTTPS.")
    if (!entry$geometry_type %in% c("esriGeometryPoint", "esriGeometryMultipoint",
                                   "esriGeometryPolyline", "esriGeometryPolygon", "none")) {
      .abort("Unrecognized registry geometry type.")
    }
    date <- tryCatch(as.Date(entry$verified), error = function(e) NA)
    if (is.na(date) || format(date, "%Y-%m-%d") != entry$verified) .abort("Registry verification dates must use YYYY-MM-DD.")
    for (name in c("date_fields", "tags")) {
      value <- entry[[name]]
      if (!is.list(value) || !is.null(names(value)) ||
          !all(vapply(value, function(x) is.character(x) && length(x) == 1L &&
                        !is.na(x) && nzchar(x), logical(1)))) {
        .abort(paste0("Registry `", name, "` must be an array of nonmissing strings."))
      }
    }
  }
  keys <- vapply(entries, function(x) paste(x$jurisdiction, x$id, sep = "/"), character(1))
  if (anyDuplicated(keys)) .abort("Registry dataset IDs must be unique within each jurisdiction.")
  invisible(entries)
}

.jurisdiction_entries <- function(jurisdiction, entries = .read_registry()) {
  .string(jurisdiction, "jurisdiction")
  supported <- unique(vapply(entries, function(x) x$jurisdiction, character(1)))
  if (!jurisdiction %in% supported) {
    .abort(paste0("Unsupported jurisdiction `", jurisdiction, "`. Available: ",
                  paste(supported, collapse = ", "), ". v0.1 supports the City of Tampa."),
           subclass = "tampa_input_error")
  }
  Filter(function(x) identical(x$jurisdiction, jurisdiction), entries)
}

.lookup_dataset <- function(id, jurisdiction = "tampa") {
  .string(id, "id")
  entries <- .jurisdiction_entries(jurisdiction)
  found <- Filter(function(x) identical(x$id, id), entries)
  if (!length(found)) {
    .abort(paste0("Unknown dataset `", id, "` for `", jurisdiction,
                  "`. Use list_datasets() or search_datasets() to find supported IDs."),
           subclass = "tampa_input_error")
  }
  entry <- found[[1L]]
  entry$tags <- unlist(entry$tags, use.names = FALSE) %||% character()
  entry$date_fields <- unlist(entry$date_fields, use.names = FALSE) %||% character()
  entry
}

.catalog_table <- function(entries) {
  scalar <- c("id", "title", "description", "jurisdiction", "publisher", "source_url",
              "service_url", "geometry_type", "category", "verified", "terms")
  cols <- lapply(scalar, function(name) vapply(entries, function(x) x[[name]], character(1)))
  names(cols) <- scalar
  cols$layer_id <- vapply(entries, function(x) as.integer(x$layer_id), integer(1))
  cols$date_fields <- lapply(entries, function(x) unlist(x$date_fields, use.names = FALSE) %||% character())
  cols$tags <- lapply(entries, function(x) unlist(x$tags, use.names = FALSE) %||% character())
  cols$verified <- as.Date(cols$verified)
  tibble::as_tibble(cols)
}

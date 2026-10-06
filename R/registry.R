.read_registry <- function() {
  path <- system.file("extdata", "datasets.json", package = "tampaBayOpenData")
  if (!nzchar(path)) .abort("The bundled dataset registry is missing. Reinstall the package.")
  entries <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
                      error = function(e) .abort("The bundled dataset registry is invalid JSON."))
  .validate_registry(entries)
  .attach_expected_schemas(entries, .read_expected_schemas())
}

.attach_expected_schemas <- function(entries, schemas) {
  keys <- vapply(entries, function(entry) {
    paste(entry$jurisdiction, entry$id, sep = "/")
  }, character(1))
  if (anyDuplicated(keys) || anyDuplicated(names(schemas)) ||
      !setequal(names(schemas), keys)) {
    .abort("The bundled expected schemas must match the checked dataset registry.")
  }
  for (i in seq_along(entries)) {
    schema <- schemas[[keys[[i]]]]
    .validate_expected_schema(schema)
    endpoint <- paste0(entries[[i]]$service_url, "/", entries[[i]]$layer_id)
    if (!identical(schema$endpoint, endpoint) ||
        !identical(schema$geometry_type, entries[[i]]$geometry_type) ||
        !identical(schema$object_id_field, entries[[i]]$object_id_field) ||
        !.same_schema_crs(schema$spatial_reference,
                          entries[[i]]$spatial_reference)) {
      .abort(paste0("The bundled expected schema for `", keys[[i]],
                    "` disagrees with the checked dataset registry."))
    }
    entries[[i]]$expected_schema <- schema
  }
  entries
}

.registry_required_fields <- function() {
  c("id", "title", "description", "jurisdiction", "publisher",
    "source_url", "service_url", "layer_id", "geometry_type",
    "date_fields", "category", "tags", "verified", "terms")
}

.validate_registry <- function(entries) {
  required <- .registry_required_fields()
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
  if (identical(jurisdiction, "all")) return(entries)
  if (!jurisdiction %in% supported) {
    .abort(paste0("Unsupported jurisdiction `", jurisdiction, "`. Available: ",
                  paste(c(supported, "all"), collapse = ", "), "."),
           subclass = "tampa_input_error")
  }
  Filter(function(x) identical(x$jurisdiction, jurisdiction), entries)
}

.lookup_dataset <- function(id, jurisdiction = "all") {
  .string(id, "id")
  entries <- .jurisdiction_entries(jurisdiction)
  found <- Filter(function(x) identical(x$id, id), entries)
  if (!length(found)) {
    .abort(paste0("Unknown dataset `", id, "` for `", jurisdiction,
                  "`. Use list_datasets() or search_datasets() to find supported IDs."),
           subclass = "tampa_input_error")
  }
  if (length(found) != 1L) {
    .abort(paste0("Dataset `", id, "` exists in more than one jurisdiction. ",
                  "Supply its specific `jurisdiction`."), subclass = "tampa_input_error")
  }
  entry <- found[[1L]]
  entry$tags <- unlist(entry$tags, use.names = FALSE) %||% character()
  entry$date_fields <- unlist(entry$date_fields, use.names = FALSE) %||% character()
  entry$validation_status <- "checked"
  entry$portal <- entry$portal %||% if (!is.null(entry$item_id))
    "https://www.arcgis.com/sharing/rest" else NULL
  entry
}

.catalog_table <- function(entries) {
  scalar <- setdiff(.registry_required_fields(), c("layer_id", "date_fields", "tags"))
  cols <- lapply(scalar, function(name) vapply(entries, function(x) x[[name]], character(1)))
  names(cols) <- scalar
  cols$layer_id <- vapply(entries, function(x) as.integer(x$layer_id), integer(1))
  cols$date_fields <- lapply(entries, function(x) unlist(x$date_fields, use.names = FALSE) %||% character())
  cols$tags <- lapply(entries, function(x) unlist(x$tags, use.names = FALSE) %||% character())
  cols$verified <- as.Date(cols$verified)
  cols$item_id <- vapply(entries, function(x) x$item_id %||% NA_character_, character(1))
  cols$portal <- vapply(entries, function(x) x$portal %||%
    if (!is.null(x$item_id)) "https://www.arcgis.com/sharing/rest" else NA_character_,
    character(1))
  cols$validation_status <- rep("checked", length(entries))
  modified <- vapply(entries, function(x) x$upstream_modified %||% NA_character_,
                     character(1))
  cols$modified <- as.POSIXct(sub("\\+00:00$", "", modified),
                              format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  cols$modified_source <- ifelse(is.na(cols$modified), NA_character_, "checked_snapshot")
  cols$service_type <- ifelse(grepl("/FeatureServer$", cols$service_url),
                              "FeatureServer", "MapServer")
  cols$layer_type <- ifelse(cols$geometry_type == "none", "Table", "Feature Layer")
  cols$categories <- lapply(entries, function(x) x$category)
  cols$original_metadata <- entries
  tibble::as_tibble(cols)
}

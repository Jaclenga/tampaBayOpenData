.read_registry <- function() {
  path <- system.file("extdata", "datasets.json", package = "tampaBayOpenData")
  if (!nzchar(path)) .abort("The bundled dataset registry is missing. Reinstall the package.")
  entries <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
                      error = function(e) .abort("The bundled dataset registry is invalid JSON."))
  .validate_checked_catalog(entries)
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

# These are editorial checks for the bundled collection. Keep them separate
# from .validate_registry(), which also accepts synthetic external publishers
# in the descriptor and schema tests.
.checked_categories <- function() {
  c("Boundaries", "Development", "Environment", "Hazards", "Housing", "Infrastructure", "Planning",
    "Public facilities", "Public safety", "Recreation", "Solid waste",
    "Transportation", "Utilities")
}

.checked_https_url <- function(url) {
  is.character(url) && length(url) == 1L && !is.na(url) &&
    grepl("^https://[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]/[^[:space:]@]*$",
          url)
}

.validate_checked_catalog <- function(entries, portals = .portal_registry()) {
  .validate_registry(entries)
  publisher_keys <- vapply(portals, function(portal) {
    paste(portal$jurisdiction, portal$publisher, sep = "\r")
  }, character(1))
  endpoints <- character(length(entries))
  for (i in seq_along(entries)) {
    entry <- entries[[i]]
    key <- paste(entry$jurisdiction, entry$publisher, sep = "\r")
    if (!key %in% publisher_keys) {
      .abort(paste0("Checked dataset `", entry$id,
                    "` must match a configured portal jurisdiction and publisher."))
    }
    if (!entry$category %in% .checked_categories()) {
      .abort(paste0("Checked dataset `", entry$id,
                    "` uses an unrecognized category."))
    }
    if (!.checked_https_url(entry$source_url)) {
      .abort(paste0("Checked dataset `", entry$id,
                    "` must cite a valid HTTPS source URL."))
    }
    endpoint <- paste0(entry$service_url, "/", entry$layer_id)
    parsed <- tryCatch(.arcgis_layer_url(endpoint), error = function(e) NULL)
    if (is.null(parsed) || !identical(parsed$service_url, entry$service_url) ||
        !identical(parsed$layer_id, as.integer(entry$layer_id))) {
      .abort(paste0("Checked dataset `", entry$id,
                    "` must use a valid public ArcGIS service URL and layer ID."))
    }
    for (name in c("layer_name", "object_id_field", "scope_note", "terms_url")) {
      .string(entry[[name]], paste0("checked.", name))
    }
    if (!.checked_https_url(entry$terms_url)) {
      .abort(paste0("Checked dataset `", entry$id,
                    "` must provide an HTTPS terms URL."))
    }
    evidence <- entry$publisher_evidence
    if (!is.list(evidence) || !length(evidence) || !is.null(names(evidence)) ||
        !all(vapply(evidence, function(url) {
          .checked_https_url(url)
        }, logical(1)))) {
      .abort(paste0("Checked dataset `", entry$id,
                    "` must cite HTTPS publisher evidence URLs."))
    }
    .number(entry$max_record_count, "checked.max_record_count", min = 1,
            integer = TRUE)
    .flag(entry$supports_pagination, "checked.supports_pagination")
    .flag(entry$supports_order_by, "checked.supports_order_by")
    if (!identical(entry$geometry_type, "none") &&
        (is.null(entry$spatial_reference) ||
         !is.list(entry$spatial_reference) ||
         !length(entry$spatial_reference))) {
      .abort(paste0("Checked spatial dataset `", entry$id,
                    "` must record its CRS."))
    }
    endpoints[[i]] <- paste0(tolower(entry$service_url), "/",
                            as.integer(entry$layer_id))
  }
  if (anyDuplicated(endpoints)) {
    .abort("Checked datasets must not duplicate a service and layer combination.")
  }
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
                  "`. Use tbod_list_datasets() or tbod_search_datasets() to find supported IDs."),
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
  entry$portal <- .checked_entry_portal(entry)
  entry
}

.checked_entry_portal <- function(entry, portals = .portal_registry()) {
  if (!is.null(entry$portal)) return(entry$portal)
  if (is.null(entry$item_id)) return(NULL)
  matches <- Filter(function(portal) {
    identical(portal$jurisdiction, entry$jurisdiction) &&
      identical(portal$publisher, entry$publisher)
  }, portals)
  if (length(matches) != 1L) return(NULL)
  matches[[1L]]$root
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
  portals <- .portal_registry()
  cols$portal <- vapply(entries, function(x) {
    .checked_entry_portal(x, portals) %||% NA_character_
  }, character(1))
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

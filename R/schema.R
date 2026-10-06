# The checked schema is a dated source snapshot, stored apart from the portal
# discovery catalog. It is data, never an assumption about current services.
.read_expected_schemas <- function() {
  path <- system.file("extdata", "expected-schemas.json",
                      package = "tampaBayOpenData")
  if (!nzchar(path)) .abort("The bundled expected schemas are missing. Reinstall the package.")
  schemas <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
                      error = function(e) .abort("The bundled expected schemas are invalid JSON."))
  if (!is.list(schemas) || is.null(names(schemas)) ||
      anyDuplicated(names(schemas))) {
    .abort("The bundled expected schemas must be keyed by jurisdiction and dataset ID.")
  }
  schemas
}

.validate_expected_schema <- function(schema) {
  if (!is.list(schema) ||
      !all(c("fields", "geometry_type", "object_id_field", "endpoint") %in%
           names(schema))) {
    .abort("An expected schema is missing required metadata.",
           subclass = "tampa_input_error")
  }
  .string(schema$geometry_type, "schema.geometry_type")
  .string(schema$object_id_field, "schema.object_id_field")
  .string(schema$endpoint, "schema.endpoint")
  if (!is.list(schema$fields) || !length(schema$fields) ||
      !all(vapply(schema$fields, function(field) {
        is.list(field) && is.character(field$name) && length(field$name) == 1L &&
          !is.na(field$name) && nzchar(field$name) &&
          is.character(field$type) && length(field$type) == 1L &&
          !is.na(field$type) && nzchar(field$type) &&
          (is.null(field$alias) || (is.character(field$alias) &&
            length(field$alias) == 1L && !is.na(field$alias)))
      }, logical(1)))) {
    .abort("An expected schema has invalid field names or types.",
           subclass = "tampa_input_error")
  }
  names <- vapply(schema$fields, `[[`, character(1), "name")
  if (anyDuplicated(names) || !schema$object_id_field %in% names) {
    .abort("An expected schema has duplicate fields or no object-ID field.",
           subclass = "tampa_input_error")
  }
  reference <- schema$spatial_reference
  if (!is.null(reference)) {
    valid_id <- function(x) is.null(x) ||
      (length(x) == 1L && !is.na(x) &&
         ((is.numeric(x) && is.finite(x) && x >= 0 && x == floor(x)) ||
            (is.character(x) && grepl("^[0-9]+$", x))))
    valid_wkt <- function(x) is.null(x) ||
      (is.character(x) && length(x) == 1L && !is.na(x) &&
         nzchar(trimws(x)))
    if (!is.list(reference) ||
        (length(reference) && is.null(names(reference))) ||
        !valid_id(reference$wkid) || !valid_id(reference$latestWkid) ||
        !valid_wkt(reference$wkt) || !valid_wkt(reference$wkt2)) {
      .abort("An expected schema has an invalid spatial reference.",
             subclass = "tampa_input_error")
    }
  }
  invisible(schema)
}

.schema_crs_key <- function(reference) {
  if (is.null(reference)) return(NULL)
  if (!is.list(reference) || is.null(names(reference))) return(reference)
  id <- reference$latestWkid %||% reference$wkid
  if (!is.null(id)) {
    # ArcGIS uses these legacy identifiers for Web Mercator (EPSG:3857).
    if (as.character(id) %in% c("102100", "102113", "900913")) id <- 3857L
    return(paste0("wkid:", as.character(id)))
  }
  wkt <- reference$wkt %||% reference$wkt2
  if (!is.null(wkt)) return(paste0("wkt:", trimws(wkt)))
  reference
}

.same_schema_crs <- function(expected, actual) {
  if (identical(.schema_crs_key(expected), .schema_crs_key(actual))) return(TRUE)
  if (!arcgis_has_sf()) return(FALSE)
  as_crs <- function(reference) {
    if (!is.list(reference) || is.null(names(reference))) return(NULL)
    if (is.null(reference$wkt) && !is.null(reference$wkt2)) {
      reference$wkt <- reference$wkt2
    }
    for (name in c("wkid", "latestWkid")) {
      value <- reference[[name]]
      if (is.character(value) && length(value) == 1L &&
          !is.na(value) && grepl("^[0-9]+$", value)) {
        reference[[name]] <- suppressWarnings(as.numeric(value))
      }
    }
    # arcgis_spatial_crs() checks that WKT is inline before passing it to GDAL.
    tryCatch(arcgis_spatial_crs(reference), error = function(e) NULL)
  }
  left <- as_crs(expected)
  right <- as_crs(actual)
  !is.null(left) && !is.null(right) &&
    isTRUE(tryCatch(left == right, error = function(e) FALSE))
}

.schema_field_table <- function(fields) {
  tibble::tibble(
    name = vapply(fields, `[[`, character(1), "name"),
    type = vapply(fields, `[[`, character(1), "type"),
    alias = vapply(fields, function(x) x$alias %||% x$name, character(1)))
}

.schema_from_metadata <- function(metadata, endpoint) {
  list(endpoint = endpoint, fields = metadata$fields,
       geometry_type = metadata[["geometryType", exact = TRUE]] %||% "none",
       spatial_reference = arcgis_native_reference(metadata),
       object_id_field = metadata$objectIdField)
}

.schema_descriptor <- function(id, jurisdiction, omitted, timeout) {
  if (is.character(id) && length(id) == 1L && !is.na(id) &&
      grepl("^https://", id)) {
    if (!omitted && !is.null(jurisdiction)) {
      .abort("`jurisdiction` does not apply to a direct ArcGIS URL.",
             subclass = "tampa_input_error")
    }
    return(.direct_arcgis_descriptor(id))
  }
  requested <- .requested_jurisdiction(id, jurisdiction, omitted)
  .resolve_dataset(id, requested, timeout)
}

#' Inspect a dataset schema
#'
#' For a checked dataset, the default returns the bundled schema snapshot
#' without a network request. `refresh = TRUE` requests current ArcGIS layer
#' metadata. A direct ArcGIS layer URL or discovered descriptor has no bundled
#' expected schema and requires `refresh = TRUE`. Call [tbod_check_schema()] to
#' compare a current service against its expected schema. A stable ArcGIS item
#' ID from an Enterprise portal can be resolved with `portal`.
#'
#' @param id Checked dataset ID, discovered descriptor, stable ArcGIS item ID,
#'   or public HTTPS ArcGIS layer URL.
#' @param jurisdiction Optional checked-catalog jurisdiction. `NULL` resolves a
#'   unique bundled ID and preserves a discovery row's source. Direct URLs do
#'   not accept a jurisdiction override.
#' @param refresh Request current layer metadata when TRUE.
#' @param timeout Per-request timeout in seconds.
#' @param total_timeout Overall operation budget in seconds; `Inf` disables it.
#' @param portal Optional public ArcGIS sharing REST portal URL for a stable
#'   `arcgis:<item-id>:<layer-id>` identifier. It does not apply to other IDs.
#' @return A list with endpoint, a tibble of field names, types and aliases,
#'   geometry type, spatial reference, object-ID field, and dataset ID.
#' @export
#' @examples
#' schema <- tbod_schema("construction-permits")
#' head(schema$fields[, c("name", "type")])
tbod_schema <- function(id, jurisdiction = NULL, refresh = FALSE,
                        timeout = 30, total_timeout = 60, portal = NULL) {
  .flag(refresh, "refresh")
  timeout <- .operation_timeout(timeout, total_timeout)
  resolved <- .tbod_resolve_portal_id(id, portal, timeout, total_timeout)
  id <- resolved$id
  timeout <- resolved$timeout
  dataset <- .schema_descriptor(id, jurisdiction, missing(jurisdiction), timeout)
  if (refresh) {
    metadata <- arcgis_layer(dataset, timeout)
    schema <- .schema_from_metadata(metadata,
      paste0(dataset$service_url, "/", dataset$layer_id))
  } else {
    schema <- dataset$expected_schema
    if (is.null(schema)) {
      .abort("This dataset has no bundled expected schema. Use `refresh = TRUE` to inspect its current schema.",
             dataset, subclass = "tampa_input_error")
    }
  }
  .check_operation_timeout(timeout, dataset)
  schema$fields <- .schema_field_table(schema$fields)
  schema$dataset_id <- dataset$id
  schema
}

.schema_issue_table <- function() {
  tibble::tibble(category = character(), severity = character(),
                 field = character(), expected = character(), actual = character())
}

.schema_report <- function(dataset, expected, actual, issues) {
  status <- if (nrow(issues) && any(issues$severity == "incompatible")) {
    "incompatible"
  } else if (nrow(issues)) {
    "compatible"
  } else if (is.null(expected)) {
    "untracked"
  } else {
    "unchanged"
  }
  endpoint <- if (!is.null(dataset)) {
    paste0(dataset$service_url, "/", dataset$layer_id)
  } else actual$endpoint %||% expected$endpoint %||% NULL
  structure(list(dataset_id = dataset$id %||% expected$dataset_id %||% NULL,
                 endpoint = endpoint,
                 status = status, issues = issues,
                 expected = expected, actual = actual),
            class = "tbod_schema_check")
}

.compare_schema <- function(expected, metadata, dataset = NULL) {
  endpoint <- if (!is.null(dataset)) {
    paste0(dataset$service_url, "/", dataset$layer_id)
  } else expected$endpoint %||% NULL
  actual <- .schema_from_metadata(metadata, endpoint)
  if (is.null(expected)) return(.schema_report(dataset, NULL, actual,
                                                .schema_issue_table()))
  .validate_expected_schema(expected)
  issue <- function(category, severity, field = "", expected_value = "",
                    actual_value = "") {
    tibble::tibble(category = category, severity = severity, field = field,
                   expected = as.character(expected_value),
                   actual = as.character(actual_value))
  }
  issues <- .schema_issue_table()
  add <- function(row) issues <<- rbind(issues, row)
  expected_fields <- .schema_field_table(expected$fields)
  actual_fields <- .schema_field_table(actual$fields)
  removed <- setdiff(expected_fields$name, actual_fields$name)
  added <- setdiff(actual_fields$name, expected_fields$name)
  # A matching alias (or case-only name change) is useful evidence of a rename
  # only when it identifies exactly one field in each direction.
  for (old in removed) {
    old_row <- expected_fields[match(old, expected_fields$name), , drop = FALSE]
    candidates <- added[vapply(added, function(new) {
      new_row <- actual_fields[match(new, actual_fields$name), , drop = FALSE]
      identical(tolower(old), tolower(new)) ||
        (identical(old_row$alias, new_row$alias) && nzchar(old_row$alias))
    }, logical(1))]
    if (length(candidates) != 1L) next
    new <- candidates[[1L]]
    reverse <- removed[vapply(removed, function(other) {
      other_row <- expected_fields[match(other, expected_fields$name), , drop = FALSE]
      identical(tolower(other), tolower(new)) ||
        (identical(other_row$alias, old_row$alias) && nzchar(old_row$alias))
    }, logical(1))]
    if (length(reverse) != 1L) next
    add(issue("renamed_field", "incompatible", old, old, new))
    new_row <- actual_fields[match(new, actual_fields$name), , drop = FALSE]
    if (!identical(old_row$type, new_row$type)) {
      add(issue("changed_type", "incompatible", new, old_row$type,
                new_row$type))
    }
    removed <- setdiff(removed, old)
    added <- setdiff(added, new)
  }
  for (name in removed) {
    row <- expected_fields[match(name, expected_fields$name), , drop = FALSE]
    add(issue("removed_field", "incompatible", name, row$type, ""))
  }
  for (name in added) {
    row <- actual_fields[match(name, actual_fields$name), , drop = FALSE]
    add(issue("added_field", "compatible", name, "", row$type))
  }
  for (name in intersect(expected_fields$name, actual_fields$name)) {
    old_type <- expected_fields$type[match(name, expected_fields$name)]
    new_type <- actual_fields$type[match(name, actual_fields$name)]
    if (!identical(old_type, new_type)) {
      add(issue("changed_type", "incompatible", name, old_type, new_type))
    }
    old_alias <- expected_fields$alias[match(name, expected_fields$name)]
    new_alias <- actual_fields$alias[match(name, actual_fields$name)]
    if (!identical(old_alias, new_alias)) {
      add(issue("changed_alias", "compatible", name, old_alias, new_alias))
    }
  }
  if (!identical(expected$object_id_field, actual$object_id_field)) {
    add(issue("object_id_change", "incompatible", "", expected$object_id_field,
              actual$object_id_field))
  }
  if (!identical(expected$geometry_type, actual$geometry_type)) {
    add(issue("geometry_change", "incompatible", "", expected$geometry_type,
              actual$geometry_type))
  }
  if (!.same_schema_crs(expected$spatial_reference,
                        actual$spatial_reference)) {
    add(issue("crs_change", "incompatible", "",
              .schema_crs_key(expected$spatial_reference) %||% "none",
              .schema_crs_key(actual$spatial_reference) %||% "none"))
  }
  if (!is.null(endpoint) && !identical(expected$endpoint, endpoint)) {
    add(issue("endpoint_change", "incompatible", "", expected$endpoint,
              endpoint))
  }
  .schema_report(dataset, expected, actual, issues)
}

.schema_endpoint_missing <- function(error) {
  inherits(error, c("tampa_http_error", "tampa_arcgis_error")) &&
    grepl("HTTP (404|410)|ArcGIS error (404|410)|[Ll]ayer (ID )?[0-9]* ?(does not exist|not found)|[Ll]ayer not found",
          conditionMessage(error))
}

.schema_missing_report <- function(dataset, expected, error) {
  issues <- tibble::tibble(category = "endpoint_disappeared",
    severity = "incompatible", field = "", expected = expected$endpoint %||%
      paste0(dataset$service_url, "/", dataset$layer_id),
    actual = conditionMessage(error))
  .schema_report(dataset, expected, NULL, issues)
}

.schema_retrieve_report <- function(dataset, timeout, expected) {
  metadata <- tryCatch(arcgis_layer(dataset, timeout,
                                    schema_only = !is.null(expected)), error = function(e) {
    if (.schema_endpoint_missing(e)) return(e)
    stop(e)
  })
  if (inherits(metadata, "error")) {
    return(.schema_missing_report(dataset, expected, metadata))
  }
  .compare_schema(expected, metadata, dataset)
}

#' Check a current ArcGIS schema against an expected schema
#'
#' The checked catalog supplies an expected snapshot automatically. For a
#' discovered descriptor or direct ArcGIS URL, pass `expected` explicitly to
#' compare it with a previously saved [tbod_schema()] result. Otherwise the
#' result is `untracked` and contains the current schema. Added fields and
#' changed aliases are compatible drift. Removed or renamed fields, changed
#' field types, object-ID fields, geometry or CRS, and moved or missing endpoints
#' are incompatible drift. This inspection function returns a report, including
#' missing endpoints; checked retrieval warns for compatible drift and errors
#' before querying for incompatible drift.
#'
#' @inheritParams tbod_schema
#' @param expected Optional schema list with `endpoint`, `fields`,
#'   `geometry_type`, `spatial_reference`, and `object_id_field`. A saved
#'   [tbod_schema()] result can be passed directly.
#' @return A `tbod_schema_check` list with `status` (`unchanged`,
#'   `compatible`, `incompatible`, or `untracked`), a tibble of issues with
#'   `category`, `severity`, `field`, `expected`, and `actual` columns, and
#'   expected and current schemas. An incompatible missing endpoint has no
#'   current schema.
#' @export
#' @examples
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   report <- tbod_check_schema("construction-permits")
#'   report$status
#'   report$issues
#' }
tbod_check_schema <- function(id, jurisdiction = NULL, expected = NULL,
                              timeout = 30, total_timeout = 60,
                              portal = NULL) {
  timeout <- .operation_timeout(timeout, total_timeout)
  resolved <- .tbod_resolve_portal_id(id, portal, timeout, total_timeout)
  id <- resolved$id
  timeout <- resolved$timeout
  dataset <- .schema_descriptor(id, jurisdiction, missing(jurisdiction), timeout)
  expected <- expected %||% dataset$expected_schema
  if (!is.null(expected)) {
    if (!is.list(expected)) {
      .abort("An expected schema is missing required metadata.",
             subclass = "tampa_input_error")
    }
    # tbod_schema() returns a field tibble; accept it as a saved expectation.
    if (inherits(expected$fields, "data.frame")) {
      required <- c("name", "type", "alias")
      if (!all(required %in% names(expected$fields)) ||
          anyDuplicated(names(expected$fields))) {
        .abort("An expected schema field table needs unique name, type, and alias columns.",
               subclass = "tampa_input_error")
      }
      expected$fields <- lapply(seq_len(nrow(expected$fields)), function(i) {
        as.list(expected$fields[i, required, drop = FALSE])
      })
    }
    .validate_expected_schema(expected)
  }
  report <- .schema_retrieve_report(dataset, timeout, expected)
  .check_operation_timeout(timeout, dataset)
  report
}

.schema_guard <- function(report, dataset) {
  if (identical(report$status, "untracked") ||
      identical(report$status, "unchanged")) return(invisible(report))
  details <- paste(paste0(report$issues$category,
                          ifelse(nzchar(report$issues$field),
                                 paste0(" `", report$issues$field, "`"), "")),
                   collapse = ", ")
  if (identical(report$status, "compatible")) {
    warning(paste0("Dataset `", dataset$id, "` has compatible ArcGIS schema drift: ",
                   details, ". Inspect with tbod_check_schema()."), call. = FALSE)
  } else {
    .abort(paste0("Incompatible ArcGIS schema drift: ", details,
                  ". Inspect with tbod_check_schema()."), dataset,
           report$endpoint, "tampa_schema_error")
  }
  invisible(report)
}

.schema_checked_layer <- function(dataset, timeout) {
  expected <- dataset$expected_schema
  metadata <- tryCatch(arcgis_layer(dataset, timeout,
                                    schema_only = !is.null(expected)), error = function(e) {
    if (!is.null(expected) && .schema_endpoint_missing(e)) {
      .schema_guard(.schema_missing_report(dataset, expected, e), dataset)
    }
    stop(e)
  })
  if (!is.null(expected)) .schema_guard(.compare_schema(expected, metadata, dataset),
                                       dataset)
  metadata
}

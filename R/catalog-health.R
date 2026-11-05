# Catalog checks inspect the bundled, checked entries. They never update the
# registry or its dated schema snapshots.

.catalog_health_state <- function(status) {
  states <- c(healthy = "healthy", schema_changed = "degraded",
              unsupported = "degraded", unavailable = "unavailable",
              unknown = "unknown")
  state <- unname(states[status])
  if (length(state) != 1L || is.na(state)) "unknown" else state
}

.catalog_health_row <- function(entry, status = "unknown", failure_type = NA_character_,
                                http_status = NA_integer_, service_status = "unknown",
                                layer_status = "unknown", schema_status = "unavailable",
                                schema_issues = .schema_issue_table(), details = "") {
  tibble::tibble(
    publisher = entry$publisher,
    jurisdiction = entry$jurisdiction,
    dataset_id = entry$id,
    endpoint = paste0(entry$service_url, "/", entry$layer_id),
    checked_at = as.POSIXct(Sys.time(), tz = "UTC"),
    status = status,
    failure_type = failure_type,
    http_status = as.integer(http_status),
    service_status = service_status,
    layer_status = layer_status,
    schema_status = schema_status,
    schema_issues = list(schema_issues),
    details = details,
    health_state = .catalog_health_state(status),
    response_time_ms = NA_real_,
    query_status = "not_checked",
    query_failure_type = NA_character_,
    query_http_status = NA_integer_,
    query_details = ""
  )
}

.catalog_error_code <- function(error) {
  message <- conditionMessage(error)
  kind <- if (inherits(error, "tampa_http_error")) "http" else
    if (inherits(error, "tampa_arcgis_error")) "arcgis" else "none"
  pattern <- if (identical(kind, "http")) "HTTP ([0-9]{3})" else
    if (identical(kind, "arcgis")) "ArcGIS error ([0-9]+)" else ""
  if (!nzchar(pattern)) return(list(kind = kind, code = NA_integer_))
  found <- regmatches(message, regexec(pattern, message))[[1L]]
  list(kind = kind, code = if (length(found) >= 2L) as.integer(found[[2L]]) else NA_integer_)
}

.catalog_http_status <- function(error) {
  code <- .catalog_error_code(error)
  if (identical(code$kind, "http")) return(code$code)
  if (identical(code$kind, "arcgis")) return(200L)
  if (inherits(error, "tampa_response_error") &&
      !grepl("invalid response status", conditionMessage(error), fixed = TRUE)) {
    return(200L)
  }
  if (inherits(error, "tampa_data_error") &&
      grepl("Layer metadata|layer no longer advertises", conditionMessage(error))) {
    return(200L)
  }
  NA_integer_
}

.catalog_error_result <- function(entry, error) {
  code <- .catalog_error_code(error)
  status <- "unknown"
  failure <- if (inherits(error, "tampa_timeout_error")) "timeout" else
    if (inherits(error, "tampa_response_error")) "malformed_response" else
    if (identical(code$kind, "http") && !is.na(code$code) &&
        code$code %in% c(429L, 500L, 502L, 503L, 504L)) "transient_http" else
    if (identical(code$kind, "arcgis") && !is.na(code$code) &&
        code$code %in% c(429L, 500L, 502L, 503L, 504L)) "transient_arcgis" else
    if (identical(code$kind, "http") && !is.na(code$code)) "unexpected_http" else
    if (inherits(error, "tampa_http_error")) "connection_failure" else
    "metadata_error"

  if (inherits(error, "tampa_data_error") &&
      grepl("no longer advertises query support", conditionMessage(error), fixed = TRUE)) {
    status <- "unsupported"
    failure <- "query_unsupported"
  } else if (inherits(error, "tampa_data_error") &&
             grepl("does not identify a unique object-ID field", conditionMessage(error),
                   fixed = TRUE)) {
    status <- "unsupported"
    failure <- "object_id_unavailable"
  } else if (!is.na(code$code) && code$code %in% c(401L, 403L, 498L, 499L)) {
    status <- "unsupported"
    failure <- "access_denied"
  } else if (!is.na(code$code) && code$code %in% c(400L, 405L, 422L, 501L)) {
    status <- "unsupported"
    failure <- "invalid_or_unsupported_request"
  } else if (identical(failure, "unexpected_http")) {
    status <- "unsupported"
  } else if (inherits(error, "tampa_data_error") &&
             grepl("Layer metadata", conditionMessage(error), fixed = TRUE)) {
    failure <- "malformed_metadata"
  }
  .catalog_health_row(entry, status = status, failure_type = failure,
                      http_status = .catalog_http_status(error),
                      details = conditionMessage(error))
}

# Service-root metadata is requested only after a missing-layer response. A
# root that still lists that layer contradicts the layer response and must not
# be reported as a confirmed disappearance.
.catalog_service_ids <- function(metadata) {
  if (!is.list(metadata) || !is.numeric(metadata$currentVersion) ||
      length(metadata$currentVersion) != 1L ||
      is.na(metadata$currentVersion) || !is.finite(metadata$currentVersion) ||
      metadata$currentVersion <= 0 ||
      !any(c("layers", "tables") %in% names(metadata))) return(NULL)
  sections <- metadata[c("layers", "tables")]
  ids <- numeric()
  for (section in sections) {
    if (is.null(section)) next
    if (!is.list(section) || !is.null(names(section))) return(NULL)
    if (!all(vapply(section, function(x) {
      is.list(x) && is.numeric(x$id) && length(x$id) == 1L &&
        !is.na(x$id) && is.finite(x$id) && x$id >= 0 && x$id == floor(x$id)
    }, logical(1)))) return(NULL)
    ids <- c(ids, vapply(section, function(x) x$id, numeric(1)))
  }
  if (anyDuplicated(ids)) return(NULL)
  ids
}

.catalog_missing_layer <- function(entry, error, timeout) {
  layer_code <- .catalog_error_code(error)
  layer_http <- .catalog_http_status(error)
  root <- tryCatch(arcgis_request(entry$service_url, dataset = entry,
                                  timeout = timeout), error = identity)
  if (inherits(root, "error")) {
    root_code <- .catalog_error_code(root)
    if (!is.na(root_code$code) && root_code$code %in% c(404L, 410L)) {
      return(.catalog_health_row(entry, status = "unavailable",
        failure_type = "service_missing", http_status = layer_http,
        service_status = "unavailable", layer_status = "unavailable",
        details = paste0("Layer request: ", conditionMessage(error),
                         "\nService-root probe: ", conditionMessage(root))))
    }
    return(.catalog_health_row(entry,
      failure_type = "layer_missing_service_unverified", http_status = layer_http,
      details = paste0("Layer returned ", layer_code$kind, " ",
                       layer_code$code, ". Service-root probe was inconclusive: ",
                       conditionMessage(root))))
  }
  ids <- .catalog_service_ids(root)
  if (is.null(ids)) {
    return(.catalog_health_row(entry, failure_type = "inconsistent_service_metadata",
      http_status = layer_http,
      details = paste0("Layer returned ", layer_code$kind, " ", layer_code$code,
                       ", but its service root returned malformed layer listings.")))
  }
  if (entry$layer_id %in% ids) {
    return(.catalog_health_row(entry, failure_type = "inconsistent_service_response",
      http_status = layer_http, service_status = "available",
      layer_status = "unknown",
      details = paste0("Layer returned ", layer_code$kind, " ", layer_code$code,
                       ", but the service root still lists layer ", entry$layer_id,
                       ". Recheck after the service stabilizes.")))
  }
  .catalog_health_row(entry, status = "unavailable", failure_type = "layer_missing",
                      http_status = layer_http, service_status = "available",
                      layer_status = "unavailable",
                      details = paste0("Layer returned ", layer_code$kind, " ",
                                       layer_code$code, "; the service root exists and ",
                                       "no longer lists layer ", entry$layer_id, "."))
}

.catalog_check_metadata <- function(entry, timeout) {
  if (.operation_remaining(timeout) <= 0) {
    return(.catalog_health_row(entry, failure_type = "budget_exhausted",
      details = "Catalog check reached `total_timeout` before this layer was requested."))
  }
  # Permit an absent object-ID field long enough to compare the live schema
  # with its snapshot. Ordinary retrieval still requires a usable ID field.
  metadata <- tryCatch(arcgis_layer(entry, timeout, schema_only = TRUE),
                       error = identity)
  if (inherits(metadata, "error")) {
    if (.schema_endpoint_missing(metadata)) {
      return(.catalog_missing_layer(entry, metadata, timeout))
    }
    return(.catalog_error_result(entry, metadata))
  }
  if (!length(metadata$fields)) {
    return(.catalog_health_row(entry, failure_type = "malformed_metadata",
      http_status = 200L, service_status = "available", layer_status = "available",
      details = "Layer metadata does not contain any fields."))
  }
  oid_available <- nzchar(metadata$objectIdField) &&
    metadata$objectIdField %in% .field_names(metadata)
  geometry <- metadata[["geometryType", exact = TRUE]]
  valid_geometry <- if (is.null(geometry)) {
    identical(entry$geometry_type, "none") || identical(metadata$type, "Table")
  } else
    is.character(geometry) && length(geometry) == 1L && !is.na(geometry) &&
    geometry %in% c("none", "esriGeometryPoint", "esriGeometryMultipoint",
                    "esriGeometryPolyline", "esriGeometryPolygon")
  if (!valid_geometry) {
    return(.catalog_health_row(entry, failure_type = "malformed_metadata",
      http_status = 200L, service_status = "available", layer_status = "available",
      details = "Layer metadata has a missing or invalid geometry type for this catalog entry."))
  }
  capabilities <- metadata[["capabilities", exact = TRUE]]
  expected <- entry$expected_schema
  if (is.null(expected)) {
    if (!oid_available) {
      return(.catalog_health_row(entry, status = "unsupported",
        failure_type = "object_id_unavailable", http_status = 200L,
        service_status = "available", layer_status = "available",
        details = "Layer metadata has no usable object-ID field; record retrieval is unsupported. No trustworthy schema baseline is available for comparison."))
    }
    unreported <- is.null(capabilities)
    return(.catalog_health_row(entry,
      failure_type = if (unreported) "baseline_and_capabilities_unavailable" else
        "baseline_unavailable",
      http_status = 200L, service_status = "available", layer_status = "available",
      details = paste0("Layer metadata is accessible, but no trustworthy schema baseline is available for comparison.",
                       if (unreported) " Query capability is also unreported." else "")))
  }
  comparison <- tryCatch(.compare_schema(expected, metadata, entry), error = identity)
  if (inherits(comparison, "error")) {
    return(.catalog_health_row(entry, failure_type = "baseline_invalid",
      http_status = 200L, service_status = "available", layer_status = "available",
      details = paste0("Schema comparison could not be completed: ",
                       conditionMessage(comparison))))
  }
  if (!identical(comparison$status, "unchanged")) {
    issue_labels <- paste0(comparison$issues$category,
                           ifelse(nzchar(comparison$issues$field),
                                  paste0(" (`", comparison$issues$field, "`)"), ""))
    return(.catalog_health_row(entry, status = "schema_changed",
      failure_type = "schema_drift", http_status = 200L,
      service_status = "available", layer_status = "available",
      schema_status = comparison$status, schema_issues = comparison$issues,
       details = paste0("Schema differs from the bundled snapshot: ",
                        paste(issue_labels, collapse = ", "), ".",
                        if (!oid_available)
                          " The object-ID field is unavailable; record retrieval is unsupported." else "",
                        if (is.null(capabilities))
                          " Query capability is unreported." else "")))
  }
  if (is.null(capabilities)) {
    return(.catalog_health_row(entry, failure_type = "capabilities_unreported",
      http_status = 200L, service_status = "available", layer_status = "available",
      schema_status = "unchanged",
      details = "Layer metadata does not advertise Query capability; required operations cannot be verified."))
  }
  .catalog_health_row(entry, status = "healthy", http_status = 200L,
                      service_status = "available", layer_status = "available",
                      schema_status = "unchanged",
                      details = "Layer metadata is valid, Query is advertised, and the schema matches the bundled snapshot.")
}

.catalog_query_probe <- function(entry, timeout) {
  url <- paste0(entry$service_url, "/", entry$layer_id, "/query")
  count <- .matching_count(url, list(where = "1=0"), entry, timeout)
  if (count != 0) {
    .abort("The zero-match query probe returned a nonzero count.", entry, url,
           "tampa_response_error")
  }
  invisible(TRUE)
}

.catalog_check_entry <- function(entry, timeout, probe_query = FALSE, pause = 0) {
  started <- .operation_clock()
  row <- .catalog_check_metadata(entry, timeout)
  requested <- !identical(row$failure_type[[1L]], "budget_exhausted")
  elapsed <- if (requested) max(0, .operation_clock() - started) else NA_real_

  # A count against a false predicate verifies the actual Query operation
  # without reading features. Unusable metadata responses are not probed.
  probeable <- identical(row$layer_status[[1L]], "available") &&
    row$status[[1L]] %in% c("healthy", "schema_changed", "unknown") &&
    !row$failure_type[[1L]] %in% c("malformed_metadata", "baseline_invalid")
  if (probe_query && probeable) {
    if (pause > 0 && .operation_remaining(timeout) > 0) {
      .operation_sleep(min(pause, .operation_remaining(timeout)))
    }
    probe_started <- .operation_clock()
    probe <- tryCatch(.catalog_query_probe(entry, timeout), error = identity)
    elapsed <- elapsed + max(0, .operation_clock() - probe_started)
    if (inherits(probe, "error")) {
      classified <- .catalog_error_result(entry, probe)
      transient <- classified$failure_type[[1L]] %in%
        c("timeout", "transient_http", "transient_arcgis", "connection_failure")
      row$query_status <- if (transient) "unknown" else "failed"
      row$query_failure_type <- classified$failure_type
      row$query_http_status <- classified$http_status
      row$query_details <- conditionMessage(probe)
      # Confirmed schema drift remains visible even if a later query probe
      # fails or times out. The query columns retain that separate diagnosis.
      if (!identical(row$status[[1L]], "schema_changed")) {
        row$status <- if (transient) "unknown" else "unsupported"
        row$failure_type <- paste0("query_", classified$failure_type)
      }
      row$details <- paste0(row$details, "\nQuery probe: ", conditionMessage(probe))
    } else {
      row$query_status <- "verified"
      row$query_http_status <- 200L
    }
  }
  row$response_time_ms <- if (is.na(elapsed)) NA_real_ else elapsed * 1000
  row$health_state <- .catalog_health_state(row$status[[1L]])
  row$checked_at <- as.POSIXct(Sys.time(), tz = "UTC")
  row
}

.check_catalog_entries <- function(entries, timeout, pause, probe_query = FALSE) {
  rows <- vector("list", length(entries))
  for (i in seq_along(entries)) {
    rows[[i]] <- .catalog_check_entry(entries[[i]], timeout, probe_query, pause)
    if (i < length(entries) && pause > 0 && .operation_remaining(timeout) > 0) {
      .operation_sleep(min(pause, .operation_remaining(timeout)))
    }
  }
  do.call(rbind, rows)
}

#' Check the current health of checked catalog layers
#'
#' Checks current public ArcGIS endpoints and saved schemas for selected
#' entries in the bundled checked catalog. It contacts publisher services and
#' returns a report without changing the catalog or saving files. A healthy
#' result is a point-in-time metadata check, not a measure of record freshness.
#' @details Each entry starts one layer-metadata request. The client probes the
#'   service root only after a missing-layer response (HTTP or ArcGIS 404/410,
#'   or an explicit layer-not-found error) to distinguish a missing layer from
#'   a missing service. Transient failures remain `unknown`
#'   after bounded retries; entries not reached before `total_timeout` are also
#'   `unknown`. The default retry limit is three additional attempts per
#'   retryable failure sequence. Set
#'   `options(tampaBayOpenData.max_retries = 3L)` to change it (whole number
#'   from 0 to 10).
#'
#'   `healthy` means the layer metadata is valid, Query is advertised, and the
#'   schema matches the saved snapshot. `schema_changed` includes both
#'   compatible and incompatible drift; inspect `schema_status` and
#'   `schema_issues`. Confirmed schema drift remains `schema_changed` if Query
#'   capability is unreported. With no saved baseline, `schema_status` is `unavailable`
#'   and `status` is `unknown`. A missing object-ID field is reported as schema
#'   drift when a baseline exists; the details also identify unsupported record
#'   retrieval. `unsupported` includes layers
#'   that cannot be queried and access failures. By default the check does not
#'   retrieve features or run count and object-ID queries. A layer can advertise Query
#'   yet fail those operations during retrieval. Set `probe_query = TRUE` to
#'   run a zero-match count request after valid layer metadata; it reads no
#'   features and records whether the actual Query operation succeeds. A
#'   confirmed query failure is degraded, while a transient probe failure is
#'   unknown unless independently confirmed schema drift already makes the
#'   result degraded. The result cannot guarantee future service availability.
#' @param jurisdiction One checked-catalog jurisdiction code or `"all"`.
#' @param ids Optional nonempty vector of unique checked dataset IDs within
#'   `jurisdiction`; `NULL` checks all selected entries.
#' @param timeout Per-HTTP-attempt timeout in seconds.
#' @param total_timeout Maximum elapsed seconds for the complete check,
#'   including requests, retries, and pauses. Defaults to 1,800; `Inf`
#'   disables the overall deadline. Entries not reached are reported as
#'   `unknown`.
#' @param pause Delay from 0 to 30 seconds between entries to limit request
#'   rate; defaults to 0.25. With `probe_query = TRUE`, also pauses between
#'   layer metadata and the count probe.
#' @param probe_query Run a zero-match count query after usable metadata to
#'   verify Query capability. Defaults to `FALSE` for the existing metadata-only
#'   behavior. Query probes do not retrieve features.
#' @return A tibble with one row per selected entry and `publisher`,
#'   `jurisdiction`, `dataset_id`, `endpoint`, `checked_at` (UTC POSIXct),
#'   `status` (`healthy`, `unavailable`, `schema_changed`, `unsupported`, or
#'   `unknown`), `failure_type`, `http_status`, `service_status` and
#'   `layer_status` (`available`, `unavailable`, or `unknown`),
#'   `schema_status` (`unchanged`, `compatible`, `incompatible`, or
#'   `unavailable`), `schema_issues` (a list of issue tibbles), and `details`.
#'   `health_state` summarizes status as `healthy`, `degraded`, `unavailable`,
#'   or `unknown`. `response_time_ms` is elapsed request time including retries
#'   and a missing-layer service-root probe, excluding deliberate pauses; it is
#'   missing if no request was made. `query_status` is `not_checked`, `verified`,
#'   `failed`, or `unknown`; `query_failure_type`, `query_http_status`, and
#'   `query_details` explain a failed or uncertain probe. `http_status` is
#'   missing when no metadata HTTP response was received.
#' @export
#' @examples
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   report <- tbod_check_catalog(ids = "construction-permits")
#'   report[, c("dataset_id", "status", "schema_status", "details")]
#' }
tbod_check_catalog <- function(jurisdiction = "all", ids = NULL, timeout = 10,
                               total_timeout = 1800, pause = 0.25,
                               probe_query = FALSE) {
  timeout <- .operation_timeout(timeout, total_timeout)
  .number(pause, "pause", min = 0)
  .flag(probe_query, "probe_query")
  if (pause > 30) {
    .abort("`pause` must be no more than 30 seconds.",
           subclass = "tampa_input_error")
  }
  entries <- .jurisdiction_entries(jurisdiction)
  if (!is.null(ids)) {
    if (!is.character(ids) || !length(ids) || anyNA(ids) ||
        any(!nzchar(ids)) || anyDuplicated(ids)) {
      .abort("`ids` must be a nonempty vector of unique checked dataset IDs.",
             subclass = "tampa_input_error")
    }
    available <- vapply(entries, `[[`, character(1), "id")
    missing <- setdiff(ids, available)
    if (length(missing)) {
      .abort(paste0("Unknown checked dataset ID(s) for `", jurisdiction, "`: ",
                    paste(missing, collapse = ", "), "."),
             subclass = "tampa_input_error")
    }
    entries <- Filter(function(entry) entry$id %in% ids, entries)
  }
  if (!length(entries)) {
    .abort(paste0("No checked catalog entries are available for `", jurisdiction, "`."),
           subclass = "tampa_input_error")
  }
  .check_catalog_entries(entries, timeout, pause, probe_query)
}

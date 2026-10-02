# All remote access, including metadata inspection, goes through this transport.
.arcgis_response_limit <- 50 * 1024^2

arcgis_http <- function(url, params, timeout) {
  req <- httr2::request(url)
  req <- httr2::req_user_agent(req, "tampaBayOpenData/0.1.0")
  req <- httr2::req_headers(req, Accept = "application/json")
  req <- httr2::req_timeout(req, timeout)
  req <- httr2::req_options(req, followlocation = FALSE,
                           maxfilesize_large = .arcgis_response_limit)
  req <- httr2::req_retry(req, max_tries = 3L, retry_on_failure = TRUE,
                         is_transient = function(response) {
                           httr2::resp_status(response) %in% c(429L, 500L, 502L, 503L, 504L)
                         },
                         after = .bounded_retry_after)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  if (grepl("/query$", url)) {
    req <- do.call(httr2::req_body_form, c(list(req), params))
  } else {
    req <- do.call(httr2::req_url_query, c(list(req), params))
  }
  response <- httr2::req_perform(req)
  list(status = httr2::resp_status(response), body = httr2::resp_body_string(response))
}

.bounded_retry_after <- function(response) {
  delay <- tryCatch(suppressWarnings(httr2::resp_retry_after(response)),
                    error = function(e) NA_real_)
  if (!is.numeric(delay) || length(delay) != 1L || !is.finite(delay)) return(NA_real_)
  min(max(delay, 0), 30)
}

# Some ArcGIS backends intermittently send an error JSON body with HTTP 200.
# Retry only the generic query failure; specific ArcGIS errors remain immediate.
arcgis_request <- function(url, params = list(), dataset = NULL, timeout = 30) {
  for (attempt in seq_len(4L)) {
    result <- tryCatch(.arcgis_request_once(url, params, dataset, timeout),
                       tampa_arcgis_transient_error = identity)
    if (!inherits(result, "tampa_arcgis_transient_error")) return(result)
    if (attempt == 4L) stop(result)
    .arcgis_retry_pause(attempt)
  }
}

.arcgis_retry_pause <- function(attempt) Sys.sleep(0.25 * attempt)

.arcgis_request_once <- function(url, params, dataset, timeout) {
  params$f <- "json"
  response <- tryCatch(arcgis_http(url, params, timeout), error = function(e) {
    .abort(paste0("The upstream ArcGIS service could not be reached: ", conditionMessage(e)),
           dataset, url, "tampa_http_error")
  })
  if (!is.list(response) || !is.numeric(response$status) || length(response$status) != 1L ||
      is.na(response$status) || !is.finite(response$status)) {
    .abort("The HTTP transport returned an invalid response status.", dataset, url, "tampa_response_error")
  }
  if (response$status < 200L || response$status >= 300L) {
    .abort(paste0("The upstream ArcGIS service returned HTTP ",
                  response$status %||% "(unknown)",
                  if (identical(as.integer(response$status), 404L))
                    ". The service may have moved; check the source page." else "."),
           dataset, url, "tampa_http_error")
  }
  if (is.character(response$body) && length(response$body) == 1L &&
      !is.na(response$body) && nchar(response$body, type = "bytes") > .arcgis_response_limit) {
    .abort("The upstream response exceeds the 50 MiB response-size limit.",
           dataset, url, "tampa_response_error")
  }
  result <- tryCatch(jsonlite::parse_json(response$body, simplifyVector = FALSE),
                     error = function(e) .abort("The upstream service returned malformed JSON.",
                                                dataset, url, "tampa_response_error"))
  if (!is.list(result) || is.null(names(result))) {
    .abort("The upstream response is not an ArcGIS JSON object.", dataset, url,
           "tampa_response_error")
  }
  if (.duplicate_json_keys(result, dataset = dataset, url = url)) {
    .abort("The upstream response contains duplicate JSON object keys.", dataset, url, "tampa_response_error")
  }
  if (!is.null(result$error)) {
    err <- result$error
    if (!is.list(err) || !is.numeric(err$code) || length(err$code) != 1L ||
        is.na(err$code) || !is.character(err$message) || length(err$message) != 1L ||
        is.na(err$message)) {
      .abort("The upstream service returned a malformed ArcGIS error object.", dataset, url, "tampa_response_error")
    }
    retryable <- grepl("/query$", url) && isTRUE(err$code == 400) &&
      identical(err$message, "Unable to complete operation.") &&
      !length(err$details)
    .abort(paste0("ArcGIS error ", err$code %||% "(unknown)", ": ",
                  err$message %||% "The query failed.",
                  if (length(err$details)) paste0(" ", paste(unlist(err$details), collapse = "; "))),
           dataset, url, if (retryable)
             c("tampa_arcgis_transient_error", "tampa_arcgis_error") else
             "tampa_arcgis_error")
  }
  result
}

.duplicate_json_keys <- function(value, depth = 1L, dataset = NULL, url = NULL) {
  if (!is.list(value)) return(FALSE)
  if (depth > 64L) {
    .abort("The upstream JSON response exceeds the 64-level nesting limit.",
           dataset, url, "tampa_response_error")
  }
  anyDuplicated(names(value)) > 0L || any(vapply(value, function(child) {
    .duplicate_json_keys(child, depth + 1L, dataset, url)
  }, logical(1)))
}

arcgis_layer <- function(dataset, timeout = 30) {
  url <- paste0(dataset$service_url, "/", dataset$layer_id)
  metadata <- arcgis_request(url, dataset = dataset, timeout = timeout)
  if (!is.list(metadata$fields) || !length(metadata$fields) ||
      !all(vapply(metadata$fields, function(x) is.list(x) &&
        is.character(x$name) && length(x$name) == 1L && !is.na(x$name) && nzchar(x$name) &&
        is.character(x$type) && length(x$type) == 1L && !is.na(x$type) && nzchar(x$type) &&
        (is.null(x$alias) || (is.character(x$alias) && length(x$alias) == 1L &&
          !is.na(x$alias))), logical(1)))) {
    .abort("Layer metadata does not contain a valid field schema.", dataset, url,
           "tampa_response_error")
  }
  if (anyDuplicated(.field_names(metadata))) {
    .abort("Layer metadata contains duplicate field names.", dataset, url,
           "tampa_response_error")
  }
  for (name in c("advancedQueryCapabilities", "dateFieldsTimeReference", "extent",
                 "spatialReference", "sourceSpatialReference")) {
    value <- metadata[[name]]
    if (!is.null(value) && (!is.list(value) ||
        (length(value) && is.null(names(value))))) {
      .abort(paste0("Layer metadata contains malformed `", name, "`."), dataset, url,
             "tampa_response_error")
    }
  }
  if (!is.null(metadata$dateFieldsTimeReference$timeZone) &&
      (!is.character(metadata$dateFieldsTimeReference$timeZone) ||
       length(metadata$dateFieldsTimeReference$timeZone) != 1L ||
       is.na(metadata$dateFieldsTimeReference$timeZone))) {
    .abort("Layer metadata contains a malformed date time zone.", dataset, url, "tampa_response_error")
  }
  if (!is.null(metadata$datesInUnknownTimezone) &&
      (!is.logical(metadata$datesInUnknownTimezone) ||
       length(metadata$datesInUnknownTimezone) != 1L ||
       is.na(metadata$datesInUnknownTimezone))) {
    .abort("Layer metadata contains a malformed unknown-time-zone flag.",
           dataset, url, "tampa_response_error")
  }
  if (!is.null(metadata$capabilities) &&
      (!is.character(metadata$capabilities) || length(metadata$capabilities) != 1L ||
       is.na(metadata$capabilities))) {
    .abort("Layer metadata contains malformed query capabilities.",
           dataset, url, "tampa_response_error")
  }
  if (!is.null(metadata$capabilities) &&
      !grepl("Query", metadata$capabilities, ignore.case = TRUE)) {
    .abort("This layer no longer advertises query support.", dataset, url)
  }
  oid <- metadata$objectIdField %||% metadata$objectIdFieldName
  if (is.null(oid) || identical(oid, "")) {
    oid_fields <- Filter(function(x) identical(x$type, "esriFieldTypeOID"), metadata$fields)
    if (length(oid_fields) == 1L) oid <- oid_fields[[1L]]$name
  }
  if (!is.character(oid) || length(oid) != 1L || is.na(oid) || !oid %in% .field_names(metadata)) {
    .abort("Layer metadata does not identify a unique object-ID field.", dataset, url)
  }
  metadata$objectIdField <- oid
  max_records <- metadata$maxRecordCount
  if (!is.numeric(max_records) || length(max_records) != 1L || is.na(max_records) ||
      !is.finite(max_records) || max_records < 1 || max_records != floor(max_records)) {
    .abort("Layer metadata does not declare a valid record limit.", dataset, url)
  }
  metadata
}

# Internal service discovery is useful when maintaining the registry.
arcgis_layers <- function(service_url, timeout = 30) {
  result <- arcgis_request(service_url, timeout = timeout)
  layers <- c(result$layers %||% list(), result$tables %||% list())
  if (!is.list(layers)) .abort("Service metadata does not contain a layer list.", url = service_url)
  tibble::tibble(
    layer_id = vapply(layers, function(x) as.integer(x$id), integer(1)),
    name = vapply(layers, function(x) x$name, character(1)))
}

.query_params <- function(query) {
  allowed <- c("geometry", "geometryType", "inSR", "spatialRel", "relationParam",
               "time", "distance", "units", "gdbVersion", "historicMoment",
               "sqlFormat", "datumTransformation")
  if (!is.list(query) || (length(query) &&
      (is.null(names(query)) || anyNA(names(query)) || any(!nzchar(names(query))) ||
       anyDuplicated(names(query))))) .abort("`query` must be a uniquely named list.")
  bad <- setdiff(names(query), allowed)
  if (length(bad)) {
    .abort(paste0("Unsupported or protected `query` parameter(s): ", paste(bad, collapse = ", "),
                  ". Use the documented get_dataset() arguments for fields, ordering, limits, and CRS."),
           subclass = "tampa_input_error")
  }
  lapply(query, function(value) {
    if (is.list(value)) return(as.character(jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", digits = NA)))
    if (length(value) != 1L || is.na(value) ||
        !is.atomic(value) || !is.null(dim(value))) .abort("Each `query` value must be a scalar or a JSON-style list.")
    as.character(value)
  })
}

.selected_fields <- function(fields, metadata) {
  attributes <- Filter(function(x) !identical(x$type, "esriFieldTypeGeometry"), metadata$fields)
  available <- vapply(attributes, function(x) x$name, character(1))
  if (is.null(fields) || identical(fields, "*")) return(available)
  if (!is.character(fields) || !length(fields) || anyNA(fields) ||
      any(!nzchar(fields)) || anyDuplicated(fields)) .abort("`fields` must be a nonempty vector of unique source field names.")
  bad <- setdiff(fields, available)
  if (length(bad)) .abort(paste0("Unknown source field(s): ", paste(bad, collapse = ", "),
                                ". Inspect dataset_info(id, refresh = TRUE)$fields."))
  fields
}

.ordering <- function(order_by, metadata) {
  if (is.null(order_by)) return(NULL)
  if (!is.character(order_by) || !length(order_by) || anyNA(order_by) || any(!nzchar(trimws(order_by)))) {
    .abort("`order_by` must contain source field names with optional ASC or DESC.")
  }
  terms <- trimws(unlist(strsplit(order_by, ",", fixed = TRUE), use.names = FALSE))
  if (!length(terms) || any(!nzchar(terms)) || any(grepl(",[[:space:]]*$", order_by))) {
    .abort("`order_by` must contain nonempty source field names.")
  }
  fields <- sub("[[:space:]]+(ASC|DESC)$", "", terms, ignore.case = TRUE)
  if (any(!fields %in% .field_names(metadata)) || anyDuplicated(fields)) {
    .abort("`order_by` must use unique source field names, each optionally followed by ASC or DESC.")
  }
  cap <- metadata$advancedQueryCapabilities
  if (!isTRUE(cap$supportsOrderBy) || !isTRUE(cap$supportsPagination)) {
    .abort("This service does not support reliable server-side ordering with pagination.")
  }
  if (!metadata$objectIdField %in% fields) terms <- c(terms, paste(metadata$objectIdField, "ASC"))
  paste(terms, collapse = ",")
}

.object_ids <- function(value, dataset, url) {
  if (is.null(value) || !is.list(value) || !is.null(names(value)) ||
      any(!vapply(value, function(x) is.numeric(x) && length(x) == 1L,
                  logical(1)))) {
    .abort("The service returned malformed or duplicate object IDs.", dataset, url, "tampa_integrity_error")
  }
  ids <- unlist(value, use.names = FALSE)
  if (!length(ids)) return(numeric())
  if (!is.numeric(ids) || anyNA(ids) || any(!is.finite(ids)) ||
      any(ids != floor(ids)) || any(abs(ids) > 2^53 - 1) || anyDuplicated(ids)) {
    .abort("The service returned malformed or duplicate object IDs.", dataset, url,
           "tampa_integrity_error")
  }
  as.numeric(ids)
}

.transfer_limit <- function(response, dataset, url) {
  flag <- response$exceededTransferLimit
  if (!is.null(flag) &&
      (!is.logical(flag) || length(flag) != 1L || is.na(flag))) {
    .abort("The response contains an invalid transfer-limit flag.", dataset, url,
           "tampa_response_error")
  }
  isTRUE(flag)
}

.check_object_id_field <- function(response, metadata, dataset, url) {
  if (!is.null(response$objectIdFieldName) &&
      !identical(response$objectIdFieldName, metadata$objectIdField)) {
    .abort("The service's object-ID field changed during retrieval.", dataset, url,
           "tampa_integrity_error")
  }
}

.manifest <- function(url, params, metadata, dataset, timeout) {
  count <- arcgis_request(url, c(params, list(returnCountOnly = "true", returnGeometry = "false")),
                          dataset, timeout)$count
  if (!is.numeric(count) || length(count) != 1L || is.na(count) || !is.finite(count) ||
      count < 0 || count != floor(count)) {
    .abort("The service returned an invalid matching-record count.", dataset, url, "tampa_response_error")
  }
  if (count > 1000000) {
    .abort("More than one million records match. Narrow `where` or spatial/time filters to avoid the ArcGIS object-ID limit.",
           dataset, url, "tampa_integrity_error")
  }
  response <- arcgis_request(url, c(params, list(returnIdsOnly = "true", returnGeometry = "false")),
                             dataset, timeout)
  truncated <- .transfer_limit(response, dataset, url)
  if (!"objectIds" %in% names(response) || truncated) {
    .abort("The service did not return a complete object-ID manifest.", dataset, url, "tampa_integrity_error")
  }
  .check_object_id_field(response, metadata, dataset, url)
  ids <- .object_ids(response$objectIds, dataset, url)
  if (length(ids) != count) {
    .abort("The matching count and object-ID manifest disagree. The service may have changed; retry the query.",
           dataset, url, "tampa_integrity_error")
  }
  list(ids = sort(ids), count = count)
}

.page_features <- function(response, metadata, dataset, url) {
  .transfer_limit(response, dataset, url)
  .check_object_id_field(response, metadata, dataset, url)
  if (!is.null(response$geometryType) && !identical(response$geometryType, metadata$geometryType)) {
    .abort("The response geometry type differs from the layer metadata.", dataset, url, "tampa_response_error")
  }
  if (!is.null(response$spatialReference) &&
      (!is.list(response$spatialReference) || is.null(names(response$spatialReference)))) {
    .abort("The response contains a malformed spatial reference.", dataset, url, "tampa_response_error")
  }
  if (!"features" %in% names(response) || !is.list(response$features) ||
      !is.null(names(response$features))) {
    .abort("The query response does not contain a valid feature array.", dataset, url, "tampa_response_error")
  }
  features <- response$features
  if (!all(vapply(features, function(x) {
    if (!is.list(x) || !"attributes" %in% names(x)) return(FALSE)
    attributes <- x[["attributes"]]
    is.list(attributes) && !anyDuplicated(names(attributes)) &&
      metadata$objectIdField %in% names(attributes)
  }, logical(1)))) {
    .abort("A feature is missing its attributes or object ID.", dataset, url, "tampa_response_error")
  }
  if (any(vapply(features, function(x) is.null(x[["attributes"]][[metadata$objectIdField]]), logical(1)))) {
    .abort("A feature contains a null object ID.", dataset, url, "tampa_integrity_error")
  }
  if (any(!vapply(features, function(x) is.numeric(x[["attributes"]][[metadata$objectIdField]]) &&
                  length(x[["attributes"]][[metadata$objectIdField]]) == 1L, logical(1)))) {
    .abort("A feature contains a malformed object ID.", dataset, url, "tampa_response_error")
  }
  ids <- .object_ids(lapply(features, function(x) x[["attributes"]][[metadata$objectIdField]]), dataset, url)
  if (length(ids) != length(features)) .abort("A feature contains a null object ID.", dataset, url, "tampa_integrity_error")
  list(features = features, ids = ids, spatial_reference = response$spatialReference)
}

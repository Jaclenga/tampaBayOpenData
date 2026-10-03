# An accepted spatial page must agree with the requested and previous CRS.
.page_reference <- function(page, metadata, out_sr, previous, dataset, url) {
  reference <- page$spatial_reference
  if (is.null(reference)) {
    if (!is.null(out_sr)) {
      .abort("A projected spatial page did not identify its response CRS. Retrieval stopped before coordinates could be mislabeled.",
             dataset, url, "tampa_spatial_error")
    }
    reference <- arcgis_native_reference(metadata)
  }
  crs <- arcgis_spatial_crs(reference)
  if (!is.null(out_sr) && !isTRUE(crs == arcgis_spatial_crs(list(wkid = out_sr)))) {
    .abort("A spatial page's response CRS differs from the requested out_sr.",
           dataset, url, "tampa_spatial_error")
  }
  if (!is.null(previous) && !isTRUE(arcgis_spatial_crs(previous) == crs)) {
    .abort("The response CRS changed between pages.", dataset, url, "tampa_integrity_error")
  }
  reference
}

.feature_page_handlers <- function(url, params, metadata, dataset, timeout,
                                   spatial, out_sr) {
  request_page <- function(paging) {
    response <- arcgis_request(url, c(params, paging), dataset, timeout)
    page <- .page_features(response, metadata, dataset, url)
    page$truncated <- .transfer_limit(response, dataset, url)
    page
  }
  add_page <- function(result, page) {
    if (spatial && length(page$features)) {
      result$spatial_reference <- .page_reference(
        page, metadata, out_sr, result$spatial_reference, dataset, url)
    }
    result$features <- c(result$features, page$features)
    result$ids <- c(result$ids, page$ids)
    result
  }
  list(request_page = request_page, add_page = add_page)
}

# Split truncated batches depth first. Only complete batches enter the result.
.fetch_id_batch <- function(ids, request_page, add_page, result, dataset, url) {
  page <- request_page(list(objectIds = paste(
    format(ids, scientific = FALSE, trim = TRUE), collapse = ",")))
  if (any(!page$ids %in% ids)) {
    .abort("A batch returned unexpected object IDs.", dataset, url, "tampa_integrity_error")
  }
  if (page$truncated) {
    if (length(ids) <= 1L) {
      .abort("The service truncated a single-record batch.", dataset, url, "tampa_integrity_error")
    }
    split <- floor(length(ids) / 2)
    result <- .fetch_id_batch(ids[seq_len(split)], request_page, add_page, result, dataset, url)
    return(.fetch_id_batch(ids[seq.int(split + 1L, length(ids))],
                           request_page, add_page, result, dataset, url))
  }
  if (!setequal(page$ids, ids)) {
    .abort("A batch is missing requested records. The service may have changed; retry the query.",
           dataset, url, "tampa_integrity_error")
  }
  index <- match(ids, page$ids)
  page$features <- page$features[index]
  page$ids <- page$ids[index]
  add_page(result, page)
}

.fetch_ordered_pages <- function(order, target, size, ids, request_page, add_page,
                                 result, dataset, url) {
  while (length(result$ids) < target) {
    requested <- min(size, target - length(result$ids))
    page <- request_page(list(orderByFields = order,
                             resultOffset = length(result$ids),
                             resultRecordCount = requested))
    if (!length(page$ids) || length(page$ids) > requested ||
        (!is.null(ids) && any(!page$ids %in% ids)) || any(page$ids %in% result$ids)) {
      .abort("Ordered pagination returned an empty, repeated, oversized, or unexpected page. Retrieval is incomplete; retry the query.",
             dataset, url, "tampa_integrity_error")
    }
    if (length(page$ids) < requested && !page$truncated) {
      .abort("Ordered pagination stopped before all requested records were returned.",
             dataset, url, "tampa_integrity_error")
    }
    result <- add_page(result, page)
  }
  result
}

arcgis_fetch <- function(dataset, metadata, where, fields, spatial, out_sr,
                         order_by, limit, page_size, query_params, timeout,
                         integrity = "full") {
  url <- paste0(dataset$service_url, "/", dataset$layer_id, "/query")
  params <- c(list(where = where), query_params)
  if (.dates_unknown(metadata)) params$timeReferenceUnknownClient <- "true"
  count <- .matching_count(url, params, dataset, timeout)
  target <- min(limit, count)
  size <- min(page_size %||% 1000, metadata$maxRecordCount, 1000)
  feature_params <- c(params, list(
    outFields = paste(unique(c(fields, metadata$objectIdField)), collapse = ","),
    returnGeometry = if (spatial) "true" else "false",
    returnZ = "false", returnM = "false"))
  if (!is.null(out_sr)) feature_params$outSR <- as.character(out_sr)
  order <- .ordering(order_by, metadata)
  capabilities <- metadata$advancedQueryCapabilities
  preview <- identical(integrity, "auto") && is.finite(limit) &&
    target > 0 && target < count && limit <= 1000 && count > 10000 &&
    isTRUE(capabilities$supportsPagination) && isTRUE(capabilities$supportsOrderBy)
  manifest <- if (target == 0 && is.finite(limit)) {
    list(ids = numeric(), count = count)
  } else if (preview) {
    list(ids = NULL, count = count)
  } else .manifest(url, params, metadata, dataset, timeout, count = count)
  if (preview && is.null(order)) order <- paste(metadata$objectIdField, "ASC")

  handlers <- .feature_page_handlers(url, feature_params, metadata, dataset,
                                     timeout, spatial, out_sr)
  result <- list(features = list(), ids = numeric(), spatial_reference = NULL)
  if (target > 0 && is.null(order)) {
    ids <- manifest$ids[seq_len(target)]
    for (start in seq.int(1, length(ids), by = size)) {
      batch <- ids[seq.int(start, min(start + size - 1, length(ids)))]
      result <- .fetch_id_batch(batch, handlers$request_page, handlers$add_page,
                                result, dataset, url)
    }
  } else if (target > 0) {
    result <- .fetch_ordered_pages(order, target, size, manifest$ids,
                                   handlers$request_page, handlers$add_page,
                                   result, dataset, url)
  }
  if (preview) {
    subset_params <- c(params, list(objectIds = paste(
      format(result$ids, scientific = FALSE, trim = TRUE), collapse = ",")))
    verified_ids <- .matching_ids(url, subset_params, metadata, dataset, timeout,
                                  length(result$ids))
    if (!setequal(result$ids, verified_ids)) {
      .abort("Preview records no longer match the requested filter. Retry the query.",
             dataset, url, "tampa_integrity_error")
    }
  }
  if (length(result$ids) != target || anyDuplicated(result$ids) ||
      (target == manifest$count && !setequal(result$ids, manifest$ids))) {
    .abort("Retrieval did not cover the requested record manifest.", dataset, url, "tampa_integrity_error")
  }
  list(features = result$features, spatial_reference = result$spatial_reference,
       matched_rows = manifest$count, returned_rows = length(result$ids),
       complete = target == manifest$count,
       integrity = if (target == 0 && is.finite(limit)) "count-only" else if
         (preview) "subset-manifest" else "full-manifest",
       pagination = if (preview) "ordered preview" else if (is.null(order))
         "object-id batches" else "ordered offsets")
}

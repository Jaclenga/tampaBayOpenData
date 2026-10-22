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
    .page_features(response, metadata, dataset, url)
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

# Split truncated or unexpectedly short batches depth first. Only complete
# batches enter the result, including when a service omits the transfer flag.
.fetch_id_batch <- function(ids, request_page, add_page, result, dataset, url) {
  page <- request_page(list(objectIds = paste(
    format(ids, scientific = FALSE, trim = TRUE), collapse = ",")))
  if (any(!page$ids %in% ids)) {
    .abort("The publisher returned unexpected object IDs in a record batch. Retrieval stopped because those records were not requested. Try again later.",
           dataset, url, "tampa_integrity_error")
  }
  if (page$truncated || !setequal(page$ids, ids)) {
    if (length(ids) <= 1L) {
      .abort(if (page$truncated)
        paste0("The publisher truncated a single-record batch, so even a smaller ",
               "request cannot confirm that record. Retrieval stopped to avoid ",
               "an incomplete result. Try again later.") else
        paste0("The publisher's response is missing requested records, even when ",
               "fetched one at a time. Records may have changed during the request. ",
               "Retrieval stopped to avoid an incomplete result; try again later."),
        dataset, url, "tampa_integrity_error")
    }
    split <- floor(length(ids) / 2)
    result <- .fetch_id_batch(ids[seq_len(split)], request_page, add_page, result, dataset, url)
    return(.fetch_id_batch(ids[seq.int(split + 1L, length(ids))],
                           request_page, add_page, result, dataset, url))
  }
  index <- match(ids, page$ids)
  page$features <- page$features[index]
  page$ids <- page$ids[index]
  add_page(result, page)
}

.ordered_spec <- function(order, metadata) {
  terms <- trimws(strsplit(order, ",", fixed = TRUE)[[1L]])
  fields <- sub("[[:space:]]+(ASC|DESC)$", "", terms, ignore.case = TRUE)
  schema <- metadata$fields[match(fields, .field_names(metadata))]
  list(fields = fields,
       descending = grepl("[[:space:]]+DESC$", terms, ignore.case = TRUE),
       types = vapply(schema, function(field) field$type, character(1)))
}

# Compare adjacent rows, including the boundary between offset pages. NULL
# placement and locale-dependent string collation cannot be inferred safely.
.ordered_pair_ok <- function(left, right, spec, dataset, url) {
  numeric_types <- c("esriFieldTypeOID", "esriFieldTypeSmallInteger",
                     "esriFieldTypeInteger", "esriFieldTypeSingle",
                     "esriFieldTypeDouble", "esriFieldTypeDate")
  for (i in seq_along(spec$fields)) {
    field <- spec$fields[[i]]
    a <- left$attributes[[field]]
    b <- right$attributes[[field]]
    if (is.null(a) || is.null(b)) {
      if (is.null(a) && is.null(b)) next
      return(TRUE)
    }
    type <- spec$types[[i]]
    if (type %in% numeric_types) {
      if (!is.numeric(a) || !is.numeric(b) || length(a) != 1L ||
          length(b) != 1L || !is.finite(a) || !is.finite(b)) {
        .abort(paste0("Ordered field `", field, "` contains an invalid numeric value."),
               dataset, url, "tampa_response_error")
      }
    } else if (type %in% c("esriFieldTypeString", "esriFieldTypeDateOnly")) {
      if (!is.character(a) || !is.character(b) || length(a) != 1L ||
          length(b) != 1L || is.na(a) || is.na(b)) {
        .abort(paste0("Ordered field `", field, "` contains an invalid string value."),
               dataset, url, "tampa_response_error")
      }
      if (!identical(a, b) && type == "esriFieldTypeString") {
        # Avoid declaring a violation for case or collation rules that may
        # differ between R and the ArcGIS source database.
        if (!grepl("^[A-Za-z0-9]+$", a) || !grepl("^[A-Za-z0-9]+$", b) ||
            identical(toupper(a), toupper(b))) return(TRUE)
        a <- toupper(a)
        b <- toupper(b)
      }
    } else {
      if (identical(a, b)) next
      return(TRUE)
    }
    comparison <- (a > b) - (a < b)
    if (comparison != 0L) {
      return(if (spec$descending[[i]]) comparison > 0L else comparison < 0L)
    }
  }
  TRUE
}

.fetch_ordered_pages <- function(order, target, size, ids, request_page, add_page,
                                 result, metadata, dataset, url) {
  spec <- .ordered_spec(order, metadata)
  while (length(result$ids) < target) {
    requested <- min(size, target - length(result$ids))
    page <- request_page(list(orderByFields = order,
                             resultOffset = length(result$ids),
                             resultRecordCount = requested))
    problem <- if (!length(page$ids)) {
      "an empty page before all records were fetched"
    } else if (length(page$ids) > requested) {
      "more records than requested"
    } else if (!is.null(ids) && any(!page$ids %in% ids)) {
      "records outside the requested ID list"
    } else if (any(page$ids %in% result$ids)) {
      "a record ID seen on an earlier page"
    } else NULL
    if (!is.null(problem)) {
      .abort(paste0("The publisher returned ", problem,
                    ". Retrieval stopped to avoid missing or duplicate records. ",
                    "Try again later or omit ",
                    "`order_by` to retrieve by record ID."),
             dataset, url, c("tampa_pagination_error", "tampa_integrity_error"))
    }
    if (length(page$ids) < requested && !page$truncated) {
      .abort("Ordered pagination stopped before all requested records were returned. The publisher sent fewer records than requested without reporting a limit. Retrieval stopped to avoid an incomplete result; try again later or omit `order_by`.",
             dataset, url, c("tampa_pagination_error", "tampa_integrity_error"))
    }
    adjacent <- c(utils::tail(result$features, 1L), page$features)
    if (length(adjacent) > 1L && any(!vapply(seq.int(2L, length(adjacent)),
      function(i) .ordered_pair_ok(adjacent[[i - 1L]], adjacent[[i]], spec,
                                    dataset, url), logical(1)))) {
      .abort("Ordered pagination returned records out of the requested order. The publisher may have ignored `order_by`. Retrieval stopped to avoid an unreliable result; try again later or omit `order_by` and sort in R.",
             dataset, url, c("tampa_pagination_error", "tampa_integrity_error"))
    }
    result <- add_page(result, page)
  }
  result
}

.offset_fallback_error <- function(error) {
  if (inherits(error, "tampa_pagination_error")) return(TRUE)
  if (inherits(error, "tampa_arcgis_transient_error")) return(TRUE)
  if (inherits(error, "tampa_http_error")) {
    return(grepl("HTTP (400|405|501)([^0-9]|$)", conditionMessage(error),
                 perl = TRUE))
  }
  if (!inherits(error, "tampa_arcgis_error")) return(FALSE)
  message <- tolower(conditionMessage(error))
  grepl("pagination|resultoffset|result offset|resultrecordcount|result record count", message) &&
    grepl("unsupported|not supported|not available|not enabled|does not support", message)
}

.fetch_manifest_batches <- function(ids, size, request_page, add_page,
                                    result, dataset, url) {
  for (start in seq.int(1, length(ids), by = size)) {
    batch <- ids[seq.int(start, min(start + size - 1, length(ids)))]
    result <- .fetch_id_batch(batch, request_page, add_page, result, dataset, url)
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
  order <- .ordering(order_by, metadata)
  capabilities <- metadata$advancedQueryCapabilities
  preview <- identical(integrity, "auto") && is.finite(limit) &&
    target > 0 && target < count && limit <= 1000 && count > 10000 &&
    isTRUE(capabilities$supportsPagination) && isTRUE(capabilities$supportsOrderBy)
  if (preview && is.null(order)) order <- paste(metadata$objectIdField, "ASC")
  feature_params <- c(params, list(
    outFields = paste(unique(c(fields, metadata$objectIdField,
      if (!is.null(order)) .ordered_spec(order, metadata)$fields)), collapse = ","),
    returnGeometry = if (spatial) "true" else "false",
    returnZ = "false", returnM = "false"))
  if (!is.null(out_sr)) feature_params$outSR <- as.character(out_sr)
  manifest <- if (target == 0 && is.finite(limit)) {
    list(ids = numeric(), count = count)
  } else if (preview) {
    list(ids = NULL, count = count)
  } else .manifest(url, params, metadata, dataset, timeout, count = count)

  handlers <- .feature_page_handlers(url, feature_params, metadata, dataset,
                                     timeout, spatial, out_sr)
  result <- list(features = list(), ids = numeric(), spatial_reference = NULL)
  offset_fallback <- FALSE
  if (target > 0 && is.null(order)) {
    ids <- manifest$ids[seq_len(target)]
    result <- .fetch_manifest_batches(ids, size, handlers$request_page,
                                      handlers$add_page, result, dataset, url)
  } else if (target > 0) {
    offset_error <- NULL
    result <- tryCatch(.fetch_ordered_pages(order, target, size, manifest$ids,
                                            handlers$request_page, handlers$add_page,
                                            result, metadata, dataset, url), error = function(e) {
      if (!preview || !is.null(order_by) || !.offset_fallback_error(e)) stop(e)
      offset_error <<- e
      result
    })
    if (!is.null(offset_error)) {
      manifest <- tryCatch(.manifest(url, params, metadata, dataset, timeout,
                                     count = count), error = function(e) {
        .abort(paste0("Automatic offset preview failed, and the object-ID manifest ",
                      "fallback also failed. Retrieval stopped to avoid an incomplete ",
                      "preview. Try again later; for large datasets, narrow `where` ",
                      "or spatial filters."),
               dataset, url,
               c("tampa_pagination_error", "tampa_integrity_error"))
      })
      result <- list(features = list(), ids = numeric(), spatial_reference = NULL)
      result <- tryCatch(.fetch_manifest_batches(manifest$ids[seq_len(target)],
                                                   size, handlers$request_page,
                                                   handlers$add_page, result,
                                                   dataset, url), error = function(e) {
        .abort(paste0("Automatic offset preview failed, and the object-ID batch ",
                      "fallback also failed. Retrieval stopped to avoid an incomplete ",
                      "preview. Try again later."),
               dataset, url, class(e)[[1L]])
      })
      preview <- FALSE
      order <- NULL
      offset_fallback <- TRUE
    }
  }
  if (preview) {
    subset_params <- c(params, list(objectIds = paste(
      format(result$ids, scientific = FALSE, trim = TRUE), collapse = ",")))
    verified_ids <- .matching_ids(url, subset_params, metadata, dataset, timeout,
                                  length(result$ids))
    if (!setequal(result$ids, verified_ids)) {
      .abort("Preview records no longer match the requested filter. The dataset may have changed during retrieval, so the preview was stopped to avoid unreliable results. Retry the query.",
             dataset, url, "tampa_integrity_error")
    }
  }
  if (length(result$ids) != target || anyDuplicated(result$ids) ||
      (target == manifest$count && !setequal(result$ids, manifest$ids))) {
    .abort("The records received do not match the requested ID list. Retrieval did not cover the requested record manifest; results may be missing or duplicated. Retrieval stopped. Try again later.",
           dataset, url, "tampa_integrity_error")
  }
  list(features = result$features, spatial_reference = result$spatial_reference,
       matched_rows = manifest$count, returned_rows = length(result$ids),
       complete = target == manifest$count,
       integrity = if (target == 0) "count-only" else if
         (preview) "subset-manifest" else "full-manifest",
       pagination = if (target == 0) "count-only" else if (offset_fallback)
         "object-id fallback" else if (preview)
         "ordered preview" else if (is.null(order)) "object-id batches" else
         "ordered offsets")
}

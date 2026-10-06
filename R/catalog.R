#' List Tampa Bay ArcGIS datasets
#'
#' Live discovery searches the organizations in [tbod_list_portals()] and expands
#' public services into candidate layers and tables. Retrieval requires Query
#' when a layer supplies a capabilities list and validates its query responses.
#' The bundled registry supplies a separate
#' `"checked"` validation layer and remains available without a network request.
#' A portal item can be stale or a layer can change after discovery.
#' @param jurisdiction Jurisdiction code or vector of codes from [tbod_list_portals()],
#'   or `"all"` (default). Filters checked and live results and narrows the portal
#'   scan. A supported jurisdiction may have no checked entries.
#' @param source `"all"` (default) combines live discovery with the checked
#'   registry; `"live"` returns layers found through the portal with checked
#'   matches marked; `"checked"` reads only the offline registry.
#' @param max_items Maximum number of portal service items to scan per selected
#'   organization. The default, 25, bounds the service scan; `Inf` follows all
#'   available search pages. This limits items, not expanded layers. Inspect
#'   `attr(result, "discovery_complete")` before treating a live result as a
#'   complete portal listing.
#' @param portals Live organization IDs from [tbod_list_portals()], or `"all"`
#'   (default). A character vector of IDs is also accepted. Intersects with
#'   jurisdiction and publisher filters before any portal requests.
#'   This does not filter the bundled checked catalog.
#' @param timeout Timeout in seconds for each HTTP attempt.
#' @param total_timeout Maximum elapsed seconds for the complete operation,
#'   including discovery and retries. Defaults to 90; `Inf` disables this limit.
#' @param publisher Publisher name or vector of names, matched exactly without
#'   regard to case. See [tbod_list_portals()] for names. Filters all results and
#'   narrows the portal scan; an unmatched name returns no rows.
#' @param validation_status `"checked"`, `"discovered"`, or a vector of both.
#'   NULL includes both. This filters the final classification; `source = "live"`
#'   can include checked matches. Use `source = "checked"` for offline browsing.
#' @param spatial TRUE selects layers with declared geometry; FALSE selects
#'   nonspatial tables. NULL includes both and unknown geometry types.
#' @param topic Word or vector of words matched as case-insensitive literal
#'   substrings in tags and categories. NULL disables this filter.
#' @param category Category or vector of categories, matched exactly without
#'   regard to case against full source paths or their final labels.
#' @param modified_after,modified_before Inclusive modification bounds: a Date
#'   or YYYY-MM-DD string includes its entire UTC calendar day; POSIXct supplies
#'   an exact instant. Rows with unknown modification times are excluded when
#'   either bound is supplied. Modification is an item or checked snapshot
#'   timestamp, not record freshness; `modified_source` identifies its origin.
#' @details Values within a filter are combined with OR; different filters and
#'   the search query are combined with AND. Status, geometry, topic, category,
#'   and date filters apply after the bounded scan and checked overlay. A capped
#'   scan can miss matching older items; inspect `discovery_complete` and use
#'   `max_items = Inf` with an appropriate time budget for an exhaustive scan.
#' @return A tibble with stable IDs, service and layer locations, portal and
#'   item IDs when available, and `validation_status` of `"checked"` or
#'   `"discovered"`. The latter means the package has not checked that layer.
#'   Skipped item errors are attached as `attr(result, "discovery_issues")`;
#'   failed portal names are in `attr(result, "discovery_failed_portals")`.
#'   `discovery_scanned_items` records item counts by portal;
#'   `discovery_truncated_portals` identifies scans stopped at `max_items`.
#'   `discovery_complete` is FALSE if a scan was truncated or any item or portal
#'   failed. These attributes describe live discovery, not checked coverage.
#' @noRd
#' @examples
#' checked <- tbod_list_datasets(source = "checked")
#' checked[, c("id", "title", "jurisdiction", "validation_status")]
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   tbod_list_datasets(max_items = 1)
#' }
.list_datasets_impl <- function(jurisdiction = "all", source = "all",
                          portals = "all", max_items = 25, timeout = 30,
                          total_timeout = 90, publisher = NULL,
                          validation_status = NULL, spatial = NULL, topic = NULL,
                          category = NULL, modified_after = NULL, modified_before = NULL) {
  timeout <- .operation_timeout(timeout, total_timeout)
  .check_operation_timeout(timeout)
  result <- .catalog_datasets(NULL, jurisdiction, source, portals, max_items, timeout,
    publisher, validation_status, spatial, topic, category, modified_after, modified_before)
  .check_operation_timeout(timeout)
  result
}

#' Search Tampa Bay ArcGIS datasets
#'
#' Live searches use the selected public ArcGIS portal indexes. Checked entries are
#' also matched locally by literal, case-insensitive words in their ID, title,
#' description, category, and tags. Portal search can include other indexed
#' fields, so its results need not follow the checked catalog's literal matching.
#' @param query A single search string. Checked matching treats punctuation
#'   literally; live matching uses the ArcGIS portal search index.
#' @inheritParams .list_datasets_impl
#' @return A tibble with the catalog columns and, for live searches, the
#'   discovery attributes described in [tbod_list_datasets()]. A checked-only
#'   search reads the bundled registry without network access.
#' @noRd
#' @examples
#' permits <- tbod_search_datasets("permit", source = "checked")
#' permits[, c("id", "title", "jurisdiction")]
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   tbod_search_datasets("housing", max_items = 1)
#' }
.search_datasets_impl <- function(query, jurisdiction = "all", source = "all",
                            portals = "all", max_items = 25, timeout = 30,
                            total_timeout = 90, publisher = NULL,
                            validation_status = NULL, spatial = NULL, topic = NULL,
                            category = NULL, modified_after = NULL, modified_before = NULL) {
  .string(query, "query", allow_empty = TRUE)
  timeout <- .operation_timeout(timeout, total_timeout)
  .check_operation_timeout(timeout)
  result <- .catalog_datasets(query, jurisdiction, source, portals, max_items, timeout,
    publisher, validation_status, spatial, topic, category, modified_after, modified_before)
  .check_operation_timeout(timeout)
  result
}

.catalog_datasets <- function(query, jurisdiction, source, portals, max_items, timeout,
                              publisher = NULL, validation_status = NULL,
                              spatial = NULL, topic = NULL, category = NULL,
                              modified_after = NULL, modified_before = NULL) {
  .catalog_options(source, portals, max_items, timeout)
  entries <- .read_registry()
  configs <- .portal_registry()
  filters <- .catalog_filters(jurisdiction, publisher, validation_status, spatial,
    topic, category, modified_after, modified_before, entries, configs)
  checked <- .catalog_table(entries)
  matching_checked <- if (is.null(query)) checked else .search_checked(checked, query)
  if (identical(source, "checked")) return(.filter_catalog(matching_checked, filters))
  keys <- .catalog_selected_portals(.discovery_portal_keys(portals), configs, filters)
  if (!length(keys)) {
    result <- if (identical(source, "all")) matching_checked else checked[0L, , drop = FALSE]
    result <- .attach_discovery_metadata(result, .discovery_metadata())
    return(.filter_catalog(result, filters))
  }
  scan_portals <- if (identical(portals, "all") && identical(keys, names(configs))) "all" else keys
  live <- .catalog_live(query, source, scan_portals, max_items, timeout)
  if (is.null(live)) {
    attr(matching_checked, "discovery_complete") <- FALSE
    return(.filter_catalog(matching_checked, filters))
  }
  included_checked <- if (identical(source, "all")) matching_checked else checked[0L, , drop = FALSE]
  .filter_catalog(.overlay_catalog(live, checked, included_checked), filters)
}

.catalog_options <- function(source, portals, max_items, timeout) {
  .string(source, "source")
  if (!source %in% c("all", "live", "checked")) {
    .abort("`source` must be 'all', 'live', or 'checked'.", subclass = "tampa_input_error")
  }
  .discovery_portal_keys(portals)
  .number(max_items, "max_items", min = 1, integer = TRUE, infinity = TRUE)
  .number(timeout, "timeout", min = .Machine$double.eps)
}

.search_checked <- function(catalog, query) {
  if (!nrow(catalog)) return(catalog)
  words <- strsplit(tolower(trimws(query)), "[[:space:]]+")[[1L]]
  words <- words[nzchar(words)]
  if (!length(words)) return(catalog)
  values <- cbind(catalog$id, catalog$title, catalog$description,
                  catalog$category,
                  vapply(catalog$tags, paste, character(1), collapse = " "))
  values[is.na(values)] <- ""
  text <- tolower(apply(values, 1L, paste, collapse = " "))
  keep <- rep(TRUE, nrow(catalog))
  for (word in words) keep <- keep & grepl(word, text, fixed = TRUE)
  catalog[keep, , drop = FALSE]
}

.catalog_live <- function(query, source, portals, max_items, timeout) {
  tryCatch(.discover_arcgis(query = query, portals = portals, max_items = max_items,
                            timeout = timeout),
           error = function(e) {
             if (inherits(e, "tampa_timeout_error")) stop(e)
             if (identical(source, "live") || !inherits(e, "tampa_data_error")) stop(e)
             warning(paste0("Live ArcGIS discovery failed; returning checked datasets only: ",
                            conditionMessage(e)), call. = FALSE)
             NULL
           })
}

.overlay_catalog <- function(live, checked, included_checked) {
  metadata <- attributes(live)[names(.discovery_metadata())]
  metadata$discovery_issues <- metadata$discovery_issues %||% character()
  metadata$discovery_failed_portals <- metadata$discovery_failed_portals %||% character()
  # The overlay supplies these five checked-catalog fields after validating live rows.
  required <- setdiff(names(checked), c("category", "verified", "terms",
                                        "date_fields", "modified_source"))
  if (!inherits(live, "data.frame") || !all(required %in% names(live))) {
    .abort("Live discovery returned an invalid catalog table.", subclass = "tampa_response_error")
  }
  live$category <- vapply(live$categories, function(x) {
    if (length(x)) x[[1L]] else NA_character_
  }, character(1))
  live$verified <- as.Date(rep(NA_character_, nrow(live)))
  live$terms <- rep(NA_character_, nrow(live))
  live$date_fields <- rep(list(character()), nrow(live))
  live$modified_source <- ifelse(is.na(live$modified), NA_character_, "portal_item")
  live <- live[, names(checked), drop = FALSE]
  key <- function(x) paste(tolower(sub("/+$", "", x$service_url)), x$layer_id,
                           sep = "#")
  if (nrow(live)) {
    live <- live[order(key(live), live$item_id, na.last = TRUE), , drop = FALSE]
    live <- live[!duplicated(key(live)), , drop = FALSE]
  }
  checked_key <- key(checked)
  live_key <- key(live)
  matched <- checked[checked_key %in% c(live_key, key(included_checked)), , drop = FALSE]
  for (i in seq_len(nrow(matched))) {
    j <- match(key(matched[i, , drop = FALSE]), live_key)
    if (is.na(j)) next
    if (!is.na(live$modified[[j]])) {
      matched$modified[[i]] <- live$modified[[j]]
      matched$modified_source[[i]] <- "portal_item"
    }
    matched$tags[[i]] <- unique(c(matched$tags[[i]], live$tags[[j]]))
    matched$categories[[i]] <- unique(c(matched$categories[[i]], live$categories[[j]]))
    matched$original_metadata[[i]]$discovery <- live$original_metadata[[j]]
  }
  unmatched <- live[!live_key %in% checked_key, , drop = FALSE]
  result <- rbind(matched, unmatched)
  rownames(result) <- NULL
  result <- tibble::as_tibble(result)
  .attach_discovery_metadata(result, metadata)
}

#' Inspect a checked or discovered dataset and its source
#'
#' A checked package ID reads the offline registry. A one-row discovery result
#' carries its portal metadata; a stable `arcgis:<item-id>:<layer-id>` identifier
#' looks up the current portal item. Set `refresh = TRUE` to retrieve the current
#' layer schema, aliases, field types,
#' CRS, query capabilities, and upstream editing metadata when available.
#' Registry verification dates are endpoint checks, not dates when government
#' records were updated.
#' @param id Checked package ID, one-row discovery descriptor, or stable
#'   ArcGIS item/layer identifier.
#' @param jurisdiction Checked-registry jurisdiction. Omit to resolve a unique
#'   checked package ID across all cities. For a discovery result or stable
#'   ArcGIS ID, omission uses its source jurisdiction.
#' @param refresh Whether to request live layer metadata.
#' @param timeout Per-request timeout in seconds.
#' @param total_timeout Maximum elapsed seconds for inspection, including
#'   metadata requests and retries. Defaults to 60; `Inf` disables this limit.
#' @return A named list of dataset metadata, including its ID, title, publisher,
#'   jurisdiction, source URL, and service URL. With `refresh = TRUE`, the list
#'   also contains `fields` (a tibble of source field names, types, and aliases),
#'   `metadata` (raw ArcGIS layer metadata), and `inspected_at` (UTC).
#' @noRd
#' @examples
#' info <- tbod_dataset_info("construction-permits")
#' info[c("id", "title", "publisher", "source_url")]
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   current <- tbod_dataset_info("construction-permits", refresh = TRUE)
#'   current$fields
#' }
.dataset_info_impl <- function(id, jurisdiction = NULL, refresh = FALSE, timeout = 30,
                         total_timeout = 60) {
  .flag(refresh, "refresh")
  timeout <- .operation_timeout(timeout, total_timeout)
  .check_operation_timeout(timeout)
  requested_jurisdiction <- .requested_jurisdiction(
    id, jurisdiction, missing(jurisdiction))
  entry <- .resolve_dataset(id, requested_jurisdiction, timeout)
  if (refresh) {
    metadata <- arcgis_layer(entry, timeout)
    entry$fields <- tibble::tibble(
      name = .field_names(metadata),
      type = vapply(metadata$fields, function(x) x$type, character(1)),
      alias = vapply(metadata$fields, function(x) x$alias %||% x$name, character(1)))
    entry$metadata <- metadata
    entry$inspected_at <- .utc_now()
  }
  .check_operation_timeout(timeout)
  entry
}

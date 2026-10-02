#' List Tampa Bay ArcGIS datasets
#'
#' Live discovery searches the City of Tampa and Tampa Bay Regional Planning
#' Council ArcGIS organizations and expands public services into candidate
#' layers and tables. Retrieval checks each layer's current Query capability.
#' The bundled registry supplies a separate
#' `"checked"` validation layer and remains available without a network request.
#' A portal item can be stale or a layer can change after discovery.
#' @param jurisdiction Checked-registry jurisdiction. v0.1 has City of Tampa
#'   checked entries. Live organizations are selected with `portals`.
#' @param source `"all"` (default) combines live discovery with the checked
#'   registry; `"live"` returns layers found through the portal with checked
#'   matches marked; `"checked"` reads only the offline registry.
#' @param max_items Maximum number of portal service items to scan per selected
#'   organization. `Inf` (default) follows all available search pages. This
#'   limits items, not expanded layers.
#' @param portals Live ArcGIS organizations to search: `"city"`, `"tbrpc"`
#'   (Tampa Bay Regional Planning Council), or `"all"` (default). A character
#'   vector of `"city"` and `"tbrpc"` is also accepted. This does not filter the
#'   bundled checked catalog.
#' @param timeout Timeout in seconds for each HTTP attempt.
#' @return A tibble with stable IDs, service and layer locations, portal and
#'   item IDs when available, and `validation_status` of `"checked"` or
#'   `"discovered"`. The latter means the package has not checked that layer.
#'   Skipped item errors are attached as `attr(result, "discovery_issues")`;
#'   failed portal names are in `attr(result, "discovery_failed_portals")`.
#' @export
#' @examples
#' list_datasets(source = "checked")
#' \dontrun{list_datasets()}
list_datasets <- function(jurisdiction = "tampa", source = "all",
                          portals = "all", max_items = Inf, timeout = 30) {
  .catalog_options(source, portals, max_items, timeout)
  checked <- .catalog_table(.jurisdiction_entries(jurisdiction))
  if (identical(source, "checked")) return(checked)
  live <- .catalog_live(NULL, source, portals, max_items, timeout)
  if (is.null(live)) return(checked)
  .overlay_catalog(live, checked, include_all_checked = identical(source, "all"))
}

#' Search Tampa Bay ArcGIS datasets
#'
#' Live searches use the selected public ArcGIS portal indexes. Checked entries are
#' also matched locally by literal, case-insensitive words in their ID, title,
#' description, category, and tags. Portal search can include other indexed
#' fields, so its results need not follow the checked catalog's literal matching.
#' @param query A single search string. Checked matching treats punctuation
#'   literally; live matching uses the ArcGIS portal search index.
#' @inheritParams list_datasets
#' @return A tibble with the same columns as [list_datasets()].
#' @export
#' @examples
#' search_datasets("permit", source = "checked")
#' \dontrun{search_datasets("housing")}
search_datasets <- function(query, jurisdiction = "tampa", source = "all",
                            portals = "all", max_items = Inf, timeout = 30) {
  .string(query, "query", allow_empty = TRUE)
  .catalog_options(source, portals, max_items, timeout)
  checked <- .search_checked(.catalog_table(.jurisdiction_entries(jurisdiction)), query)
  if (identical(source, "checked")) return(checked)
  live <- .catalog_live(query, source, portals, max_items, timeout)
  if (is.null(live)) return(checked)
  .overlay_catalog(live, checked, include_all_checked = identical(source, "all"))
}

.catalog_options <- function(source, portals, max_items, timeout) {
  .string(source, "source")
  if (!source %in% c("all", "live", "checked")) {
    .abort("`source` must be 'all', 'live', or 'checked'.", subclass = "tampa_input_error")
  }
  if (!is.character(portals) || !length(portals) || anyNA(portals) ||
      any(!portals %in% c("city", "tbrpc", "all")) ||
      ("all" %in% portals && length(portals) != 1L) || anyDuplicated(portals)) {
    .abort("`portals` must be 'city', 'tbrpc', 'all', or both named portals.",
           subclass = "tampa_input_error")
  }
  .number(max_items, "max_items", min = 1, integer = TRUE, infinity = TRUE)
  .number(timeout, "timeout", min = .Machine$double.eps)
}

.search_checked <- function(catalog, query) {
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
             if (identical(source, "live") || !inherits(e, "tampa_data_error")) stop(e)
             warning(paste0("Live ArcGIS discovery failed; returning checked datasets only: ",
                            conditionMessage(e)), call. = FALSE)
             NULL
           })
}

.overlay_catalog <- function(live, checked, include_all_checked) {
  issues <- attr(live, "discovery_issues", exact = TRUE)
  failed_portals <- attr(live, "discovery_failed_portals", exact = TRUE)
  required <- c("id", "title", "description", "jurisdiction", "publisher", "source_url",
                "service_url", "layer_id", "item_id", "portal", "geometry_type",
                "tags", "categories", "modified", "service_type", "layer_type",
                "validation_status", "original_metadata")
  if (!inherits(live, "data.frame") || !all(required %in% names(live))) {
    .abort("Live discovery returned an invalid catalog table.", subclass = "tampa_response_error")
  }
  live$category <- vapply(live$categories, function(x) {
    if (length(x)) x[[1L]] else NA_character_
  }, character(1))
  live$verified <- as.Date(rep(NA_character_, nrow(live)))
  live$terms <- rep(NA_character_, nrow(live))
  live$date_fields <- rep(list(character()), nrow(live))
  live <- live[, names(checked), drop = FALSE]
  key <- function(x) paste(tolower(sub("/+$", "", x$service_url)), x$layer_id,
                           sep = "#")
  if (nrow(live)) {
    live <- live[order(key(live), live$item_id, na.last = TRUE), , drop = FALSE]
    live <- live[!duplicated(key(live)), , drop = FALSE]
  }
  checked_key <- key(checked)
  live_key <- key(live)
  matched <- checked[checked_key %in% live_key, , drop = FALSE]
  unmatched <- live[!live_key %in% checked_key, , drop = FALSE]
  if (include_all_checked) matched <- checked
  result <- rbind(matched, unmatched)
  rownames(result) <- NULL
  result <- tibble::as_tibble(result)
  attr(result, "discovery_issues") <- issues %||% character()
  attr(result, "discovery_failed_portals") <- failed_portals %||% character()
  result
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
#' @param jurisdiction Checked-registry jurisdiction. Omit for a discovered
#'   result or stable ArcGIS ID so its source jurisdiction is used.
#' @param refresh Whether to request live layer metadata.
#' @param timeout Per-request timeout in seconds.
#' @return A named list of dataset metadata. Live inspection adds `fields`
#'   (a tibble), `metadata` (the raw layer metadata), and `inspected_at` (UTC).
#' @export
#' @examples
#' dataset_info("construction-permits")
#' \dontrun{
#' info <- dataset_info("construction-permits", refresh = TRUE)
#' info$fields
#' }
dataset_info <- function(id, jurisdiction = "tampa", refresh = FALSE, timeout = 30) {
  .flag(refresh, "refresh")
  .number(timeout, "timeout", min = .Machine$double.eps)
  requested_jurisdiction <- if (missing(jurisdiction) &&
                                (!is.character(id) ||
                                 (length(id) == 1L && !is.na(id) &&
                                  startsWith(id, "arcgis:")))) {
    NULL
  } else jurisdiction
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
  entry
}

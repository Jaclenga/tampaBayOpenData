#' List datasets in the bundled catalog
#'
#' By default, scans the configured Tampa Bay ArcGIS portals and combines their
#' layers with the bundled checked catalog. Use `source = "checked"` to list
#' checked entries offline. Live scans may be incomplete; see Details for the
#' result attributes. Use [tbod_discover()] to scan another portal.
#' @param jurisdiction Jurisdiction code or vector of codes from
#'   [tbod_list_portals()], or `"all"` (default). Filters checked and live
#'   results and narrows the portal scan.
#' @param source `"all"` (default) combines live discovery with checked entries;
#'   `"live"` returns portal layers with checked matches marked; `"checked"`
#'   reads only the offline registry.
#' @param portals Configured publisher IDs from [tbod_list_portals()], or
#'   `"all"`. This selects live portals and does not filter checked entries.
#' @param max_items Maximum number of service items scanned per selected
#'   portal. Defaults to 25; `Inf` follows all search pages. An item can
#'   expand to multiple layers, so this does not bound the row count.
#' @param timeout Per-request timeout in seconds.
#' @param total_timeout Overall operation budget, including retries and live
#'   discovery. Defaults to 90 seconds; `Inf` disables the deadline.
#' @param publisher Publisher name or vector, matched exactly without regard
#'   to case. Narrows both checked results and the live portal scan.
#' @param validation_status `"checked"`, `"discovered"`, or a vector of both;
#'   `NULL` includes both. `source = "live"` can include checked matches.
#' @param spatial `TRUE` selects layers with declared geometry, `FALSE`
#'   selects nonspatial tables, and `NULL` includes both and unknown geometry.
#' @param topic Word or vector matched as case-insensitive literal substrings
#'   in tags and categories; `NULL` disables the filter.
#' @param category Category or vector matched, ignoring case, against full
#'   source paths or their final labels.
#' @param modified_after,modified_before Inclusive modification bounds. A
#'   Date or YYYY-MM-DD string includes its full UTC day; POSIXct specifies an
#'   instant. Unknown modification times are excluded when a bound is set.
#'   This is an item or checked snapshot time, not record freshness.
#' @details Values within a filter are combined with OR; different filters
#'   and a search query are combined with AND. Status, geometry, topic,
#'   category, and date filters apply after the bounded live scan and checked
#'   overlay. A capped scan can miss older matching items. For an exhaustive
#'   scan, use `max_items = Inf` with an appropriate time budget and inspect
#'   `attr(result, "discovery_complete")`. Live results also carry
#'   `discovery_issues`, `discovery_failed_portals`,
#'   `discovery_scanned_items`, and `discovery_truncated_portals` attributes.
#' @return A tibble with stable IDs, service and layer locations, portal and
#'   item IDs when available, and `validation_status` of `"checked"` or
#'   `"discovered"`. Live results include scan-completeness and issue attributes
#'   described in Details.
#' @export
#' @examples
#' tbod_list_datasets(source = "checked")
tbod_list_datasets <- function(jurisdiction = "all", source = "all",
                               portals = "all", max_items = 25, timeout = 30,
                               total_timeout = 90, publisher = NULL,
                               validation_status = NULL, spatial = NULL,
                               topic = NULL, category = NULL,
                               modified_after = NULL, modified_before = NULL) {
  .list_datasets_impl(jurisdiction = jurisdiction, source = source, portals = portals,
                max_items = max_items, timeout = timeout,
                total_timeout = total_timeout, publisher = publisher,
                validation_status = validation_status, spatial = spatial,
                topic = topic, category = category,
                modified_after = modified_after,
                modified_before = modified_before)
}

#' Search datasets in the bundled catalog
#'
#' Searches checked Tampa Bay entries and, when requested, configured live
#' ArcGIS portals. Checked entries match literal, case-insensitive words in
#' their IDs, titles, descriptions, categories, and tags. Live searches use
#' each portal's index, so matching can differ. Use [tbod_discover()] to search
#' another ArcGIS portal.
#' @param query A single search string. Checked matching treats punctuation
#'   literally; live matching uses the ArcGIS portal index.
#' @inheritParams tbod_list_datasets
#' @details Values within a filter are combined with OR; different filters
#'   and the search query are combined with AND. Filters apply after the
#'   bounded scan, so a capped scan can miss matching items. See
#'   [tbod_list_datasets()] for the discovery attributes.
#' @return A tibble with the same columns and live discovery attributes as
#'   [tbod_list_datasets()]. A checked-only search requires no network request.
#' @export
#' @examples
#' tbod_search_datasets("permit", source = "checked")
tbod_search_datasets <- function(query, jurisdiction = "all", source = "all",
                                 portals = "all", max_items = 25, timeout = 30,
                                 total_timeout = 90, publisher = NULL,
                                 validation_status = NULL, spatial = NULL,
                                 topic = NULL, category = NULL,
                                 modified_after = NULL, modified_before = NULL) {
  .search_datasets_impl(query = query, jurisdiction = jurisdiction, source = source,
                  portals = portals, max_items = max_items, timeout = timeout,
                  total_timeout = total_timeout, publisher = publisher,
                  validation_status = validation_status, spatial = spatial,
                  topic = topic, category = category,
                  modified_after = modified_after,
                  modified_before = modified_before)
}

#' Discover datasets from an ArcGIS portal
#'
#' Searches a public ArcGIS portal or lists layers from a FeatureServer or
#' MapServer service or layer URL. Pass a result row to [tbod_get_dataset()] to
#' retrieve it. Portal rows have `discovered` status; service URL rows have
#' `not_checked` status because they have no portal item identity. Publisher
#' services can change after discovery.
#' @details A portal search scans at most `max_items` service items, then
#'   expands queryable layers. For a FeatureServer or MapServer URL, discovery
#'   enumerates the service's layers; `query` filters their names. The result
#'   reports scan completeness and item errors as attributes.
#' @param portal Public HTTPS ArcGIS sharing REST root ending in
#'   `/sharing/rest`, or FeatureServer/MapServer service or layer URL.
#' @param query Optional portal search text. For a service URL, a literal
#'   case-insensitive layer-name filter.
#' @param max_items Maximum service items to scan in a portal or layers to
#'   inspect in a service. Defaults to 25; `Inf` scans all available entries.
#'   A capped portal search can omit matching layers from older items.
#' @param timeout Per-request timeout in seconds.
#' @param total_timeout Maximum elapsed seconds for the operation. Defaults to
#'   90; `Inf` disables this limit.
#' @param org_id Optional ArcGIS organization ID to restrict a portal search.
#'   This argument does not apply to service URLs.
#' @param publisher Publisher label to attach to discovery rows. If NULL, a
#'   portal organization name is used when available; service URLs use an
#'   unknown-publisher label.
#' @param jurisdiction Jurisdiction label to attach to discovery rows. Defaults
#'   to `"unspecified"` for a custom portal.
#' @return A tibble of discovered ArcGIS layers. Discovery issues, scan counts,
#'   truncation, and completeness are attached as attributes; check
#'   `attr(rows, "discovery_complete")` before assuming a complete search.
#' @export
#' @examples
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   rows <- tbod_discover("https://www.arcgis.com/sharing/rest",
#'                         query = "parks", max_items = 5)
#' }
tbod_discover <- function(portal, query = NULL, max_items = 25, timeout = 30,
                          total_timeout = 90, org_id = NULL, publisher = NULL,
                          jurisdiction = "unspecified") {
  timeout <- .operation_timeout(timeout, total_timeout)
  .check_operation_timeout(timeout)
  rows <- .discover_custom_portal(portal = portal, query = query,
                                  max_items = max_items, timeout = timeout,
                                  org_id = org_id, publisher = publisher,
                                  jurisdiction = jurisdiction)
  .check_operation_timeout(timeout)
  rows
}

#' List bundled ArcGIS publisher configurations
#'
#' Returns the package's Tampa Bay publisher configurations without a network
#' request. Each entry provides an ArcGIS organization ID and sharing REST
#' root. Its `verified` date checks publisher identity, not every layer's
#' contents or reuse terms. To scan another portal, pass its sharing REST URL
#' to [tbod_discover()].
#' @return A tibble with `id` (the discovery selector), `root`, `org_id`,
#'   `publisher`, `jurisdiction`, `website`, `verified` (a Date),
#'   `metadata_url`, and `evidence_url`. Use `id` in the `portals` argument of
#'   [tbod_list_datasets()] or [tbod_search_datasets()].
#' @export
#' @examples
#' tbod_list_portals()
tbod_list_portals <- function() {
  .list_portals_impl()
}


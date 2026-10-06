#' List datasets in the bundled catalog
#'
#' The bundled Tampa Bay catalog includes checked entries that are available
#' offline and live entries from its configured publishers. Use
#' [tbod_discover()] to scan another ArcGIS portal. The unprefixed
#' [list_datasets()] entry point remains available for existing code.
#' @inheritParams list_datasets
#' @return A dataset catalog tibble, with discovery attributes for live scans.
#' @export
#' @examples
#' tbod_list_datasets(source = "checked")
tbod_list_datasets <- function(jurisdiction = "all", source = "all",
                               portals = "all", max_items = 25, timeout = 30,
                               total_timeout = 90, publisher = NULL,
                               validation_status = NULL, spatial = NULL,
                               topic = NULL, category = NULL,
                               modified_after = NULL, modified_before = NULL) {
  list_datasets(jurisdiction = jurisdiction, source = source, portals = portals,
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
#' ArcGIS portals. Use [tbod_discover()] to search another ArcGIS portal.
#' The unprefixed [search_datasets()] entry point remains available for
#' existing code.
#' @inheritParams search_datasets
#' @return A dataset catalog tibble, with discovery attributes for live scans.
#' @export
#' @examples
#' tbod_search_datasets("permit", source = "checked")
tbod_search_datasets <- function(query, jurisdiction = "all", source = "all",
                                 portals = "all", max_items = 25, timeout = 30,
                                 total_timeout = 90, publisher = NULL,
                                 validation_status = NULL, spatial = NULL,
                                 topic = NULL, category = NULL,
                                 modified_after = NULL, modified_before = NULL) {
  search_datasets(query = query, jurisdiction = jurisdiction, source = source,
                  portals = portals, max_items = max_items, timeout = timeout,
                  total_timeout = total_timeout, publisher = publisher,
                  validation_status = validation_status, spatial = spatial,
                  topic = topic, category = category,
                  modified_after = modified_after,
                  modified_before = modified_before)
}

#' Discover datasets from an ArcGIS portal
#'
#' Searches public service items in an ArcGIS REST portal or enumerates layers
#' from a FeatureServer or MapServer service root or layer URL. The source can be outside
#' the bundled Tampa Bay catalog. Discovery rows can be
#' passed directly to [tbod_get_dataset()]. Discovery is a current portal
#' search, not a guarantee that an item or layer will remain available. Portal
#' rows have `discovered` status; rows from a service URL have `not_checked`
#' status because no portal item identity is available.
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
#' request. To scan another portal, pass its sharing REST URL to
#' [tbod_discover()].
#' @return A tibble of bundled publisher names, jurisdiction labels, ArcGIS
#'   organization IDs, and portal roots.
#' @export
tbod_list_portals <- function() {
  list_portals()
}

#' Inspect a dataset and its source
#'
#' Accepts a bundled ID, one-row discovery result, stable ArcGIS ID, or direct
#' public HTTPS layer URL. With `refresh = TRUE`, retrieves the live layer
#' metadata. Use [tbod_schema()] to inspect the expected or current fields and
#' [tbod_check_schema()] to compare them.
#' @inheritParams dataset_info
#' @param id Bundled ID, one-row discovery result, stable ArcGIS ID, or public
#'   HTTPS ArcGIS layer URL.
#' @param jurisdiction Optional bundled catalog jurisdiction. `NULL` resolves a
#'   unique bundled ID and preserves a discovery result's jurisdiction. Direct
#'   URLs do not accept a jurisdiction override.
#' @param portal Optional ArcGIS sharing REST portal URL when `id` is a stable
#'   `arcgis:<item-id>:<layer-id>` identifier.
#' @return A named list of source information; with `refresh = TRUE` it also
#'   contains the current fields and raw ArcGIS metadata.
#' @export
tbod_dataset_info <- function(id, jurisdiction = NULL, refresh = FALSE,
                              timeout = 30, total_timeout = 60,
                              portal = NULL) {
  resolved <- .tbod_resolve_portal_id(id, portal, timeout, total_timeout)
  id <- resolved$id
  timeout <- resolved$timeout
  if (.tbod_is_url(id)) {
    if (!is.null(jurisdiction)) {
      .abort("`jurisdiction` does not apply to a direct ArcGIS URL.",
             subclass = "tampa_input_error")
    }
    id <- .direct_arcgis_descriptor(id)
  }
  dataset_info(id, jurisdiction = jurisdiction, refresh = refresh,
               timeout = timeout, total_timeout = total_timeout)
}

#' Retrieve a bundled, discovered, or direct ArcGIS dataset
#'
#' Accepts a checked catalog ID, a one-row discovery result, a stable
#' `arcgis:<item-id>:<layer-id>` identifier, or a public HTTPS ArcGIS layer URL
#' ending in `/FeatureServer/<id>` or `/MapServer/<id>`. For a stable ArcGIS ID
#' from an Enterprise portal, supply that portal's sharing REST URL in `portal`.
#' Direct URLs use the same retrieval engine and carry `not_checked` provenance.
#' For a bundled checked layer, retrieval compares current metadata with its
#' expected schema, warns for compatible drift, and errors before querying for
#' incompatible drift. Use [tbod_check_schema()] to inspect the differences.
#' The unprefixed [get_dataset()] and [get_arcgis_layer()] entry points remain
#' available for existing code.
#' @inheritParams get_dataset
#' @param id Bundled ID, one-row discovery result, stable
#'   `arcgis:<item-id>:<layer-id>` identifier, or public HTTPS ArcGIS layer URL
#'   ending in `/FeatureServer/<id>` or `/MapServer/<id>`.
#' @param jurisdiction Optional checked-catalog jurisdiction. `NULL` resolves a
#'   unique checked ID across the bundled catalog and preserves the source
#'   jurisdiction of a discovery result. Direct URLs use `"unspecified"` and
#'   do not accept a jurisdiction override.
#' @param portal Optional public HTTPS ArcGIS sharing REST portal URL for a
#'   stable `arcgis:<item-id>:<layer-id>` identifier. Omit to use the global
#'   ArcGIS item lookup. This argument does not apply to other input types.
#' @return A tibble, or an sf object when `spatial = TRUE`, with source and
#'   retrieval metadata attached. Read it with [tbod_provenance()].
#' @export
#' @examples
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   data <- tbod_get_dataset("construction-permits", limit = 5)
#'   tbod_provenance(data)$source_url
#' }
tbod_get_dataset <- function(id, jurisdiction = NULL, where = "1=1",
                             fields = NULL, spatial = FALSE, out_sr = NULL,
                             order_by = NULL, limit = Inf, page_size = NULL,
                             query = list(), timeout = 30, total_timeout = 120,
                             integrity = "auto", portal = NULL) {
  resolved <- .tbod_resolve_portal_id(id, portal, timeout, total_timeout)
  id <- resolved$id
  timeout <- resolved$timeout
  if (.tbod_is_url(id)) {
    if (!is.null(jurisdiction)) {
      .abort("`jurisdiction` does not apply to a direct ArcGIS URL.",
             subclass = "tampa_input_error")
    }
    return(get_arcgis_layer(id, where = where, fields = fields,
                            spatial = spatial, out_sr = out_sr,
                            order_by = order_by, limit = limit,
                            page_size = page_size, query = query,
                            timeout = timeout, total_timeout = total_timeout,
                            integrity = integrity))
  }
  get_dataset(id, jurisdiction = jurisdiction, where = where, fields = fields,
              spatial = spatial, out_sr = out_sr, order_by = order_by,
              limit = limit, page_size = page_size, query = query,
              timeout = timeout, total_timeout = total_timeout,
              integrity = integrity)
}

.tbod_is_url <- function(id) {
  is.character(id) && length(id) == 1L && !is.na(id) &&
    grepl("^https?://", id, ignore.case = TRUE)
}

.tbod_resolve_portal_id <- function(id, portal, timeout, total_timeout) {
  stable_id <- is.character(id) && length(id) == 1L && !is.na(id) &&
    grepl("^arcgis:[0-9a-fA-F]{32}:[0-9]+$", id)
  if (is.null(portal)) return(list(id = id, timeout = timeout))
  if (!stable_id) {
    .abort("`portal` applies only to a stable `arcgis:<item-id>:<layer-id>` identifier.",
           subclass = "tampa_input_error")
  }
  .string(portal, "portal")
  parts <- strsplit(id, ":", fixed = TRUE)[[1L]]
  layer_id <- suppressWarnings(as.numeric(parts[[3L]]))
  if (!is.finite(layer_id) || layer_id > .Machine$integer.max) {
    .abort("The ArcGIS identifier has an invalid layer ID.",
           subclass = "tampa_input_error")
  }
  timeout <- .operation_timeout(timeout, total_timeout)
  rows <- .discover_arcgis_item(parts[[2L]], as.integer(layer_id),
                                portal = portal, timeout = timeout)
  if (!is.data.frame(rows) || nrow(rows) != 1L) {
    .abort(paste0("ArcGIS item `", parts[[2L]], "` layer ", layer_id,
                  " is unavailable or is not a supported query layer."),
           subclass = "tampa_input_error")
  }
  list(id = rows, timeout = timeout)
}

#' Retrieve a direct ArcGIS layer URL
#'
#' This prefixed convenience entry point uses [tbod_get_dataset()] with a
#' public HTTPS ArcGIS FeatureServer or MapServer layer URL.
#' @param url Public HTTPS ArcGIS layer URL.
#' @inheritParams get_arcgis_layer
#' @return A tibble or sf object with retrieval provenance attached.
#' @export
tbod_get_arcgis_layer <- function(url, where = "1=1", fields = NULL,
                                 spatial = FALSE, out_sr = NULL,
                                 order_by = NULL, limit = Inf, page_size = NULL,
                                 query = list(), timeout = 30,
                                 total_timeout = 120, integrity = "auto") {
  tbod_get_dataset(url, where = where, fields = fields, spatial = spatial,
                   out_sr = out_sr, order_by = order_by, limit = limit,
                   page_size = page_size, query = query, timeout = timeout,
                   total_timeout = total_timeout, integrity = integrity)
}

#' Download a dataset into resumable chunks
#'
#' Accepts a bundled ID, discovery row, stable ArcGIS ID, or direct ArcGIS
#' layer URL. A custom Enterprise portal can be provided with stable IDs.
#' Bundled checked layers are compared with expected schemas before downloading;
#' compatible drift warns and incompatible drift stops the download.
#' @inheritParams download_dataset
#' @param id Bundled ID, one-row discovery result, stable ArcGIS ID, or direct
#'   public HTTPS ArcGIS layer URL.
#' @param jurisdiction Optional bundled catalog jurisdiction. `NULL` resolves a
#'   unique bundled ID and preserves a discovery result's jurisdiction. Direct
#'   URLs do not accept a jurisdiction override.
#' @param portal Optional ArcGIS sharing REST portal URL when `id` is a stable
#'   `arcgis:<item-id>:<layer-id>` identifier.
#' @return A download summary with saved chunk paths and provenance.
#' @export
tbod_download_dataset <- function(id, path, jurisdiction = NULL,
                                  where = "1=1", fields = NULL,
                                  spatial = FALSE, out_sr = NULL,
                                  page_size = 1000, query = list(),
                                  timeout = 30, total_timeout = Inf,
                                  resume = TRUE, portal = NULL) {
  resolved <- .tbod_resolve_portal_id(id, portal, timeout, total_timeout)
  id <- resolved$id
  timeout <- resolved$timeout
  if (.tbod_is_url(id)) {
    if (!is.null(jurisdiction)) {
      .abort("`jurisdiction` does not apply to a direct ArcGIS URL.",
             subclass = "tampa_input_error")
    }
    return(download_arcgis_layer(id, path = path, where = where,
                                 fields = fields, spatial = spatial,
                                 out_sr = out_sr, page_size = page_size,
                                 query = query, timeout = timeout,
                                 total_timeout = total_timeout,
                                 resume = resume))
  }
  download_dataset(id, path = path, jurisdiction = jurisdiction,
                   where = where, fields = fields, spatial = spatial,
                   out_sr = out_sr, page_size = page_size, query = query,
                   timeout = timeout, total_timeout = total_timeout,
                   resume = resume)
}

#' Download a direct ArcGIS layer URL
#'
#' This prefixed convenience entry point uses [tbod_download_dataset()] with
#' a public HTTPS ArcGIS FeatureServer or MapServer layer URL.
#' @param url Public HTTPS ArcGIS layer URL.
#' @inheritParams download_arcgis_layer
#' @return A download summary with saved chunk paths and provenance.
#' @export
tbod_download_arcgis_layer <- function(url, path, where = "1=1",
                                      fields = NULL, spatial = FALSE,
                                      out_sr = NULL, page_size = 1000,
                                      query = list(), timeout = 30,
                                      total_timeout = Inf, resume = TRUE) {
  tbod_download_dataset(url, path = path, where = where, fields = fields,
                        spatial = spatial, out_sr = out_sr,
                        page_size = page_size, query = query,
                        timeout = timeout, total_timeout = total_timeout,
                        resume = resume)
}

#' Read retrieval provenance
#'
#' Reads the source, query, completeness, and schema information attached to
#' a result from [tbod_get_dataset()]. The unprefixed
#' [dataset_provenance()] entry point remains available for existing code.
#' @inheritParams dataset_provenance
#' @return The result's attached provenance record.
#' @export
tbod_provenance <- function(x) {
  dataset_provenance(x)
}

#' Retrieve bundled Tampa permit locations
#'
#' Convenience wrapper for the bundled `construction-permits` layer.
#' @param ... Arguments passed to [tbod_get_dataset()] except `id`.
#' @return A tibble or sf object with retrieval provenance attached.
#' @export
tbod_get_permits <- function(...) tbod_get_dataset("construction-permits", ...)

#' Retrieve bundled Tampa development cases
#'
#' Convenience wrapper for the bundled `development-cases` layer.
#' @inheritParams tbod_get_permits
#' @return A tibble or sf object with retrieval provenance attached.
#' @export
tbod_get_development_cases <- function(...) tbod_get_dataset("development-cases", ...)

#' Retrieve bundled Tampa capital projects
#'
#' Convenience wrapper for the bundled `capital-projects` layer.
#' @inheritParams tbod_get_permits
#' @return A tibble or sf object with retrieval provenance attached.
#' @export
tbod_get_capital_projects <- function(...) tbod_get_dataset("capital-projects", ...)

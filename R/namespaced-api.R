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

#' Inspect a dataset and its source
#'
#' Accepts a bundled ID, one-row discovery result, stable ArcGIS ID, or direct
#' public HTTPS layer URL. A checked ID reads its bundled record offline;
#' a stable ArcGIS ID resolves the current portal item. `refresh = TRUE`
#' retrieves current fields, aliases, types, geometry, CRS, query capabilities,
#' and editing metadata. The registry's `verified` date records an endpoint
#' check, not record freshness. Use [tbod_schema()] to inspect the schema or
#' [tbod_check_schema()] to compare it with the checked snapshot.
#' @param refresh Whether to request current ArcGIS layer metadata.
#' @param timeout Per-request timeout in seconds.
#' @param total_timeout Maximum elapsed seconds for inspection, including
#'   metadata requests and retries. Defaults to 60; `Inf` disables it.
#' @param id Bundled ID, one-row discovery result, stable ArcGIS ID, or public
#'   HTTPS ArcGIS layer URL.
#' @param jurisdiction Optional bundled catalog jurisdiction. `NULL` resolves a
#'   unique bundled ID and preserves a discovery result's jurisdiction. Direct
#'   URLs do not accept a jurisdiction override.
#' @param portal Optional ArcGIS sharing REST portal URL when `id` is a stable
#'   `arcgis:<item-id>:<layer-id>` identifier.
#' @return A named list with the dataset ID, title, publisher, jurisdiction,
#'   source and service URLs, scope, and terms. With `refresh = TRUE`, it also
#'   contains `fields` (a tibble of source names, types, and aliases),
#'   `metadata` (raw ArcGIS layer metadata), and UTC `inspected_at`.
#' @export
#' @examples
#' info <- tbod_dataset_info("construction-permits")
#' info[c("id", "title", "publisher", "source_url")]
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
  .dataset_info_impl(id, jurisdiction = jurisdiction, refresh = refresh,
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
#' @details Retrieval requests the current layer schema and matching count.
#'   Full requests also retrieve and validate an object-ID manifest. A small
#'   preview of a large queryable layer can validate only its returned IDs
#'   against the original filter. Missing or duplicate records, truncated
#'   manifests, unexpected responses, and upstream errors fail explicitly.
#'   Full retrieval requires a complete manifest and must be narrowed by
#'   filters if more than one million records match. Use
#'   [tbod_download_dataset()] to save validated chunks to disk.
#'
#'   Source field names, strings, coded values, and date-looking strings are
#'   preserved. ArcGIS epoch-millisecond dates become UTC POSIXct and date-only
#'   fields become Date. Dates declared to have an unknown timezone remain raw
#'   milliseconds with a warning; UTC editor tracking dates can still convert.
#'   Integer values remain integers when safe, larger numeric values become
#'   doubles, and exact big integers can be represented as character values.
#'   NULL or absent attributes become typed missing values. Spatial results
#'   use two-dimensional XY coordinates and exclude Z and M values.
#'
#'   The package does not cache live data. Record membership changes detected
#'   during retrieval cause an error, but attribute changes cannot be frozen.
#'   Accepted responses are limited to 50 MiB and 64 nested JSON containers;
#'   requests do not follow redirects. Native curl, GDAL, and PROJ parsing
#'   remains subject to the installed libraries' behavior.
#' @param where ArcGIS SQL WHERE clause using source field names; defaults to
#'   `"1=1"` for all records. Inspect names with
#'   `tbod_dataset_info(id, refresh = TRUE)`.
#' @param fields Character vector of exact source field names, or `NULL` or
#'   `"*"` for all nongeometry attributes. An object-ID field is requested
#'   internally for integrity checks and omitted from the result if unselected.
#' @param spatial Return an `sf` object. Requires the optional sf package and
#'   supported geometry with a reliably determined CRS.
#' @param out_sr Optional positive ArcGIS/EPSG spatial reference ID for server
#'   projection, such as 4326. Requires `spatial = TRUE`; `NULL` keeps the
#'   native CRS. The response must confirm a requested projection.
#' @param order_by Source fields with ASC or DESC, such as
#'   `c("LASTUPDATE DESC", "RECORD_ID ASC")`. Requires server ordering and
#'   offset pagination; an object-ID tie breaker is added automatically.
#' @param limit Maximum records. `Inf` retrieves all; zero returns a typed
#'   empty result. A deliberate subset is `complete = FALSE` in
#'   [tbod_provenance()] when more matching records exist.
#' @param page_size Optional positive integer batch size, capped at 1,000 and
#'   the service maximum.
#' @param query Named list of advanced ArcGIS filters: `geometry`,
#'   `geometryType`, `inSR`, `spatialRel`, `relationParam`, `time`, `distance`,
#'   `units`, `gdbVersion`, `historicMoment`, `sqlFormat`, and
#'   `datumTransformation`. Values can be scalars or JSON-style lists.
#'   Response format, field selection, aggregation, geometry simplification,
#'   and pagination parameters are protected.
#' @param timeout Per-request timeout in seconds. Transient transport and HTTP
#'   failures may receive three attempts; a generic ArcGIS query error may
#'   receive four.
#' @param total_timeout Overall operation budget in seconds. Defaults to 120;
#'   `Inf` disables it. Requests and retry waits use the remaining budget.
#' @param integrity `"auto"` (default) uses bounded preview validation when a
#'   finite limit is at most 1,000, more than 10,000 records match, and the
#'   layer supports ordering and pagination. The returned IDs are checked
#'   against the original filter. Full retrieval always uses the full object-ID
#'   manifest; `"full"` requires it even for a preview. A zero limit requests
#'   only the count. Provenance records the method used.
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
#' @return A tibble, or an sf object when `spatial = TRUE`. `source`,
#'   `dataset_id`, `jurisdiction`, and `retrieved_at` attributes record the
#'   source and retrieval. Read the complete record with [tbod_provenance()].
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
    return(.get_arcgis_layer_impl(id, where = where, fields = fields,
                            spatial = spatial, out_sr = out_sr,
                            order_by = order_by, limit = limit,
                            page_size = page_size, query = query,
                            timeout = timeout, total_timeout = total_timeout,
                            integrity = integrity))
  }
  .get_dataset_impl(id, jurisdiction = jurisdiction, where = where, fields = fields,
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
#' Calls [tbod_get_dataset()] with a public HTTPS ArcGIS FeatureServer or
#' MapServer layer URL. Direct layers have `not_checked` provenance and no
#' inferred publisher or portal item identity.
#' @param url Public HTTPS ArcGIS layer URL.
#' @inheritParams tbod_get_dataset
#' @param where ArcGIS SQL WHERE clause using source field names; defaults to
#'   `"1=1"`. Inspect names with `tbod_dataset_info(url, refresh = TRUE)`.
#' @return A tibble or sf object with source, completeness, and retrieval
#'   metadata attached. Read it with [tbod_provenance()].
#' @export
#' @examples
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   url <- tbod_dataset_info("construction-permits")$source_url
#'   data <- tbod_get_arcgis_layer(url, limit = 10)
#'   tbod_provenance(data)$validation_status
#' }
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
#' @details The client retrieves the full matching object-ID manifest, then
#'   writes bounded RDS chunks to a caller-selected directory. Each chunk is
#'   a tibble or `sf` object with its own provenance; read files one at a time
#'   with [readRDS()]. Feature pages are not accumulated in memory, but the
#'   manifest itself is subject to the one-million-record limit.
#'
#'   A saved manifest fixes the endpoint, query, fields, schema, CRS metadata,
#'   matching IDs, and batch size. With `resume = TRUE`, current metadata and
#'   IDs are rechecked before saved chunks are used. Changed options, schema,
#'   CRS, or membership cause an error. Completed chunks must match their
#'   checkpoint checksums, expected IDs, columns, and provenance. Temporary
#'   files from interrupted writes are ignored.
#'
#'   The directory must be empty on the first call. Unrelated files and
#'   existing downloads with `resume = FALSE` are rejected. An exclusive lock
#'   prevents concurrent writers. If a terminated process leaves `.lock`,
#'   confirm no writer remains, remove that empty directory, and resume.
#'   Record attributes can change between chunks or resumed calls even when
#'   IDs and schema remain stable; this is not a frozen snapshot. The returned
#'   summary records whether the complete matching manifest was downloaded.
#' @param path Local directory for the manifest, checkpoints, and chunk files.
#' @param where ArcGIS SQL WHERE clause using source field names; defaults to
#'   `"1=1"`. Inspect names with `tbod_dataset_info(id, refresh = TRUE)`.
#' @param fields Character vector of exact source field names, or `NULL` or
#'   `"*"` for all nongeometry attributes. Object IDs remain in chunk
#'   provenance even if the column was not selected.
#' @param spatial Write `sf` chunks; requires the optional sf package and a
#'   layer with supported geometry and a known CRS.
#' @param out_sr Optional positive ArcGIS/EPSG output reference for server
#'   projection; requires `spatial = TRUE`. `NULL` keeps the native CRS.
#' @param page_size Positive integer batch size capped at 1,000 and the
#'   service maximum. The effective size must stay fixed when resuming.
#' @param query Named list of advanced ArcGIS filters such as `geometry`,
#'   `spatialRel`, and `time`. Response format, field selection, aggregation,
#'   geometry simplification, and pagination parameters are protected.
#' @param timeout Per-request timeout in seconds.
#' @param total_timeout Overall operation deadline in seconds. The default
#'   `Inf` allows a long download; completed chunks remain for a later resume
#'   if a finite deadline expires.
#' @param resume Reuse a matching saved download and skip validated chunks.
#' @param id Bundled ID, one-row discovery result, stable ArcGIS ID, or direct
#'   public HTTPS ArcGIS layer URL.
#' @param jurisdiction Optional bundled catalog jurisdiction. `NULL` resolves a
#'   unique bundled ID and preserves a discovery result's jurisdiction. Direct
#'   URLs do not accept a jurisdiction override.
#' @param portal Optional ArcGIS sharing REST portal URL when `id` is a stable
#'   `arcgis:<item-id>:<layer-id>` identifier.
#' @return A named list with `path`, ordered chunk `files`, `matched_rows`,
#'   `returned_rows`, `complete`, and summary `source` provenance. Each RDS
#'   chunk has its own provenance; `tbod_provenance(chunk)$download` includes
#'   its chunk number and object IDs.
#' @export
#' @examples
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   saved <- tbod_download_dataset("construction-permits",
#'     tempfile("permit-download-"), where = "OBJECTID <= 10", page_size = 5)
#'   if (length(saved$files)) tbod_provenance(readRDS(saved$files[[1L]]))
#' }
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
    return(.download_arcgis_layer_impl(id, path = path, where = where,
                                 fields = fields, spatial = spatial,
                                 out_sr = out_sr, page_size = page_size,
                                 query = query, timeout = timeout,
                                 total_timeout = total_timeout,
                                 resume = resume))
  }
  .download_dataset_impl(id, path = path, jurisdiction = jurisdiction,
                   where = where, fields = fields, spatial = spatial,
                   out_sr = out_sr, page_size = page_size, query = query,
                   timeout = timeout, total_timeout = total_timeout,
                   resume = resume)
}

#' Download a direct ArcGIS layer URL
#'
#' Uses [tbod_download_dataset()] with a public HTTPS ArcGIS FeatureServer or
#' MapServer layer URL. The direct source has `not_checked` provenance and no
#' inferred publisher identity. A saved manifest fixes the endpoint, query,
#' fields, schema, CRS, IDs, and batch size; a resumed call rechecks them before
#' reusing validated chunks. See [tbod_download_dataset()] for the directory,
#' lock, and record-change rules.
#' @param url Public HTTPS ArcGIS layer URL.
#' @inheritParams tbod_download_dataset
#' @param where ArcGIS SQL WHERE clause using source field names; defaults to
#'   `"1=1"`. Inspect names with `tbod_dataset_info(url, refresh = TRUE)`.
#' @return A named list with the download path, ordered chunk files, matched
#'   and returned row counts, completeness, and summary provenance.
#' @export
#' @examples
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   url <- tbod_dataset_info("construction-permits")$source_url
#'   tbod_download_arcgis_layer(url, tempfile("permit-url-download-"),
#'     where = "OBJECTID <= 10", page_size = 5)
#' }
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
#' a tabular or spatial result from [tbod_get_dataset()], or a chunk saved by
#' [tbod_download_dataset()]. The record includes publisher, source and query
#' URLs, UTC retrieval time, returned and matching row counts, and integrity
#' status. `validation_status` is `checked` for bundled entries, `discovered`
#' for live portal results, and `not_checked` for direct layer URLs. Item ID,
#' portal, and original metadata are included when available. A successful
#' full retrieval checks object-ID membership, but upstream attributes are
#' not a transactionally frozen snapshot. R transformations can discard
#' attributes; save provenance before transforming or exporting the result.
#' @param x A retrieval result or a chunk read from [tbod_download_dataset()]
#'   or [tbod_download_arcgis_layer()].
#' @return The attached `source` list, including `dataset_id`, `publisher`,
#'   `jurisdiction`, `source_url`, query `endpoint`, `validation_status`, UTC
#'   `started_at` and `retrieved_at`, submitted `query`, `matched_rows`,
#'   `returned_rows`, `complete`, and `integrity`. Download chunks also include
#'   `download` with the chunk number and object IDs.
#' @export
#' @examples
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   permits <- tbod_get_permits(limit = 10)
#'   tbod_provenance(permits)$source_url
#' }
tbod_provenance <- function(x) {
  .dataset_provenance_impl(x)
}

#' Retrieve bundled Tampa permit locations
#'
#' Calls [tbod_get_dataset()] for the bundled `construction-permits` layer.
#' It reflects the City's active permit viewer;
#' the source is not a complete historical archive of every permit.
#' @param ... Arguments passed to [tbod_get_dataset()] except `id`.
#' @return A tibble or sf object with retrieval provenance attached.
#' @export
#' @examples
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   tbod_get_permits(limit = 10)
#' }
tbod_get_permits <- function(...) tbod_get_dataset("construction-permits", ...)

#' Retrieve bundled Tampa development cases
#'
#' Calls [tbod_get_dataset()] for the bundled `development-cases` layer.
#' It covers active entitlement locations, not all
#' historical development cases.
#' @inheritParams tbod_get_permits
#' @return A tibble or sf object with retrieval provenance attached.
#' @export
#' @examples
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   tbod_get_development_cases(limit = 10)
#' }
tbod_get_development_cases <- function(...) tbod_get_dataset("development-cases", ...)

#' Retrieve bundled Tampa capital projects
#'
#' Calls [tbod_get_dataset()] for the bundled `capital-projects` layer.
#' The City service publishes records marked PUBLIC;
#' the package preserves that source scope.
#' @inheritParams tbod_get_permits
#' @return A tibble or sf object with retrieval provenance attached.
#' @export
#' @examples
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   tbod_get_capital_projects(limit = 10)
#' }
tbod_get_capital_projects <- function(...) tbod_get_dataset("capital-projects", ...)

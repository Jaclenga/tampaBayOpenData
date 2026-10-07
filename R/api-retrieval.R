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
    id <- .direct_arcgis_descriptor(id)
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

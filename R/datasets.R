#' Retrieve a checked or discovered ArcGIS dataset
#'
#' Accepts a checked package ID from [tbod_list_datasets()], a single discovery
#' result row from [tbod_search_datasets()], or a stable `arcgis:<item-id>:<layer-id>`
#' identifier. The latter two paths use current ArcGIS portal metadata; they
#' have not received the package's curated source validation. For a compatible
#' layer URL outside the discovery portal, use [tbod_get_arcgis_layer()].
#' Bundled checked layers are compared with expected schema snapshots before
#' querying. Compatible changes warn; incompatible changes stop retrieval.
#' [tbod_check_schema()] returns a categorized report of current differences.
#'
#' Requests the current ArcGIS layer schema,
#' matching count, and object-ID manifest. Full requests are validated against
#' that manifest. Small previews of large queryable layers can validate only
#' the returned IDs against the original filter. A missing or duplicate record,
#' truncated manifest, unexpected
#' response, or upstream error fails explicitly. With `limit = Inf`, all matching
#' records are retrieved. Queries matching more than one million records must be
#' narrowed with filters for full retrieval because it requires a complete ID
#' manifest. See `integrity` for previews and [tbod_download_dataset()] for downloads
#' that save validated chunks to disk and can resume after interruption.
#'
#' Source column names, strings, coded values, and date-looking strings are
#' preserved. ArcGIS epoch-millisecond date fields are converted to UTC POSIXct.
#' Date-only fields become Date. If the source declares an unknown time zone, affected dates
#' remain raw milliseconds with a warning; UTC editor tracking dates identified
#' by layer metadata are still converted. Integer fields become integers where
#' safe, and
#' larger values become numeric; big integers are preserved as character values
#' when exact representation is available. Timestamp-offset and time-only strings
#' are retained. NULL or absent attributes become typed missing values. Geometry
#' is returned separately only when `spatial = TRUE`. Spatial results use XY
#' (two-dimensional) coordinates; requests exclude Z and M values.
#'
#' The function does not maintain a data cache. A live source can change between
#' requests; detected record membership changes cause an error suggesting retry.
#' Attribute changes during retrieval cannot be detected or frozen by this client.
#' Requests do not follow redirects. Each accepted response is limited to 50 MiB,
#' JSON validation allows at most 64 nested containers, and server-requested
#' retry waits are capped at 30 seconds. Spatial WKT must be an inline definition.
#' Keep native curl, GDAL, and PROJ libraries patched; these checks do not isolate
#' native parsers or bound decompression memory on older curl builds.
#' @param id Checked package dataset ID, one-row discovered dataset descriptor,
#'   or stable `arcgis:<32-hex-item-id>:<nonnegative-layer-id>` identifier.
#' @param jurisdiction Bundled checked-catalog jurisdiction code, or `"all"`.
#'   Omit to resolve a unique checked ID across the catalog or to use a
#'   discovered result's or stable ArcGIS ID's jurisdiction. See
#'   [tbod_list_portals()] for the bundled jurisdiction codes.
#' @param where ArcGIS SQL WHERE clause, using actual source field names.
#'   Defaults to `"1=1"` (all records). See [tbod_dataset_info()] with `refresh = TRUE`.
#' @param fields Character vector of exact source field names, or NULL/`"*"` for
#'   all nongeometry attributes. An object-ID field is requested internally for
#'   integrity checks and removed when it was not selected.
#' @param spatial Return an `sf` object. Requires the optional sf package and
#'   a layer with supported geometry and a reliably determined CRS.
#' @param out_sr Optional positive ArcGIS/EPSG spatial reference ID for server
#'   projection, such as 4326. Used only with `spatial = TRUE`; NULL keeps the
#'   native CRS. A projection response must confirm its spatial reference.
#' @param order_by Optional source fields with ASC/DESC, such as
#'   `c("LASTUPDATE DESC", "RECORD_ID ASC")`. Requires server ordering and
#'   offset pagination. An object-ID tie breaker is added automatically.
#' @param limit Maximum number of records; Inf retrieves all, and 0 returns a
#'   typed empty result. A deliberate subset is recorded as incomplete in
#'   [tbod_provenance()] when additional matching records exist.
#' @param page_size Optional positive integer batch size. Defaults to at most
#'   1,000, bounded by the advertised service maximum; larger values are capped.
#' @param query Named list of advanced ArcGIS filter parameters: `geometry`,
#'   `geometryType`, `inSR`, `spatialRel`, `relationParam`, `time`, `distance`,
#'   `units`, `gdbVersion`, `historicMoment`, `sqlFormat`, `datumTransformation`.
#'   Values can be scalars or JSON-style lists. Response format, field selection,
#'   aggregation, geometry simplification, and pagination parameters are protected.
#' @param timeout Timeout in seconds for each HTTP attempt. Transient transport
#'   and HTTP failures may receive three attempts; one generic ArcGIS query
#'   error may receive four.
#' @param total_timeout Overall operation time budget in seconds. Defaults to
#'   120; use Inf to disable it. Requests and retry waits use the remaining
#'   budget. Parsing is checked after it finishes rather than interrupted.
#' @param integrity `"auto"` (default) uses a bounded preview when a finite
#'   limit is at most 1,000, more than 10,000 records match, and the layer supports
#'   ordering and pagination. Returned IDs are verified against the original
#'   filter, without retrieving all matching IDs. Full retrieval always uses
#'   the full manifest. `"full"` requires that manifest even for a preview.
#'   A zero limit requests only the count. Provenance records the verification
#'   method and never labels a deliberate subset complete.
#' @return A tibble, or an sf object when spatial retrieval is requested. Source
#'   metadata are attached as `source`, `dataset_id`, `jurisdiction`, and
#'   `retrieved_at` attributes; [tbod_provenance()] returns the full record.
#' @noRd
#' @examples
#' tbod_dataset_info("construction-permits")$source_url
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   permits <- tbod_get_dataset("construction-permits", limit = 10,
#'     fields = c("RECORD_ID", "PROJECTSTATUS", "LASTUPDATE"))
#'   tbod_provenance(permits)$returned_rows
#' }
.get_dataset_impl <- function(id, jurisdiction = NULL, where = "1=1", fields = NULL,
                        spatial = FALSE, out_sr = NULL, order_by = NULL,
                        limit = Inf, page_size = NULL, query = list(), timeout = 30,
                        total_timeout = 120, integrity = "auto") {
  .string(where, "where")
  .flag(spatial, "spatial")
  .number(limit, "limit", integer = TRUE, infinity = TRUE)
  timeout <- .operation_timeout(timeout, total_timeout)
  .string(integrity, "integrity")
  if (!integrity %in% c("auto", "full")) {
    .abort("`integrity` must be 'auto' or 'full'.", subclass = "tampa_input_error")
  }
  if (!is.null(page_size)) .number(page_size, "page_size", min = 1, integer = TRUE)
  if (!is.null(out_sr)) {
    .number(out_sr, "out_sr", min = 1, integer = TRUE)
    if (!spatial) .abort("`out_sr` requires `spatial = TRUE`.")
  }
  query_params <- .query_params(query)
  requested_jurisdiction <- .requested_jurisdiction(
    id, jurisdiction, missing(jurisdiction))
  dataset <- .resolve_dataset(id, requested_jurisdiction, timeout)
  .retrieve_dataset(dataset, where, fields, spatial, out_sr, order_by,
                    limit, page_size, query, query_params, timeout, integrity)
}

# The checked catalog, portal discovery, and direct URL entry points share all
# query, parsing, spatial, and provenance behavior after descriptor resolution.
.retrieve_dataset <- function(dataset, where, fields, spatial, out_sr, order_by,
                              limit, page_size, query, query_params, timeout,
                              integrity = "auto") {
  started_at <- .utc_now()
  tryCatch({
    if (spatial && !arcgis_has_sf()) {
      .abort("Spatial retrieval requires the sf package. Install it with install.packages('sf').")
    }
    metadata <- .schema_checked_layer(dataset, timeout)
    geometry_type <- metadata[["geometryType", exact = TRUE]]
    if (spatial && (!is.character(geometry_type) || length(geometry_type) != 1L ||
                    is.na(geometry_type) ||
                    !geometry_type %in% c("esriGeometryPoint", "esriGeometryMultipoint",
                                          "esriGeometryPolyline", "esriGeometryPolygon"))) {
      .abort("This layer has no supported spatial geometry type. Request a table with spatial = FALSE.",
             dataset, paste0(dataset$service_url, "/", dataset$layer_id),
             "tampa_spatial_error")
    }
    selected <- .selected_fields(fields, metadata)
    fetched <- arcgis_fetch(dataset, metadata, where, selected, spatial, out_sr,
                            order_by, limit, page_size, query_params, timeout, integrity)
    data <- arcgis_parse(fetched$features, metadata, selected)
    if (spatial) {
      data <- arcgis_as_sf(data, fetched$features, metadata,
                           fetched$spatial_reference, out_sr)
    }
    data <- .attach_provenance(data, dataset, metadata, fetched,
      list(where = where, fields = selected, spatial = spatial, out_sr = out_sr,
           order_by = order_by, limit = limit, query = query,
           integrity = integrity), started_at)
    .check_operation_timeout(timeout, dataset)
    data
  }, tampa_data_error = function(e) {
    if (is.null(e$dataset_id)) {
      .abort(conditionMessage(e), dataset, paste0(dataset$service_url, "/", dataset$layer_id), class(e)[1L])
    }
    stop(e)
  })
}

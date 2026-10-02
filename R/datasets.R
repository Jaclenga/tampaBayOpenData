#' Retrieve a supported government dataset
#'
#' Resolves the registry entry and requests the current ArcGIS layer schema,
#' matching count, and object-ID manifest. Bounded requests are validated against
#' that manifest. A missing or duplicate record, truncated manifest, unexpected
#' response, or upstream error fails explicitly. With `limit = Inf`, all matching
#' records are retrieved. Queries matching more than one million records must be
#' narrowed with filters because the client requires a complete object-ID manifest.
#'
#' Source column names, strings, coded values, and date-looking strings are
#' preserved. Declared ArcGIS date fields are converted from epoch milliseconds
#' to UTC POSIXct. If the source declares an unknown time zone, affected dates
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
#' @param id Stable package dataset ID from [list_datasets()].
#' @inheritParams list_datasets
#' @param where ArcGIS SQL WHERE clause, using actual source field names.
#'   Defaults to `"1=1"` (all records). See [dataset_info()] with `refresh = TRUE`.
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
#'   [dataset_provenance()] when additional matching records exist.
#' @param page_size Optional positive integer batch size. Defaults to at most
#'   1,000, bounded by the advertised service maximum; larger values are capped.
#' @param query Named list of advanced ArcGIS filter parameters: `geometry`,
#'   `geometryType`, `inSR`, `spatialRel`, `relationParam`, `time`, `distance`,
#'   `units`, `gdbVersion`, `historicMoment`, `sqlFormat`, `datumTransformation`.
#'   Values can be scalars or JSON-style lists. Response format, field selection,
#'   aggregation, geometry simplification, and pagination parameters are protected.
#' @param timeout Timeout in seconds for each HTTP attempt. Transient transport
#'   and service errors receive up to three attempts; this is not an overall
#'   retrieval deadline.
#' @return A tibble, or an sf object when spatial retrieval is requested. Source
#'   metadata are attached as `source`, `dataset_id`, `jurisdiction`, and
#'   `retrieved_at` attributes; [dataset_provenance()] returns the full record.
#' @export
#' @examples
#' \dontrun{
#' permits <- get_dataset("construction-permits")
#' filtered <- get_dataset("construction-permits",
#'   where = "PROJECTSTATUS IS NOT NULL",
#'   fields = c("RECORD_ID", "PROJECTSTATUS", "LASTUPDATE"))
#' projects <- get_dataset("development-cases", spatial = TRUE, out_sr = 4326)
#' dataset_provenance(projects)
#' }
get_dataset <- function(id, jurisdiction = "tampa", where = "1=1", fields = NULL,
                        spatial = FALSE, out_sr = NULL, order_by = NULL,
                        limit = Inf, page_size = NULL, query = list(), timeout = 30) {
  .string(where, "where")
  .flag(spatial, "spatial")
  .number(limit, "limit", integer = TRUE, infinity = TRUE)
  .number(timeout, "timeout", min = .Machine$double.eps)
  if (!is.null(page_size)) .number(page_size, "page_size", min = 1, integer = TRUE)
  if (!is.null(out_sr)) {
    .number(out_sr, "out_sr", min = 1, integer = TRUE)
    if (!spatial) .abort("`out_sr` requires `spatial = TRUE`.")
  }
  query_params <- .query_params(query)
  dataset <- .lookup_dataset(id, jurisdiction)
  started_at <- .utc_now()
  tryCatch({
    if (spatial && !arcgis_has_sf()) {
      .abort("Spatial retrieval requires the sf package. Install it with install.packages('sf').")
    }
    metadata <- arcgis_layer(dataset, timeout)
    selected <- .selected_fields(fields, metadata)
    fetched <- arcgis_fetch(dataset, metadata, where, selected, spatial, out_sr,
                            order_by, limit, page_size, query_params, timeout)
    data <- arcgis_parse(fetched$features, metadata, selected)
    if (spatial) {
      data <- arcgis_as_sf(data, fetched$features, metadata,
                           fetched$spatial_reference, out_sr)
    }
    .attach_provenance(data, dataset, metadata, fetched,
      list(where = where, fields = selected, spatial = spatial, out_sr = out_sr,
           order_by = order_by, limit = limit, query = query), started_at)
  }, tampa_data_error = function(e) {
    if (is.null(e$dataset_id)) {
      .abort(conditionMessage(e), dataset, paste0(dataset$service_url, "/", dataset$layer_id), class(e)[1L])
    }
    stop(e)
  })
}

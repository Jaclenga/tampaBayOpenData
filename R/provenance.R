.utc_now <- function() {
  as.POSIXct(as.numeric(Sys.time()), origin = "1970-01-01", tz = "UTC")
}

.attach_provenance <- function(x, dataset, metadata, fetched, query, started_at) {
  retrieved <- .utc_now()
  reference <- NULL
  if (isTRUE(query$spatial)) {
    requested <- if (!is.null(query$out_sr) && nrow(x) == 0L) list(wkid = query$out_sr)
    reference <- fetched$spatial_reference %||% requested %||%
      arcgis_native_reference(metadata)
  }
  source <- list(
    dataset_id = dataset$id, title = dataset$title, publisher = dataset$publisher,
    jurisdiction = dataset$jurisdiction, source_url = dataset$source_url,
    service_url = dataset$service_url, layer_id = dataset$layer_id,
    endpoint = paste0(dataset$service_url, "/", dataset$layer_id, "/query"),
    item_id = dataset$item_id, portal = dataset$portal,
    validation_status = dataset$validation_status %||% "checked",
    original_metadata = dataset$original_metadata %||% dataset,
    terms = dataset$terms, endpoint_verified = dataset$verified,
    started_at = started_at, retrieved_at = retrieved,
    package_version = "0.1.0", query = query,
    matched_rows = fetched$matched_rows, returned_rows = fetched$returned_rows,
    complete = fetched$complete, pagination = fetched$pagination,
    integrity = fetched$integrity %||% "full-manifest",
    field_schema = metadata$fields, date_fields_time_reference = metadata$dateFieldsTimeReference,
    dates_in_unknown_timezone = .dates_unknown(metadata),
    upstream_editing_info = metadata$editingInfo,
    spatial_reference = reference)
  attr(x, "source") <- source
  attr(x, "retrieved_at") <- retrieved
  attr(x, "dataset_id") <- dataset$id
  attr(x, "jurisdiction") <- dataset$jurisdiction
  x
}

#' Read the source and retrieval provenance of a result
#'
#' Provenance is attached to both tabular and spatial retrieval results. It
#' describes the government publisher, source URL, query endpoint, retrieval
#' time, original query, expected and returned row counts, and completeness.
#' `validation_status` is `checked` for bundled, maintainer-validated entries,
#' `discovered` for live portal results, and `not_checked` for direct layer URLs.
#' Item ID, portal, and original metadata are included when available.
#' A successful full retrieval checks membership against an object-ID manifest;
#' upstream attributes are not guaranteed to be a transactionally frozen snapshot.
#' Attributes can be lost in subsequent R transformations; save provenance before
#' exporting data or transforming objects with tools that discard attributes.
#' @param x A retrieval result or a chunk read from [download_dataset()] or
#'   [download_arcgis_layer()].
#' @return A named list containing source metadata and retrieval details.
#' @export
#' @examples
#' \dontrun{
#' permits <- get_permits(limit = 10)
#' dataset_provenance(permits)
#' attr(permits, "retrieved_at")
#' }
dataset_provenance <- function(x) {
  source <- attr(x, "source", exact = TRUE)
  if (!is.list(source) || is.null(source$dataset_id)) .abort("This object has no tampaBayOpenData retrieval provenance.")
  source
}

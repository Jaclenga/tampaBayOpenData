# Inspect one public ArcGIS layer before proposing it for the checked catalog.
# Run from the package root after installing the current source package:
#   Rscript tools/prepare-checked-candidate.R \
#     https://example.org/arcgis/rest/services/Example/FeatureServer/0 \
#     hillsborough example-layer
# This makes live requests. It saves only metadata, validation results, and a
# two-row retrieval summary under ignored .research/checked-candidates/.
# Review publisher identity, exact-source terms, scope, fields, and geographic
# coverage before manually editing the bundled registries. Nothing is promoted.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 1L && args[[1L]] %in% c("-h", "--help")) {
  cat("Usage: Rscript tools/prepare-checked-candidate.R <layer-url> <jurisdiction> <slug>\n")
  quit(save = "no", status = 0L)
}
if (length(args) != 3L) {
  stop("Provide a public ArcGIS layer URL, configured jurisdiction, and slug.")
}
if (!file.exists("DESCRIPTION") || !file.exists("inst/extdata/portals.json")) {
  stop("Run this script from the tampaBayOpenData package root.")
}
if (dir.exists(".library")) {
  .libPaths(c(normalizePath(".library"), .libPaths()))
}
if (!requireNamespace("tampaBayOpenData", quietly = TRUE) ||
    !requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Install the current tampaBayOpenData package before running this script.")
}
`%||%` <- function(x, y) if (is.null(x)) y else x

layer_url <- args[[1L]]
jurisdiction <- args[[2L]]
slug <- args[[3L]]
if (!grepl("^[a-z][a-z0-9]*(-[a-z0-9]+)*$", slug)) {
  stop("The candidate slug must use lowercase letters, digits, and single hyphens.")
}
portals <- tampaBayOpenData::tbod_list_portals()
publisher <- portals[portals$jurisdiction == jurisdiction, , drop = FALSE]
if (nrow(publisher) != 1L) {
  stop("Select one jurisdiction from tbod_list_portals().")
}

# Direct-URL entry points validate the HTTPS ArcGIS layer URL. An invalid or
# inaccessible layer fails before any output is written.
info <- tampaBayOpenData::tbod_dataset_info(
  layer_url, refresh = TRUE, timeout = 20, total_timeout = 60
)
schema <- tampaBayOpenData::tbod_schema(
  layer_url, refresh = TRUE, timeout = 20, total_timeout = 60
)
check <- tampaBayOpenData::tbod_check_schema(
  layer_url, expected = schema, timeout = 20, total_timeout = 60
)
if (!identical(check$status, "unchanged")) {
  stop("The layer schema changed during inspection; rerun before saving a snapshot.")
}
preview <- tampaBayOpenData::tbod_get_dataset(
  layer_url, limit = 2, page_size = 1, timeout = 20, total_timeout = 120
)
source <- tampaBayOpenData::tbod_provenance(preview)
metadata <- info$metadata
if (!"Query" %in% trimws(strsplit(metadata$capabilities %||% "", ",",
                                 fixed = TRUE)[[1L]])) {
  stop("The layer does not advertise Query capability.")
}

# An ordered two-row preview exercises offset pagination when the service
# advertises both required capabilities. The first preview exercises the
# package's object-ID batching path and count behavior for all candidates.
advanced <- metadata$advancedQueryCapabilities
offset_checked <- isTRUE(advanced$supportsPagination) &&
  isTRUE(advanced$supportsOrderBy)
if (offset_checked) {
  ordered <- tampaBayOpenData::tbod_get_dataset(
    layer_url, order_by = paste(schema$object_id_field, "ASC"),
    limit = 2, page_size = 1, timeout = 20, total_timeout = 120
  )
  ordered_source <- tampaBayOpenData::tbod_provenance(ordered)
} else {
  ordered_source <- NULL
}

field_rows <- lapply(seq_len(nrow(schema$fields)), function(i) {
  row <- schema$fields[i, c("name", "type", "alias"), drop = FALSE]
  list(name = row$name[[1L]], type = row$type[[1L]],
       alias = row$alias[[1L]])
})
reference <- schema$spatial_reference
if (!is.null(reference)) {
  reference <- reference[intersect(c("wkid", "latestWkid", "wkt", "wkt2"),
                                   names(reference))]
}
snapshot <- list(
  endpoint = schema$endpoint,
  fields = field_rows,
  geometry_type = schema$geometry_type,
  spatial_reference = reference,
  object_id_field = schema$object_id_field
)
date_fields <- as.list(vapply(Filter(function(field) {
  identical(field$type, "esriFieldTypeDate")
}, field_rows), `[[`, character(1), "name"))

# Null editorial fields deliberately keep the draft invalid as a checked
# registry entry until a maintainer documents and approves them.
draft <- list(
  id = slug,
  title = metadata$name,
  description = metadata$description %||% "",
  jurisdiction = jurisdiction,
  publisher = publisher$publisher[[1L]],
  source_url = layer_url,
  service_url = info$service_url,
  layer_id = info$layer_id,
  layer_name = metadata$name,
  geometry_type = schema$geometry_type,
  spatial_reference = reference,
  object_id_field = schema$object_id_field,
  date_fields = date_fields,
  category = NULL,
  tags = list(),
  verified = NULL,
  terms = NULL,
  terms_url = NULL,
  license_info = NULL,
  license_source = NULL,
  item_id = NULL,
  publisher_evidence = list(publisher$evidence_url[[1L]],
                            publisher$metadata_url[[1L]], layer_url),
  max_record_count = metadata$maxRecordCount,
  supports_pagination = isTRUE(advanced$supportsPagination),
  supports_order_by = isTRUE(advanced$supportsOrderBy),
  upstream_modified = NULL,
  date_time_reference = metadata$dateFieldsTimeReference,
  scope_note = NULL
)

evidence <- list(
  inspected_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  jurisdiction = jurisdiction,
  publisher = publisher$publisher[[1L]],
  endpoint = schema$endpoint,
  capabilities = metadata$capabilities,
  field_count = length(field_rows),
  object_id_field = schema$object_id_field,
  geometry_type = schema$geometry_type,
  spatial_reference = reference,
  upstream_data_last_edit_ms = metadata$editingInfo$dataLastEditDate,
  max_record_count = metadata$maxRecordCount,
  advanced_query_capabilities = advanced,
  schema_check_status = check$status,
  count_and_id_preview = list(
    matched_rows = source$matched_rows,
    returned_rows = source$returned_rows,
    integrity = source$integrity,
    page_size = 1,
    pagination_exercised = source$returned_rows > 1L
  ),
  ordered_offset_preview = if (is.null(ordered_source)) NULL else list(
    matched_rows = ordered_source$matched_rows,
    returned_rows = ordered_source$returned_rows,
    integrity = ordered_source$integrity,
    page_size = 1,
    pagination_exercised = ordered_source$returned_rows > 1L
  ),
  review_needed = list(
    "Confirm publisher item ownership and exact-service reuse terms.",
    "Inspect geographic extent, date semantics, and known limitations.",
    "Choose a controlled category and verify the candidate adds useful coverage.",
    "Run opt-in live validation again after manually adding both registries."
  )
)

output <- file.path(".research", "checked-candidates", jurisdiction, slug,
                    format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"))
if (dir.exists(output) || !dir.create(output, recursive = TRUE)) {
  stop("Could not create a unique candidate evidence directory: ", output)
}
jsonlite::write_json(snapshot, file.path(output, "schema.json"),
                     auto_unbox = TRUE, pretty = TRUE, null = "null")
jsonlite::write_json(draft, file.path(output, "draft-registry.json"),
                     auto_unbox = TRUE, pretty = TRUE, null = "null")
jsonlite::write_json(evidence, file.path(output, "validation.json"),
                     auto_unbox = TRUE, pretty = TRUE, null = "null")
message("Saved candidate evidence to ", normalizePath(output),
        ". Review the draft; no checked registry files were changed.")

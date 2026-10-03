#' Download an ArcGIS dataset into resumable local chunks
#'
#' Retrieves the full matching object-ID manifest, then writes bounded chunks
#' of typed data to a caller-selected directory. Each chunk is an RDS tibble or
#' `sf` object with its own provenance; read one file at a time with [readRDS()].
#' Downloading does not accumulate all feature pages in memory. The manifest
#' itself remains in memory and is subject to the one-million-record limit.
#'
#' A saved manifest fixes the endpoint, query, fields, schema, CRS metadata,
#' matching IDs, and batch size. With `resume = TRUE`, the client rechecks the
#' current metadata and full manifest before using any saved chunk. Changed
#' options, schema, CRS, or record membership cause an error. Completed chunks
#' must match their checkpoint checksum, expected IDs, columns, and provenance.
#' Temporary files from interrupted writes are ignored. The directory must be
#' empty on the first call; unrelated files and existing downloads with
#' `resume = FALSE` are rejected. An exclusive directory lock prevents concurrent
#' writers. A terminated R process can leave a `.lock` directory; after confirming
#' that no process is still using this download, remove that empty lock directory
#' before resuming. Locks are never removed automatically on a new call.
#'
#' Record attributes can change between chunks and between resumed calls even
#' when the IDs and schema remain unchanged. This is not a frozen snapshot.
#' Chunk provenance describes that chunk; the returned summary reports whether
#' the full matching manifest has been downloaded.
#' @inheritParams get_dataset
#' @param path Local directory for the manifest, checkpoints, and chunk files.
#' @param page_size Positive integer batch size, capped at 1,000 and the service
#'   maximum. The effective batch size must remain unchanged when resuming.
#' @param total_timeout Overall operation deadline in seconds. The default
#'   `Inf` permits a long download; a finite deadline leaves completed chunks
#'   available for a later resume.
#' @param resume Reuse a matching saved download and skip validated chunks.
#' @return A named list with `path`, ordered chunk `files`, `matched_rows`,
#'   `returned_rows`, `complete`, and summary `source` provenance. A query with
#'   no matches returns no chunk files. Individual chunks retain object IDs in
#'   `dataset_provenance(chunk)$download$object_ids`, including when the ID
#'   column was not selected.
#' @export
#' @examples
#' \dontrun{
#' saved <- download_dataset("construction-permits", "permit-download",
#'   fields = c("OBJECTID", "RECORD_ID", "LASTUPDATE"), page_size = 500)
#' first <- readRDS(saved$files[[1]])
#' dataset_provenance(first)
#' }
download_dataset <- function(id, path, jurisdiction = "tampa", where = "1=1",
                             fields = NULL, spatial = FALSE, out_sr = NULL,
                             page_size = 1000, query = list(), timeout = 30,
                             total_timeout = Inf, resume = TRUE) {
  .string(path, "path")
  .string(where, "where")
  .flag(spatial, "spatial")
  .flag(resume, "resume")
  .number(page_size, "page_size", min = 1, integer = TRUE)
  if (!is.null(out_sr)) {
    .number(out_sr, "out_sr", min = 1, integer = TRUE)
    if (!spatial) .abort("`out_sr` requires `spatial = TRUE`.")
  }
  query_params <- .query_params(query)
  timeout <- .operation_timeout(timeout, total_timeout)
  requested <- .requested_jurisdiction(id, jurisdiction, missing(jurisdiction))
  dataset <- .resolve_dataset(id, requested, timeout)
  if (spatial && !arcgis_has_sf()) {
    .abort("Spatial downloads require the optional sf package.", dataset)
  }
  metadata <- arcgis_layer(dataset, timeout)
  selected <- .selected_fields(fields, metadata)
  if (spatial) {
    # Validate even an empty download's declared geometry and requested CRS.
    arcgis_as_sf(arcgis_parse(list(), metadata, selected), list(), metadata,
                 out_sr = out_sr)
  }
  url <- paste0(dataset$service_url, "/", dataset$layer_id, "/query")
  params <- c(list(where = where), query_params)
  if (.dates_unknown(metadata)) params$timeReferenceUnknownClient <- "true"
  manifest <- .manifest(url, params, metadata, dataset, timeout)
  options <- list(where = where, fields = selected, spatial = spatial,
                  out_sr = out_sr, page_size = min(page_size, 1000,
                                                   metadata$maxRecordCount),
                  query = query)
  signature <- list(
    dataset = dataset[c("id", "service_url", "layer_id", "source_url",
                         "publisher", "jurisdiction", "validation_status")],
    options = options,
    schema = metadata[c("fields", "objectIdField", "geometryType",
                         "dateFieldsTimeReference", "datesInUnknownTimezone",
                         "editFieldsInfo", "spatialReference", "sourceSpatialReference")],
    extent_reference = metadata$extent$spatialReference,
    ids = manifest$ids, count = manifest$count)
  path <- .download_directory(path, resume)
  lock <- file.path(path, ".lock")
  if (!dir.create(lock, showWarnings = FALSE)) {
    .abort("The download directory is busy or has a lock from a terminated process. After confirming no writer is active, remove its empty `.lock` directory and resume.",
           dataset, path, "tampa_download_error")
  }
  on.exit(.download_release_lock(lock, path), add = TRUE)
  manifest_file <- file.path(path, "manifest.rds")
  if (file.exists(manifest_file)) {
    saved <- .download_read_rds(manifest_file)
    if (!is.list(saved) || !identical(saved$version, 1L) ||
        !identical(saved$signature, signature)) {
      .abort("The saved download's options, endpoint, schema, CRS, or ID membership changed. Use a new directory.",
             dataset, url, "tampa_download_error")
    }
  } else {
    saved <- list(version = 1L, signature = signature, dataset = dataset,
                  metadata = metadata, started_at = .utc_now())
    .download_write_rds(saved, manifest_file)
  }
  manifest_hash <- .download_hash(manifest_file)
  .download_chunks(path, saved, manifest_hash, dataset, metadata, manifest,
                    params, options, timeout)
}

#' Download a direct ArcGIS layer into resumable local chunks
#'
#' Uses the same resumable, bounded-memory path as [download_dataset()]. A direct
#' layer URL retains `not_checked` provenance and no inferred publisher identity.
#' @param url Public HTTPS ArcGIS FeatureServer or MapServer layer URL.
#' @inheritParams download_dataset
#' @return The download summary described in [download_dataset()].
#' @export
#' @examples
#' \dontrun{
#' url <- paste0("https://gis.myclearwater.com/arcgis/rest/services/",
#'   "ArcGISMapServices/Clearwater_Park_Buffers/MapServer/0")
#' saved <- download_arcgis_layer(url, "park-buffer-download", page_size = 50)
#' }
download_arcgis_layer <- function(url, path, where = "1=1", fields = NULL,
                                 spatial = FALSE, out_sr = NULL, page_size = 1000,
                                 query = list(), timeout = 30,
                                 total_timeout = Inf, resume = TRUE) {
  descriptor <- .direct_arcgis_descriptor(url)
  download_dataset(descriptor, path, where = where, fields = fields,
                    spatial = spatial, out_sr = out_sr, page_size = page_size,
                    query = query, timeout = timeout,
                    total_timeout = total_timeout, resume = resume)
}

.download_directory <- function(path, resume) {
  if (file.exists(path) && !dir.exists(path)) {
    .abort("`path` must identify a directory.", subclass = "tampa_download_error")
  }
  if (!dir.exists(path) && !dir.create(path, recursive = TRUE)) {
    .abort("The download directory could not be created.", subclass = "tampa_download_error")
  }
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  entries <- list.files(path, all.files = TRUE, no.. = TRUE)
  has_manifest <- "manifest.rds" %in% entries
  temporary <- grepl("^\\.tbod-.*\\.tmp$", entries)
  allowed <- entries %in% c("manifest.rds", ".checkpoints", ".lock") |
    grepl("^chunk-[0-9]{7}\\.rds$", entries) | temporary
  checkpoint_dir <- file.path(path, ".checkpoints")
  if (dir.exists(checkpoint_dir)) {
    checkpoint_dir <- .download_check_checkpoint_directory(path)
  }
  checkpoint_entries <- if (dir.exists(checkpoint_dir))
    list.files(checkpoint_dir, all.files = TRUE, no.. = TRUE) else character()
  own_empty_checkpoints <- entries == ".checkpoints" & dir.exists(checkpoint_dir) &
    all(grepl("^\\.tbod-.*\\.tmp$", checkpoint_entries))
  initial_allowed <- temporary | entries == ".lock" | own_empty_checkpoints
  if (any(!allowed) || (!has_manifest && any(!initial_allowed))) {
    .abort("The download directory contains unrelated files. Use an empty directory.",
           subclass = "tampa_download_error")
  }
  if (has_manifest && !resume) {
    .abort("A saved download already exists and `resume` is FALSE. Use a new directory.",
           subclass = "tampa_download_error")
  }
  if (!dir.exists(checkpoint_dir) && !dir.create(checkpoint_dir) &&
      !dir.exists(checkpoint_dir)) {
    .abort("The checkpoint directory could not be created.", subclass = "tampa_download_error")
  }
  checkpoint_dir <- .download_check_checkpoint_directory(path)
  checkpoint_files <- list.files(checkpoint_dir, all.files = TRUE, no.. = TRUE)
  if (any(!grepl("^(chunk-[0-9]{7}-[0-9]{7}\\.rds|\\.tbod-.*\\.tmp)$",
                 checkpoint_files))) {
    .abort("The checkpoint directory contains unrelated files.", subclass = "tampa_download_error")
  }
  path
}

.download_check_checkpoint_directory <- function(path) {
  checkpoint_dir <- file.path(path, ".checkpoints")
  if (!dir.exists(checkpoint_dir)) {
    .abort("The checkpoint directory is missing or inaccessible.",
           subclass = "tampa_download_error")
  }
  resolved <- normalizePath(checkpoint_dir, winslash = "/", mustWork = TRUE)
  parent <- paste0(sub("/+$", "", path), "/")
  within <- if (.Platform$file.sep == "\\") {
    startsWith(tolower(resolved), tolower(parent))
  } else {
    startsWith(resolved, parent)
  }
  if (!within) {
    .abort("The checkpoint directory resolves outside the download directory.",
           subclass = "tampa_download_error")
  }
  resolved
}

.download_release_lock <- function(lock, path) {
  # The only recursive removal targets our exact resolved lock directory.
  # A replaced link or unexpected target is preserved for manual inspection.
  if (dir.exists(lock) && identical(normalizePath(lock, winslash = "/", mustWork = TRUE),
                                    file.path(path, ".lock"))) {
    unlink(lock, recursive = TRUE)
  }
  invisible(NULL)
}

.download_read_rds <- function(path) {
  tryCatch(readRDS(path), error = function(e) {
    .abort("A saved download file cannot be read. Use a new directory or restore the original file.",
           url = path, subclass = "tampa_download_error")
  })
}

.download_hash <- function(path) {
  hash <- unname(tools::md5sum(path))
  if (length(hash) != 1L || is.na(hash)) {
    .abort("A download file checksum could not be read.", url = path,
           subclass = "tampa_download_error")
  }
  hash
}

# New immutable filenames permit atomic rename on Windows as well as Unix.
.download_write_rds <- function(value, path) {
  if (file.exists(path)) {
    .abort("A download file already exists; it will not be overwritten.", url = path,
           subclass = "tampa_download_error")
  }
  temp <- tempfile(".tbod-", tmpdir = dirname(path), fileext = ".tmp")
  on.exit(unlink(temp), add = TRUE)
  saveRDS(value, temp)
  if (!file.rename(temp, path)) {
    .abort("An atomic download file write failed.", url = path,
           subclass = "tampa_download_error")
  }
  invisible(path)
}

.download_chunks <- function(path, saved, manifest_hash, dataset, metadata,
                             manifest, params, options, timeout) {
  url <- paste0(dataset$service_url, "/", dataset$layer_id, "/query")
  chunks <- ceiling(manifest$count / options$page_size)
  existing <- list.files(path, pattern = "^chunk-[0-9]{7}\\.rds$")
  index <- as.integer(sub("^chunk-([0-9]+)\\.rds$", "\\1", existing))
  if (any(index < 1L | index > chunks)) {
    .abort("A saved chunk is outside the matching manifest.", dataset, url,
           "tampa_download_error")
  }
  files <- character(chunks)
  returned <- 0L
  reference <- NULL
  query_options <- c(options[c("where", "fields", "spatial", "out_sr", "query")],
                     list(order_by = NULL, limit = Inf, integrity = "full"))
  for (chunk in seq_len(chunks)) {
    .check_operation_timeout(timeout, dataset, url)
    start <- (chunk - 1) * options$page_size + 1
    ids <- manifest$ids[seq.int(start, min(start + options$page_size - 1,
                                          manifest$count))]
    name <- sprintf("chunk-%07d.rds", chunk)
    files[[chunk]] <- file.path(path, name)
    if (file.exists(files[[chunk]])) {
      checked <- .download_validate_chunk(files[[chunk]], chunk, ids,
        manifest_hash, path, dataset, metadata, options, manifest$count)
      page_reference <- checked$spatial_reference
    } else {
      result <- .download_fetch_chunk(ids, params, options, metadata, dataset,
                                      timeout, reference)
      data <- arcgis_parse(result$features, metadata, options$fields)
      if (options$spatial) {
        data <- arcgis_as_sf(data, result$features, metadata,
                             result$spatial_reference, options$out_sr)
      }
      fetched <- list(matched_rows = manifest$count, returned_rows = length(ids),
                       complete = length(ids) == manifest$count,
                       pagination = "object-id batches", integrity = "full-manifest",
                       spatial_reference = result$spatial_reference)
      data <- .attach_provenance(data, dataset, metadata, fetched,
                                 query_options, saved$started_at)
      source <- attr(data, "source", exact = TRUE)
      source$download <- list(chunk = chunk, object_ids = ids, file = name)
      attr(data, "source") <- source
      .check_operation_timeout(timeout, dataset, url)
      .download_save_chunk(data, files[[chunk]], chunk, ids, manifest_hash,
                            path, result$spatial_reference)
      page_reference <- result$spatial_reference
      rm(data, result)
    }
    if (options$spatial && !is.null(page_reference)) {
      if (!is.null(reference) &&
          !isTRUE(arcgis_spatial_crs(reference) == arcgis_spatial_crs(page_reference))) {
        .abort("The response CRS changed between saved chunks.", dataset, url,
               "tampa_integrity_error")
      }
      reference <- page_reference
    }
    returned <- returned + length(ids)
  }
  .check_operation_timeout(timeout, dataset, url)
  fetched <- list(matched_rows = manifest$count, returned_rows = returned,
                   complete = returned == manifest$count, pagination = "object-id chunks",
                   integrity = "full-manifest", spatial_reference = reference)
  source <- dataset_provenance(.attach_provenance(tibble::tibble(), dataset,
    metadata, fetched, query_options, saved$started_at))
  list(path = path, files = files, matched_rows = manifest$count,
       returned_rows = returned, complete = returned == manifest$count,
       source = source)
}

.download_fetch_chunk <- function(ids, params, options, metadata, dataset,
                                  timeout, previous_reference) {
  url <- paste0(dataset$service_url, "/", dataset$layer_id, "/query")
  feature_params <- c(params, list(
    outFields = paste(unique(c(options$fields, metadata$objectIdField)), collapse = ","),
    returnGeometry = if (options$spatial) "true" else "false",
    returnZ = "false", returnM = "false"))
  if (!is.null(options$out_sr)) feature_params$outSR <- as.character(options$out_sr)
  handlers <- .feature_page_handlers(url, feature_params, metadata, dataset,
                                     timeout, options$spatial, options$out_sr)
  .fetch_id_batch(ids, handlers$request_page, handlers$add_page,
    list(features = list(), ids = numeric(), spatial_reference = previous_reference),
    dataset, url)
}

.download_save_chunk <- function(data, file, chunk, ids, manifest_hash, path, reference) {
  temp <- tempfile(".tbod-", tmpdir = path, fileext = ".tmp")
  on.exit(unlink(temp), add = TRUE)
  saveRDS(data, temp)
  checkpoint_dir <- .download_check_checkpoint_directory(path)
  prefix <- sprintf("chunk-%07d-", chunk)
  previous <- list.files(checkpoint_dir, pattern = paste0("^", prefix, "[0-9]{7}\\.rds$"))
  attempt <- if (length(previous))
    max(as.integer(sub(paste0("^", prefix, "([0-9]+)\\.rds$"), "\\1", previous))) + 1L else 1L
  checkpoint <- list(version = 1L, manifest_md5 = manifest_hash, chunk = chunk,
                      object_ids = ids, rows = nrow(data), data_md5 = .download_hash(temp),
                      spatial_reference = reference)
  # Publish the checksum before the data rename: a crash can leave a checkpoint
  # without data, but it never leaves completed data without its checksum.
  .download_write_rds(checkpoint,
    file.path(checkpoint_dir, sprintf("chunk-%07d-%07d.rds", chunk, attempt)))
  if (file.exists(file) || !file.rename(temp, file)) {
    .abort("An atomic chunk write failed or another writer used this directory.",
           url = file, subclass = "tampa_download_error")
  }
  invisible(file)
}

.download_validate_chunk <- function(file, chunk, ids, manifest_hash, path,
                                     dataset, metadata, options, count) {
  prefix <- sprintf("chunk-%07d-", chunk)
  checkpoint_dir <- .download_check_checkpoint_directory(path)
  checkpoints <- list.files(checkpoint_dir,
    pattern = paste0("^", prefix, "[0-9]{7}\\.rds$"), full.names = TRUE)
  bad <- function() .abort("A completed chunk or checkpoint was altered, is missing, or does not match this download.",
                           dataset, file, "tampa_download_error")
  if (!length(checkpoints)) bad()
  checkpoint <- .download_read_rds(sort(checkpoints, decreasing = TRUE)[[1L]])
  if (!is.list(checkpoint) || !identical(checkpoint$version, 1L) ||
      !identical(checkpoint$manifest_md5, manifest_hash) ||
      !identical(checkpoint$chunk, chunk) || !identical(checkpoint$object_ids, ids) ||
      !identical(checkpoint$data_md5, .download_hash(file))) bad()
  data <- .download_read_rds(file)
  attributes <- if (options$spatial && inherits(data, "sf")) sf::st_drop_geometry(data) else data
  if (!inherits(data, if (options$spatial) "sf" else "tbl_df") ||
      nrow(data) != length(ids) || !identical(checkpoint$rows, as.integer(length(ids))) ||
      !identical(names(attributes), options$fields)) bad()
  source <- attr(data, "source", exact = TRUE)
  if (!is.list(source) || !is.list(source$query) || !is.list(source$download) ||
      !identical(source$dataset_id, dataset$id) ||
      !identical(source$source_url, dataset$source_url) ||
      !identical(source$publisher, dataset$publisher) ||
      !identical(source$jurisdiction, dataset$jurisdiction) ||
      !identical(source$query$fields, options$fields) ||
      !identical(source$query$where, options$where) ||
      !identical(source$query$query, options$query) ||
      !identical(source$query$spatial, options$spatial) ||
      !identical(source$query$out_sr, options$out_sr) ||
      !identical(source$matched_rows, count) ||
      !identical(source$returned_rows, length(ids)) ||
      !identical(source$complete, length(ids) == count) ||
      !identical(source$integrity, "full-manifest") ||
      !identical(source$download$object_ids, ids) ||
      !identical(source$download$chunk, chunk)) bad()
  oid <- metadata$objectIdField
  if (oid %in% options$fields && !identical(as.numeric(data[[oid]]), ids)) bad()
  if (options$spatial && (!is.list(checkpoint$spatial_reference) ||
      !isTRUE(sf::st_crs(data) == arcgis_spatial_crs(checkpoint$spatial_reference)))) bad()
  rm(data)
  checkpoint
}

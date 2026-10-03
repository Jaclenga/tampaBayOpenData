# All download files stay in the R session's temporary directory.
download_test_path <- function() tempfile("tbod-download-", tmpdir = tempdir())

test_that("downloads resume after interruption without refetching completed chunks", {
  path <- download_test_path()
  fields <- c("RECORD_ID", "LASTUPDATE")
  interrupted <- fixture_transport(transform = function(payload, params, url, call) {
    if (identical(params$objectIds, "3,4")) stop("synthetic interruption")
    payload
  })
  local_mocked_bindings(arcgis_http = interrupted$http)
  expect_error(download_dataset("construction-permits", path, fields = fields,
                                 page_size = 2), "synthetic interruption")
  first_file <- file.path(path, "chunk-0000001.rds")
  expect_true(file.exists(first_file))
  expect_false(file.exists(file.path(path, "chunk-0000002.rds")))
  first <- readRDS(first_file)
  expect_s3_class(first, "tbl_df")
  expect_identical(names(first), fields)
  expect_identical(first$RECORD_ID, c("synthetic-1", "synthetic-2"))
  expect_s3_class(first$LASTUPDATE, "POSIXct")
  expect_false(dataset_provenance(first)$complete)
  expect_identical(dataset_provenance(first)$download$object_ids, c(1, 2))

  # Existing attributes can change upstream without changing the manifest.
  features <- fixture_features()
  features[[which(vapply(features, function(x) x$attributes$OBJECTID == 1L,
                         logical(1)))]]$attributes$RECORD_ID <- "changed upstream"
  resumed <- fixture_transport(features = features)
  local_mocked_bindings(arcgis_http = resumed$http)
  result <- download_dataset("construction-permits", path, fields = fields,
                              page_size = 2, timeout = 15, total_timeout = 30)
  expect_true(result$complete)
  expect_equal(result$matched_rows, 5)
  expect_equal(result$returned_rows, 5)
  expect_length(result$files, 3L)
  expect_identical(basename(result$files),
                   sprintf("chunk-%07d.rds", 1:3))
  expect_identical(result$source$integrity, "full-manifest")
  expect_identical(result$source$pagination, "object-id chunks")
  expect_length(fixture_queries(resumed, "count"), 1L)
  expect_length(fixture_queries(resumed, "ids"), 1L)
  expect_identical(vapply(fixture_queries(resumed, "features"),
    function(x) x$params$objectIds, character(1)), c("3,4", "5"))
  expect_identical(readRDS(first_file)$RECORD_ID,
                   c("synthetic-1", "synthetic-2"))
  expect_equal(unname(vapply(result$files, function(file) nrow(readRDS(file)), integer(1))),
                c(2L, 2L, 1L))
})

test_that("an overall deadline preserves completed chunks and allows a later resume", {
  path <- download_test_path()
  clock <- new.env(parent = emptyenv())
  clock$elapsed <- 0
  local_mocked_bindings(.operation_clock = function() clock$elapsed)
  expired <- fixture_transport(transform = function(payload, params, url, call) {
    if (identical(params$objectIds, "3,4")) clock$elapsed <- 2
    payload
  })
  local_mocked_bindings(arcgis_http = expired$http)
  expect_error(download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 2, timeout = 5, total_timeout = 1),
    "exceeded.*total_timeout", class = "tampa_timeout_error")
  expect_true(file.exists(file.path(path, "chunk-0000001.rds")))
  expect_false(file.exists(file.path(path, "chunk-0000002.rds")))
  expect_false(dir.exists(file.path(path, ".lock")))
  resumed <- fixture_transport()
  local_mocked_bindings(arcgis_http = resumed$http)
  result <- download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 2, timeout = 10, total_timeout = 10)
  expect_true(result$complete)
  expect_equal(result$returned_rows, 5)
  expect_false(dir.exists(file.path(path, ".lock")))
  expect_identical(vapply(fixture_queries(resumed, "features"),
    function(x) x$params$objectIds, character(1)), c("3,4", "5"))
})

test_that("resuming rejects changed queries, fields, batch sizes, and endpoints", {
  path <- download_test_path()
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  download_dataset("construction-permits", path, fields = "RECORD_ID", page_size = 2)
  expect_error(download_dataset("construction-permits", path,
    fields = "RECORD_ID", where = "RECORD_ID IS NOT NULL", page_size = 2),
    "options, endpoint, schema, CRS, or ID membership changed", class = "tampa_download_error")
  expect_error(download_dataset("construction-permits", path,
    fields = c("RECORD_ID", "LASTUPDATE"), page_size = 2),
    "options, endpoint, schema, CRS, or ID membership changed", class = "tampa_download_error")
  expect_error(download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 1),
    "options, endpoint, schema, CRS, or ID membership changed", class = "tampa_download_error")
  expect_error(download_arcgis_layer(
    "https://example.org/arcgis/rest/services/Other/FeatureServer/0", path,
    fields = "RECORD_ID", page_size = 2),
    "options, endpoint, schema, CRS, or ID membership changed", class = "tampa_download_error")
  expect_error(download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 2, resume = FALSE),
    "resume.*FALSE", class = "tampa_download_error")
})

test_that("resuming rejects schema, CRS, and membership changes even at equal counts", {
  path <- download_test_path()
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  download_dataset("construction-permits", path, fields = "RECORD_ID", page_size = 2)
  changed <- fixture_metadata()
  changed$fields[[2L]]$type <- "esriFieldTypeInteger"
  transport <- fixture_transport(metadata = changed)
  local_mocked_bindings(arcgis_http = transport$http)
  expect_error(download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 2), "schema, CRS, or ID membership changed",
    class = "tampa_download_error")
  changed <- fixture_metadata()
  changed$extent$spatialReference <- list(wkid = 4326)
  transport <- fixture_transport(metadata = changed)
  local_mocked_bindings(arcgis_http = transport$http)
  expect_error(download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 2), "schema, CRS, or ID membership changed",
    class = "tampa_download_error")
  features <- fixture_features()
  features[[3L]]$attributes$OBJECTID <- 6L
  transport <- fixture_transport(features = features)
  local_mocked_bindings(arcgis_http = transport$http)
  expect_error(download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 2), "schema, CRS, or ID membership changed",
    class = "tampa_download_error")
})

test_that("a modified completed chunk is rejected before any new feature request", {
  path <- download_test_path()
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  result <- download_dataset("construction-permits", path,
                              fields = c("OBJECTID", "RECORD_ID"), page_size = 2)
  data <- readRDS(result$files[[1L]])
  data$RECORD_ID[[1L]] <- "tampered local value"
  saveRDS(data, result$files[[1L]])
  resumed <- fixture_transport()
  local_mocked_bindings(arcgis_http = resumed$http)
  expect_error(download_dataset("construction-permits", path,
    fields = c("OBJECTID", "RECORD_ID"), page_size = 2), "completed chunk or checkpoint was altered",
    class = "tampa_download_error")
  expect_length(fixture_queries(resumed, "features"), 0L)
})

test_that("checkpoint publication before chunk rename can be resumed safely", {
  path <- download_test_path()
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  original_write <- .download_write_rds
  local_mocked_bindings(.download_write_rds = function(value, file) {
    original_write(value, file)
    if (grepl("chunk-0000001-0000001.rds$", file)) {
      stop("synthetic interruption after checkpoint")
    }
  })
  expect_error(download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 2), "interruption after checkpoint")
  expect_true(file.exists(file.path(path, ".checkpoints", "chunk-0000001-0000001.rds")))
  expect_false(file.exists(file.path(path, "chunk-0000001.rds")))
  # Leftovers from a hard stop are not interpreted as R data or completed chunks.
  writeLines("unfinished bytes", file.path(path, ".tbod-interrupted.tmp"))
  local_mocked_bindings(.download_write_rds = original_write)
  result <- download_dataset("construction-permits", path,
                              fields = "RECORD_ID", page_size = 2)
  expect_true(result$complete)
  expect_length(result$files, 3L)
  expect_true(file.exists(file.path(path, ".checkpoints", "chunk-0000001-0000002.rds")))
})

test_that("an interrupted initial manifest write leaves a recoverable directory", {
  path <- download_test_path()
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  original_write <- .download_write_rds
  local_mocked_bindings(.download_write_rds = function(value, file) {
    if (identical(basename(file), "manifest.rds")) {
      writeLines("unfinished manifest bytes", file.path(dirname(file), ".tbod-initial.tmp"))
      stop("synthetic interruption during manifest")
    }
    original_write(value, file)
  })
  expect_error(download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 2), "interruption during manifest")
  expect_true(dir.exists(file.path(path, ".checkpoints")))
  expect_false(file.exists(file.path(path, "manifest.rds")))
  expect_false(dir.exists(file.path(path, ".lock")))
  local_mocked_bindings(.download_write_rds = original_write)
  result <- download_dataset("construction-permits", path,
                              fields = "RECORD_ID", page_size = 2)
  expect_true(result$complete)
  expect_length(result$files, 3L)
})

test_that("an active or stale directory lock is preserved and blocks writes", {
  path <- download_test_path()
  dir.create(path)
  lock <- file.path(path, ".lock")
  dir.create(lock)
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  expect_error(download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 2), "directory is busy or has a lock",
    class = "tampa_download_error")
  expect_true(dir.exists(lock))
  expect_false(file.exists(file.path(path, "manifest.rds")))
  expect_length(fixture_queries(transport, "features"), 0L)
})

test_that("a redirected checkpoint directory is rejected before any writes", {
  path <- download_test_path()
  outside <- paste0(path, "-outside")
  dir.create(path)
  dir.create(outside)
  checkpoint_dir <- file.path(path, ".checkpoints")
  linked <- suppressWarnings(file.symlink(outside, checkpoint_dir))
  if (!linked && .Platform$OS.type == "windows") {
    # A junction exercises the same path redirection without symlink privileges.
    status <- suppressWarnings(system2("cmd", c("/c", "mklink", "/J",
      shQuote(checkpoint_dir, type = "cmd"), shQuote(outside, type = "cmd")),
      stdout = FALSE, stderr = FALSE))
    linked <- identical(status, 0L) && dir.exists(checkpoint_dir)
  }
  if (!linked) skip("Directory links are unavailable on this system")
  on.exit({
    # The link and its target were created under this test's temporary root.
    if (dir.exists(checkpoint_dir)) {
      resolved <- normalizePath(checkpoint_dir, winslash = "/", mustWork = TRUE)
      temporary <- paste0(normalizePath(tempdir(), winslash = "/", mustWork = TRUE), "/")
      if (startsWith(tolower(resolved), tolower(temporary))) {
        unlink(checkpoint_dir, recursive = TRUE)
      }
    }
  }, add = TRUE)
  expect_identical(normalizePath(checkpoint_dir, winslash = "/", mustWork = TRUE),
                   normalizePath(outside, winslash = "/", mustWork = TRUE))
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  expect_error(download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 2), "checkpoint directory resolves outside",
    class = "tampa_download_error")
  expect_false(file.exists(file.path(path, "manifest.rds")))
  expect_length(list.files(outside, all.files = TRUE, no.. = TRUE), 0L)
  expect_length(fixture_queries(transport, "features"), 0L)
})

test_that("a checksum alone does not validate a chunk with mismatched provenance", {
  path <- download_test_path()
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  result <- download_dataset("construction-permits", path,
                              fields = "RECORD_ID", page_size = 2)
  data <- readRDS(result$files[[1L]])
  source <- dataset_provenance(data)
  source$query$where <- "unrelated query"
  attr(data, "source") <- source
  saveRDS(data, result$files[[1L]])
  checkpoint_file <- file.path(path, ".checkpoints", "chunk-0000001-0000001.rds")
  checkpoint <- readRDS(checkpoint_file)
  checkpoint$data_md5 <- unname(tools::md5sum(result$files[[1L]]))
  saveRDS(checkpoint, checkpoint_file)
  expect_error(download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 2), "completed chunk or checkpoint was altered",
    class = "tampa_download_error")
  source$query$where <- "1=1"
  source$returned_rows <- NULL
  attr(data, "source") <- source
  saveRDS(data, result$files[[1L]])
  checkpoint$data_md5 <- unname(tools::md5sum(result$files[[1L]]))
  saveRDS(checkpoint, checkpoint_file)
  expect_error(download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 2), "completed chunk or checkpoint was altered",
    class = "tampa_download_error")
})

test_that("direct downloads preserve typed data and direct-URL provenance", {
  path <- download_test_path()
  url <- "https://example.org/arcgis/rest/services/Public/FeatureServer/0"
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  result <- download_arcgis_layer(url, path,
    fields = c("OBJECTID", "RECORD_ID", "CREATEDDATE", "LASTUPDATE"), page_size = 2)
  data <- readRDS(result$files[[1L]])
  expect_s3_class(data, "tbl_df")
  expect_identical(data$OBJECTID, c(1L, 2L))
  expect_type(data$RECORD_ID, "character")
  expect_s3_class(data$CREATEDDATE, "POSIXct")
  expect_true(all(is.na(data$CREATEDDATE)))
  expect_s3_class(data$LASTUPDATE, "POSIXct")
  expect_identical(attr(data$LASTUPDATE, "tzone"), "UTC")
  source <- dataset_provenance(data)
  expect_identical(source$source_url, url)
  expect_identical(source$validation_status, "not_checked")
  expect_identical(source$publisher, "Unknown ArcGIS publisher")
  expect_null(source$item_id)
  expect_identical(result$source$validation_status, "not_checked")
})

test_that("spatial download chunks and resumed chunks retain native geometry", {
  skip_if_not_installed("sf")
  path <- download_test_path()
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  result <- download_dataset("construction-permits", path,
    fields = c("OBJECTID", "RECORD_ID"), spatial = TRUE, page_size = 2)
  for (file in result$files) {
    data <- readRDS(file)
    expect_s3_class(data, "sf")
    expect_equal(sf::st_crs(data)$epsg, 3857)
    expect_false(any(sf::st_is_empty(data)))
    expect_true(all(as.character(sf::st_geometry_type(data)) == "POINT"))
    expect_lte(nrow(data), 2L)
  }
  resumed <- fixture_transport()
  local_mocked_bindings(arcgis_http = resumed$http)
  resumed_result <- download_dataset("construction-permits", path,
    fields = c("OBJECTID", "RECORD_ID"), spatial = TRUE, page_size = 2,
    timeout = 10, total_timeout = 30)
  expect_true(resumed_result$complete)
  expect_length(fixture_queries(resumed, "features"), 0L)
  expect_equal(resumed_result$source$spatial_reference$latestWkid, 3857)
})

test_that("empty downloads are complete and unrelated directories are preserved", {
  path <- download_test_path()
  transport <- fixture_transport(features = list())
  local_mocked_bindings(arcgis_http = transport$http)
  result <- download_dataset("construction-permits", path, where = "1=0",
                              fields = "RECORD_ID", page_size = 2)
  expect_true(result$complete)
  expect_equal(result$matched_rows, 0)
  expect_equal(result$returned_rows, 0)
  expect_identical(result$files, character())
  expect_length(fixture_queries(transport, "features"), 0L)

  unrelated <- download_test_path()
  dir.create(unrelated)
  file <- file.path(unrelated, "notes.txt")
  writeLines("keep this file", file)
  expect_error(download_dataset("construction-permits", unrelated,
    fields = "RECORD_ID"), "unrelated files", class = "tampa_download_error")
  expect_identical(readLines(file), "keep this file")
  expect_identical(list.files(unrelated), "notes.txt")
})

preview_transport <- function(transform = NULL, metadata = fixture_metadata()) {
  fixture_transport(metadata = metadata, count = 1000001,
                     transform = transform)
}

test_that("large finite previews verify only returned IDs against the original filter", {
  transport <- preview_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  result <- get_dataset("construction-permits", limit = 2, page_size = 1,
                        fields = c("RECORD_ID", "LASTUPDATE"),
                        where = "PROJECTSTATUS IS NOT NULL")
  expect_identical(result$RECORD_ID, c("synthetic-1", "synthetic-2"))
  expect_identical(names(result), c("RECORD_ID", "LASTUPDATE"))
  expect_s3_class(result$LASTUPDATE, "POSIXct")
  source <- dataset_provenance(result)
  expect_false(source$complete)
  expect_equal(source$matched_rows, 1000001)
  expect_identical(source$returned_rows, 2L)
  expect_identical(source$integrity, "subset-manifest")
  expect_identical(source$pagination, "ordered preview")
  ids <- fixture_queries(transport, "ids")
  expect_length(ids, 1L)
  expect_identical(ids[[1L]]$params$objectIds, "1,2")
  expect_identical(ids[[1L]]$params$where, "PROJECTSTATUS IS NOT NULL")
  pages <- fixture_queries(transport, "features")
  expect_length(pages, 2L)
  expect_true(all(vapply(pages, function(x) {
    identical(x$params$orderByFields, "OBJECTID ASC")
  }, logical(1))))
  expect_equal(vapply(pages, function(x) x$params$resultOffset, numeric(1)), c(0, 1))
})

test_that("preview ordering and geometry use the same validated response pipeline", {
  transport <- preview_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  result <- get_dataset("construction-permits", fields = "OBJECTID", limit = 2,
                        order_by = "OBJECTID DESC", page_size = 1)
  expect_identical(result$OBJECTID, 5:4)
  expect_identical(fixture_queries(transport, "ids")[[1L]]$params$objectIds, "5,4")
  expect_false(dataset_provenance(result)$complete)

  skip_if_not_installed("sf")
  transport <- preview_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  spatial <- get_dataset("construction-permits", limit = 2, spatial = TRUE,
                         fields = "OBJECTID", out_sr = 4326)
  expect_s3_class(spatial, "sf")
  expect_equal(sf::st_crs(spatial)$epsg, 4326)
  expect_identical(spatial$OBJECTID, 1:2)
  expect_identical(dataset_provenance(spatial)$integrity, "subset-manifest")
})

test_that("full verification and unsupported previews retain the manifest size gate", {
  for (options in list(list(limit = Inf), list(limit = 2, integrity = "full"),
                        list(limit = 1001))) {
    transport <- preview_transport()
    local_mocked_bindings(arcgis_http = transport$http)
    expect_error(do.call(get_dataset, c(list(id = "construction-permits"), options)),
                 "one million", class = "tampa_integrity_error")
    expect_length(fixture_queries(transport, "ids"), 0L)
    expect_length(fixture_queries(transport, "features"), 0L)
  }
  for (metadata in list(fixture_metadata(pagination = FALSE),
                        fixture_metadata(ordering = FALSE))) {
    transport <- preview_transport(metadata = metadata)
    local_mocked_bindings(arcgis_http = transport$http)
    expect_error(get_dataset("construction-permits", limit = 2), "one million",
                 class = "tampa_integrity_error")
    expect_length(fixture_queries(transport, "features"), 0L)
  }
})

test_that("zero limits get typed results and counts without an ID manifest", {
  transport <- preview_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  result <- get_dataset("construction-permits", limit = 0,
                        fields = c("OBJECTID", "LASTUPDATE"))
  expect_identical(result$OBJECTID, integer())
  expect_s3_class(result$LASTUPDATE, "POSIXct")
  expect_identical(nrow(result), 0L)
  expect_false(dataset_provenance(result)$complete)
  expect_equal(dataset_provenance(result)$matched_rows, 1000001)
  expect_identical(dataset_provenance(result)$integrity, "count-only")
  expect_length(fixture_queries(transport, "count"), 1L)
  expect_length(fixture_queries(transport, "ids"), 0L)
  expect_length(fixture_queries(transport, "features"), 0L)
})

test_that("previews reject malformed, truncated, or changed subset manifests", {
  changes <- list(
    function(payload) { payload$objectIds <- list(1L, 99L); payload },
    function(payload) { payload$objectIds <- list(1L); payload },
    function(payload) { payload$objectIds <- list(1L, 1L); payload },
    function(payload) { payload$exceededTransferLimit <- TRUE; payload },
    function(payload) { payload$objectIdFieldName <- "OTHER_ID"; payload }
  )
  for (change in changes) {
    transport <- preview_transport(transform = function(payload, params, ...) {
      if (identical(params$returnIdsOnly, "true")) payload <- change(payload)
      payload
    })
    local_mocked_bindings(arcgis_http = transport$http)
    expect_error(get_dataset("construction-permits", limit = 2),
                 class = "tampa_integrity_error")
  }
})

test_that("preview pages cannot silently repeat or stop early", {
  for (mode in c("repeat", "empty")) {
    transport <- preview_transport(transform = function(payload, params, ...) {
      if (!is.null(params$resultOffset) && params$resultOffset == 1) {
        payload$features <- if (mode == "repeat") fixture_features(1L) else list()
      }
      payload
    })
    local_mocked_bindings(arcgis_http = transport$http)
    expect_error(get_dataset("construction-permits", limit = 2, page_size = 1),
                 class = "tampa_integrity_error")
  }
})

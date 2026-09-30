test_that("each small convenience wrapper delegates all arguments to the generic client", {
  calls <- list()
  sentinel <- tibble::tibble(value = "generic-client-result")
  local_mocked_bindings(get_dataset = function(id, ...) {
    calls[[length(calls) + 1L]] <<- c(list(id = id), list(...))
    sentinel
  }, .package = "tampaBayOpenData")
  query <- list(time = "0,10000")
  expect_identical(get_permits(fields = "RECORD_ID", where = "PROJECTSTATUS = 'Issued'",
                               limit = 7, query = query), sentinel)
  expect_identical(get_development_cases(spatial = TRUE, out_sr = 4326, timeout = 11), sentinel)
  expect_identical(get_capital_projects(jurisdiction = "tampa", order_by = "projid ASC"), sentinel)
  expect_identical(vapply(calls, function(x) x$id, character(1)),
                   c("construction-permits", "development-cases", "capital-projects"))
  expect_identical(calls[[1L]]$fields, "RECORD_ID")
  expect_identical(calls[[1L]]$where, "PROJECTSTATUS = 'Issued'")
  expect_identical(calls[[1L]]$query, query)
  expect_equal(calls[[1L]]$limit, 7)
  expect_true(calls[[2L]]$spatial)
  expect_equal(calls[[2L]]$out_sr, 4326)
  expect_equal(calls[[2L]]$timeout, 11)
  expect_identical(calls[[3L]]$jurisdiction, "tampa")
  expect_identical(calls[[3L]]$order_by, "projid ASC")
})

test_that("wrapper results retain generic parsing and source provenance", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  permits <- get_permits(limit = 2, fields = c("RECORD_ID", "LASTUPDATE"))
  expect_s3_class(permits, "tbl_df")
  expect_s3_class(permits$LASTUPDATE, "POSIXct")
  expect_identical(dataset_provenance(permits)$dataset_id, "construction-permits")
  expect_false(dataset_provenance(permits)$complete)
})

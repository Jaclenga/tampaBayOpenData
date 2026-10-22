test_that("incompatible schema errors explain why retrieval stopped", {
  metadata <- fixture_metadata()
  metadata$fields <- Filter(function(field) field$name != "PROJECTSTATUS",
                            metadata$fields)
  transport <- fixture_transport(metadata = metadata)
  local_mocked_bindings(arcgis_http = transport$http)

  failure <- tryCatch(tbod_get_dataset("construction-permits"),
                      error = identity)
  expect_s3_class(failure, "tampa_schema_error")
  expect_match(conditionMessage(failure), "structure no longer matches")
  expect_match(conditionMessage(failure), "removed_field.*PROJECTSTATUS")
  expect_match(conditionMessage(failure), "retrieval stopped")
  expect_match(conditionMessage(failure), "tbod_check_schema\\(\\)")
  expect_length(fixture_queries(transport, "features"), 0L)
})

test_that("missing records explain that no partial result was returned", {
  transport <- fixture_transport(transform = function(payload, params, ...) {
    if (!is.null(params$objectIds)) {
      payload$features <- Filter(function(feature) {
        feature$attributes$OBJECTID != 1L
      }, payload$features)
    }
    payload
  })
  local_mocked_bindings(arcgis_http = transport$http)

  failure <- tryCatch(tbod_get_dataset("construction-permits"),
                      error = identity)
  expect_s3_class(failure, "tampa_integrity_error")
  expect_match(conditionMessage(failure), "missing requested records")
  expect_match(conditionMessage(failure), "even when fetched one at a time")
  expect_match(conditionMessage(failure), "Retrieval stopped")
  expect_match(conditionMessage(failure), "try again later")
})

test_that("repeated ordered pages identify duplicate IDs and a recovery action", {
  transport <- fixture_transport(transform = function(payload, params, ...) {
    if (identical(params$resultOffset, 2L)) {
      payload$features <- fixture_features(1L)
    }
    payload
  })
  local_mocked_bindings(arcgis_http = transport$http)

  failure <- tryCatch(tbod_get_dataset("construction-permits",
                                       order_by = "OBJECTID", page_size = 2),
                      error = identity)
  expect_s3_class(failure, "tampa_pagination_error")
  expect_s3_class(failure, "tampa_integrity_error")
  expect_match(conditionMessage(failure), "record ID seen on an earlier page")
  expect_match(conditionMessage(failure), "Retrieval stopped")
  expect_match(conditionMessage(failure), "omit `order_by`")
})

test_that("short ordered pages explain why the result is incomplete", {
  transport <- fixture_transport(transform = function(payload, params, ...) {
    if (identical(params$resultOffset, 0L)) {
      payload$features <- payload$features[1L]
      payload$exceededTransferLimit <- FALSE
    }
    payload
  })
  local_mocked_bindings(arcgis_http = transport$http)

  failure <- tryCatch(tbod_get_dataset("construction-permits",
                                       order_by = "OBJECTID", page_size = 2),
                      error = identity)
  expect_s3_class(failure, "tampa_pagination_error")
  expect_match(conditionMessage(failure), "fewer records than requested")
  expect_match(conditionMessage(failure), "incomplete result")
  expect_match(conditionMessage(failure), "omit `order_by`")
})

test_that("failed automatic preview fallback reports both failures", {
  transport <- fixture_transport(count = 10001L, transform = function(payload,
                                                                      params, ...) {
    if (!is.null(params$resultOffset)) {
      return(list(error = list(code = 400L,
                               message = "resultOffset is not supported: SYNTHETIC_SECRET_VALUE",
                               details = list())))
    }
    if (identical(params$returnIdsOnly, "true")) {
      return(list(error = list(code = 400L,
                               message = "Could not list IDs: SYNTHETIC_SECRET_VALUE",
                               details = list())))
    }
    payload
  })
  local_mocked_bindings(arcgis_http = transport$http)

  failure <- tryCatch(tbod_get_dataset("construction-permits", limit = 2),
                      error = identity)
  expect_s3_class(failure, "tampa_pagination_error")
  expect_s3_class(failure, "tampa_integrity_error")
  expect_match(conditionMessage(failure), "offset preview failed")
  expect_match(conditionMessage(failure), "manifest fallback also failed")
  expect_match(conditionMessage(failure), "incomplete preview")
  expect_false(grepl("SYNTHETIC_SECRET_VALUE", conditionMessage(failure),
                     fixed = TRUE))
})

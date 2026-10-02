test_that("a feature requires the exact attributes member", {
  metadata <- list(objectIdField = "OBJECTID")
  feature <- list(attributesExtra = list(OBJECTID = 1L, VALUE = "wrong key"))
  expect_error(
    .page_features(list(features = list(feature)), metadata, NULL, "probe"),
    "missing its attributes", class = "tampa_response_error"
  )

  feature$attributes <- list(OBJECTID = 2L, VALUE = "right key")
  page <- .page_features(list(features = list(feature)), metadata, NULL, "probe")
  expect_identical(page$ids, 2)
})

test_that("the retry policy includes gateway failures and preserves existing cases", {
  requests <- list()
  local_mocked_bindings(
    req_perform = function(req, ...) {
      requests[[length(requests) + 1L]] <<- req
      httr2::response(status_code = 200L, url = req$url, body = charToRaw("{}"))
    },
    .package = "httr2"
  )
  arcgis_http("https://example.invalid/FeatureServer/0", list(f = "json"), 1)
  policy <- requests[[1L]]$policies
  expect_true(policy$retry_on_failure)
  for (status in c(429L, 500L, 502L, 503L, 504L)) {
    expect_true(policy$retry_is_transient(httr2::response(status_code = status)))
  }
  for (status in c(400L, 404L, 501L, 508L)) {
    expect_false(policy$retry_is_transient(httr2::response(status_code = status)))
  }
})

test_that("the retry loop recovers from consecutive gateway failures", {
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(
    req_perform = fixture_req_perform,
    req_perform1 = function(req, ...) {
      attempts <<- attempts + 1L
      status <- c(502L, 504L, 200L)[[attempts]]
      httr2::response(status_code = status, url = req$url,
                      body = charToRaw('{"count":1}'))
    },
    sys_sleep = function(seconds, ...) waits <<- c(waits, seconds),
    .package = "httr2"
  )
  response <- arcgis_http("https://example.invalid/FeatureServer/0",
                          list(f = "json"), 1)
  expect_identical(response$status, 200L)
  expect_identical(attempts, 3L)
  expect_true(length(waits) >= 2L)
  expect_true(all(is.finite(waits) & waits >= 0))
})

test_that("the retry loop recovers from a transient transport failure", {
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(
    req_perform = fixture_req_perform,
    req_perform1 = function(req, ...) {
      attempts <<- attempts + 1L
      # httr2's transport returns a curl error condition for retry handling.
      if (attempts == 1L) return(simpleError("synthetic connection reset"))
      httr2::response(status_code = 200L, url = req$url,
                      body = charToRaw('{"count":1}'))
    },
    sys_sleep = function(seconds, ...) waits <<- c(waits, seconds),
    .package = "httr2"
  )
  response <- arcgis_http("https://example.invalid/FeatureServer/0",
                          list(f = "json"), 1)
  expect_identical(response$status, 200L)
  expect_identical(attempts, 2L)
  expect_gte(length(waits), 2L)
  expect_true(all(is.finite(waits) & waits >= 0))
})

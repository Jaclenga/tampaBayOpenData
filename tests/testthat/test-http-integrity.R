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

test_that("only the selected HTTP statuses trigger another attempt", {
  previous <- options(tampaBayOpenData.max_retries = 1L)
  on.exit(options(previous), add = TRUE)
  local_mocked_bindings(.operation_sleep = function(...) invisible(NULL))
  for (status in c(429L, 500L, 502L, 503L, 504L,
                   400L, 401L, 403L, 404L, 501L, 508L)) {
    attempts <- 0L
    local_mocked_bindings(req_perform = function(req, ...) {
      attempts <<- attempts + 1L
      httr2::response(status_code = if (attempts == 1L) status else 200L,
                      url = req$url, body = charToRaw("{}"))
    }, .package = "httr2")
    response <- arcgis_http("https://example.invalid/FeatureServer/0",
                            list(f = "json"), 1)
    transient <- status %in% c(429L, 500L, 502L, 503L, 504L)
    expect_identical(response$status, if (transient) 200L else status)
    expect_identical(attempts, if (transient) 2L else 1L)
  }
})

test_that("the retry loop recovers from consecutive gateway failures", {
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(.operation_sleep = function(seconds) {
    waits <<- c(waits, seconds)
  })
  local_mocked_bindings(
    req_perform = function(req, ...) {
      attempts <<- attempts + 1L
      status <- c(502L, 504L, 200L)[[attempts]]
      httr2::response(status_code = status, url = req$url,
                      body = charToRaw('{"count":1}'))
    },
    .package = "httr2"
  )
  response <- arcgis_http("https://example.invalid/FeatureServer/0",
                          list(f = "json"), 1)
  expect_identical(response$status, 200L)
  expect_identical(attempts, 3L)
  expect_length(waits, 2L)
  expect_true(all(is.finite(waits) & waits >= 0))
})

test_that("the retry loop recovers from a transient transport failure", {
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(.operation_sleep = function(seconds) {
    waits <<- c(waits, seconds)
  })
  local_mocked_bindings(
    req_perform = function(req, ...) {
      attempts <<- attempts + 1L
      if (attempts == 1L) {
        failure <- simpleError("synthetic connection reset")
        class(failure) <- c("curl_error", class(failure))
        stop(failure)
      }
      httr2::response(status_code = 200L, url = req$url,
                      body = charToRaw('{"count":1}'))
    },
    .package = "httr2"
  )
  response <- arcgis_http("https://example.invalid/FeatureServer/0",
                          list(f = "json"), 1)
  expect_identical(response$status, 200L)
  expect_identical(attempts, 2L)
  expect_length(waits, 1L)
  expect_true(all(is.finite(waits) & waits >= 0))
})

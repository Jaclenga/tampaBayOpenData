test_that("a transient ArcGIS error during a later page recovers without duplicate rows", {
  transport <- fixture_transport()
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(
    arcgis_http = function(url, params, timeout) {
      if (identical(params$objectIds, "3,4")) {
        attempts <<- attempts + 1L
        if (attempts == 1L) {
          return(fixture_response(list(error = list(
            code = 400L, message = "Unable to complete operation.", details = list()))))
        }
      }
      transport$http(url, params, timeout)
    },
    .operation_sleep = function(seconds) waits <<- c(waits, seconds)
  )

  result <- tbod_get_dataset("construction-permits", page_size = 2)
  expect_identical(result$OBJECTID, 1:5)
  expect_true(tbod_provenance(result)$complete)
  expect_identical(attempts, 2L)
  expect_length(waits, 1L)
  expect_true(is.finite(waits) && waits >= 0 && waits <= 30)
  expect_identical(vapply(fixture_queries(transport, "features"),
                          function(x) x$params$objectIds, character(1)),
                   c("1,2", "3,4", "5"))
})

test_that("authentication errors in a successful HTTP response are permanent", {
  transport <- fixture_transport()
  attempts <- 0L
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    if (identical(params$objectIds, "3,4")) {
      attempts <<- attempts + 1L
      return(fixture_response(list(error = list(
        code = 498L, message = "Invalid token", details = list()))))
    }
    transport$http(url, params, timeout)
  })

  error <- tryCatch(tbod_get_dataset("construction-permits", page_size = 2),
                    error = identity)
  expect_s3_class(error, "tampa_arcgis_error")
  expect_match(conditionMessage(error), "Invalid token", fixed = TRUE)
  expect_match(conditionMessage(error), "/query", fixed = TRUE)
  expect_identical(attempts, 1L)
})

test_that("a transient ArcGIS 503 body recovers under HTTP 200", {
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(
    arcgis_http = function(...) {
      attempts <<- attempts + 1L
      if (attempts == 1L) {
        return(fixture_response(list(error = list(
          code = 503L, message = "Service unavailable", details = list()))))
      }
      fixture_response(list(count = 5L))
    },
    .operation_sleep = function(seconds) waits <<- c(waits, seconds)
  )

  expect_identical(arcgis_request(
    "https://example.invalid/FeatureServer/0/query",
    list(returnCountOnly = "true"))$count, 5L)
  expect_identical(attempts, 2L)
  expect_length(waits, 1L)
})

test_that("a service without offset pagination uses capped object-ID batches", {
  metadata <- fixture_metadata(max_records = 2L, pagination = FALSE, ordering = TRUE)
  transport <- fixture_transport(metadata = metadata)
  local_mocked_bindings(arcgis_http = transport$http)

  result <- tbod_get_dataset("construction-permits", page_size = 1000)
  expect_identical(result$OBJECTID, 1:5)
  expect_identical(tbod_provenance(result)$pagination, "object-id batches")
  requests <- fixture_queries(transport, "features")
  expect_identical(vapply(requests, function(x) x$params$objectIds,
                          character(1)), c("1,2", "3,4", "5"))
  expect_true(all(vapply(requests, function(x) is.null(x$params$resultOffset),
                         logical(1))))
  expect_error(tbod_get_dataset("construction-permits", order_by = "OBJECTID"),
               "ordering with pagination", class = "tampa_data_error")
})

test_that("silently short object-ID pages are split and recovered", {
  transport <- fixture_transport(transform = function(payload, params, ...) {
    if (identical(params$objectIds, "3,4")) {
      payload$features <- payload$features[1L]
      payload$exceededTransferLimit <- FALSE
    }
    payload
  })
  local_mocked_bindings(arcgis_http = transport$http)

  result <- tbod_get_dataset("construction-permits", page_size = 2)
  expect_identical(result$OBJECTID, 1:5)
  expect_true(tbod_provenance(result)$complete)
  expect_identical(vapply(fixture_queries(transport, "features"),
                          function(x) x$params$objectIds, character(1)),
                   c("1,2", "3,4", "3", "4", "5"))
})

test_that("automatic preview falls back when the service ignores offsets", {
  transport <- fixture_transport(
    features = fixture_features(1:2), ids = seq_len(10001L), count = 10001L,
    metadata = fixture_metadata(max_records = 1L),
    transform = function(payload, params, ...) {
      if (identical(params$resultOffset, 1L)) {
        payload$features <- fixture_features(1L)
      }
      payload
    })
  local_mocked_bindings(arcgis_http = transport$http)

  result <- tbod_get_dataset("construction-permits", limit = 2, page_size = 1)
  expect_identical(result$OBJECTID, 1:2)
  expect_false(tbod_provenance(result)$complete)
  expect_identical(tbod_provenance(result)$pagination, "object-id fallback")
  expect_length(fixture_queries(transport, "ids"), 1L)
  expect_identical(vapply(fixture_queries(transport, "features"),
                          function(x) x$params$objectIds %||% "", character(1)),
                   c("", "", "1", "2"))

  expect_error(tbod_get_dataset("construction-permits", limit = 2,
                                page_size = 1, order_by = "OBJECTID"),
               class = "tampa_integrity_error")
})

test_that("automatic preview falls back when offset queries are rejected", {
  transport <- fixture_transport(
    features = fixture_features(1:2), ids = seq_len(10001L), count = 10001L,
    metadata = fixture_metadata(max_records = 1L))
  offset_attempts <- 0L
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    if (!is.null(params$resultOffset)) {
      offset_attempts <<- offset_attempts + 1L
      return(fixture_response(list(error = list(
        code = 400L, message = "resultOffset is not supported",
        details = list()))))
    }
    transport$http(url, params, timeout)
  })

  result <- tbod_get_dataset("construction-permits", limit = 2, page_size = 1)
  expect_identical(result$OBJECTID, 1:2)
  expect_identical(offset_attempts, 1L)
  expect_identical(tbod_provenance(result)$pagination, "object-id fallback")
  expect_length(fixture_queries(transport, "ids"), 1L)
})

test_that("a short download page preserves only validated chunks for resume", {
  path <- tempfile("tbod-short-page-", tmpdir = tempdir())
  short <- fixture_transport(transform = function(payload, params, ...) {
    if (identical(params$objectIds, "3,4")) {
      payload$features <- payload$features[1L]
      payload$exceededTransferLimit <- FALSE
    }
    if (identical(params$objectIds, "4")) payload$features <- list()
    payload
  })
  local_mocked_bindings(arcgis_http = short$http)
  expect_error(tbod_download_dataset("construction-permits", path,
                                     fields = "RECORD_ID", page_size = 2),
               "missing requested records", class = "tampa_integrity_error")
  first <- file.path(path, "chunk-0000001.rds")
  expect_true(file.exists(first))
  expect_false(tbod_provenance(readRDS(first))$complete)
  expect_false(file.exists(file.path(path, "chunk-0000002.rds")))
  expect_false(file.exists(file.path(path, "complete.rds")))

  resumed <- fixture_transport()
  local_mocked_bindings(arcgis_http = resumed$http)
  result <- tbod_download_dataset("construction-permits", path,
                                  fields = "RECORD_ID", page_size = 2)
  expect_true(result$complete)
  expect_true(file.exists(file.path(path, "complete.rds")))
  expect_identical(result$returned_rows, 5L)
  expect_identical(vapply(fixture_queries(resumed, "features"),
                          function(x) x$params$objectIds, character(1)),
                   c("3,4", "5"))
})

test_that("configurable retries recover from 500 and 503 within a fixed bound", {
  previous <- options(tampaBayOpenData.max_retries = 2L)
  on.exit(options(previous), add = TRUE)
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    status <- c(500L, 503L, 200L)[[attempts]]
    httr2::response(status_code = status, url = req$url,
                    body = charToRaw('{"count":5}'))
  }, .package = "httr2")
  local_mocked_bindings(.operation_sleep = function(seconds) {
    waits <<- c(waits, seconds)
  })

  result <- arcgis_request("https://example.invalid/FeatureServer/0/query")
  expect_identical(result$count, 5L)
  expect_identical(attempts, 3L)
  expect_length(waits, 2L)
  expect_true(all(is.finite(waits) & waits >= 0 & waits <= 30))
})

test_that("repeated transport timeouts exhaust the configured attempt count", {
  previous <- options(tampaBayOpenData.max_retries = 2L)
  on.exit(options(previous), add = TRUE)
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    failure <- simpleError("synthetic operation timed out")
    class(failure) <- c("curl_error", class(failure))
    stop(failure)
  }, .package = "httr2")
  local_mocked_bindings(.operation_sleep = function(seconds) {
    waits <<- c(waits, seconds)
  })

  error <- tryCatch(arcgis_request("https://example.invalid/FeatureServer/0/query"),
                    error = identity)
  expect_s3_class(error, "tampa_http_error")
  expect_match(conditionMessage(error), "timed out", fixed = TRUE)
  expect_match(conditionMessage(error), "query", fixed = TRUE)
  expect_identical(attempts, 3L)
  expect_length(waits, 2L)
})

test_that("an HTTP-date Retry-After controls the next rate-limit attempt", {
  previous <- options(tampaBayOpenData.max_retries = 1L)
  on.exit(options(previous), add = TRUE)
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    if (attempts == 1L) {
      return(httr2::response(status_code = 429L, url = req$url,
        headers = list(Date = "Tue, 29 Sep 2026 08:00:00 GMT",
                       `Retry-After` = "Tue, 29 Sep 2026 08:00:05 GMT"),
        body = charToRaw("{}")))
    }
    httr2::response(status_code = 200L, url = req$url,
                    body = charToRaw('{"count":5}'))
  }, .package = "httr2")
  local_mocked_bindings(.operation_sleep = function(seconds) {
    waits <<- c(waits, seconds)
  })

  expect_identical(arcgis_request("https://example.invalid/FeatureServer/0/query")$count,
                   5L)
  expect_identical(attempts, 2L)
  expect_equal(waits, 5)
})

test_that("an ArcGIS rate-limit body in HTTP 200 honors Retry-After", {
  previous <- options(tampaBayOpenData.max_retries = 1L)
  on.exit(options(previous), add = TRUE)
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    if (attempts == 1L) {
      return(httr2::response(status_code = 200L, url = req$url,
        headers = list(`Retry-After` = "10"),
        body = charToRaw('{"error":{"code":429,"message":"Rate limited","details":[]}}')))
    }
    httr2::response(status_code = 200L, url = req$url,
                    body = charToRaw('{"count":5}'))
  }, .package = "httr2")
  local_mocked_bindings(.operation_sleep = function(seconds) waits <<- c(waits, seconds))

  expect_identical(arcgis_request("https://example.invalid/FeatureServer/0/query")$count,
                   5L)
  expect_identical(attempts, 2L)
  expect_equal(waits, 10)
})

test_that("an ArcGIS rate-limit body does not retry before a long Retry-After", {
  previous <- options(tampaBayOpenData.max_retries = 1L)
  on.exit(options(previous), add = TRUE)
  attempts <- 0L
  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    httr2::response(status_code = 200L, url = req$url,
      headers = list(`Retry-After` = "60"),
      body = charToRaw('{"error":{"code":429,"message":"Rate limited","details":[]}}'))
  }, .package = "httr2")
  local_mocked_bindings(.operation_sleep = function(...) stop("No early wait expected"))

  error <- tryCatch(arcgis_request("https://example.invalid/FeatureServer/0/query"),
                    error = identity)
  expect_s3_class(error, "tampa_arcgis_transient_error")
  expect_match(conditionMessage(error), "60-second Retry-After", fixed = TRUE)
  expect_match(conditionMessage(error), "no early retry", fixed = TRUE)
  expect_identical(attempts, 1L)
})

test_that("an unrepresentably long Retry-After cannot cause an early ArcGIS retry", {
  previous <- options(tampaBayOpenData.max_retries = 1L)
  on.exit(options(previous), add = TRUE)
  attempts <- 0L
  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    httr2::response(status_code = 200L, url = req$url,
      headers = list(`Retry-After` = strrep("9", 400L)),
      body = charToRaw('{"error":{"code":429,"message":"Rate limited","details":[]}}'))
  }, .package = "httr2")
  local_mocked_bindings(.operation_sleep = function(...) stop("No early wait expected"))

  error <- tryCatch(arcgis_request("https://example.invalid/FeatureServer/0/query"),
                    error = identity)
  expect_s3_class(error, "tampa_arcgis_transient_error")
  expect_match(conditionMessage(error), "Retry-After", fixed = TRUE)
  expect_identical(attempts, 1L)
})

test_that("invalid Retry-After on an ArcGIS body uses jittered backoff", {
  previous <- options(tampaBayOpenData.max_retries = 1L)
  on.exit(options(previous), add = TRUE)
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    httr2::response(status_code = 200L, url = req$url,
      headers = list(`Retry-After` = "invalid"),
      body = charToRaw(if (attempts == 1L)
        '{"error":{"code":429,"message":"Rate limited","details":[]}}' else
        '{"count":5}'))
  }, .package = "httr2")
  local_mocked_bindings(.arcgis_backoff = function(...) 0.25,
                        .operation_sleep = function(seconds) waits <<- c(waits, seconds))

  expect_identical(arcgis_request("https://example.invalid/FeatureServer/0/query")$count,
                   5L)
  expect_identical(attempts, 2L)
  expect_equal(waits, 0.25)
})

test_that("a Retry-After beyond the wait bound does not trigger an early retry", {
  previous <- options(tampaBayOpenData.max_retries = 1L)
  on.exit(options(previous), add = TRUE)
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    httr2::response(status_code = 429L, url = req$url,
      headers = list(Date = "Tue, 29 Sep 2026 08:00:00 GMT",
                     `Retry-After` = "Tue, 29 Sep 2026 08:01:00 GMT"),
      body = charToRaw("{}"))
  }, .package = "httr2")
  local_mocked_bindings(.operation_sleep = function(seconds) {
    waits <<- c(waits, seconds)
  })

  error <- tryCatch(arcgis_request("https://example.invalid/FeatureServer/0/query"),
                    error = identity)
  expect_s3_class(error, "tampa_http_error")
  expect_match(conditionMessage(error), "60-second Retry-After", fixed = TRUE)
  expect_match(conditionMessage(error), "no early retry", fixed = TRUE)
  expect_identical(attempts, 1L)
  expect_length(waits, 0L)
})

test_that("zero retries returns the original rate-limit status without a wait", {
  previous <- options(tampaBayOpenData.max_retries = 0L)
  on.exit(options(previous), add = TRUE)
  attempts <- 0L
  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    httr2::response(status_code = 429L, url = req$url,
                    body = charToRaw("{}"))
  }, .package = "httr2")
  local_mocked_bindings(.operation_sleep = function(...) {
    stop("No retry wait expected", call. = FALSE)
  })

  error <- tryCatch(arcgis_request("https://example.invalid/FeatureServer/0/query"),
                    error = identity)
  expect_s3_class(error, "tampa_http_error")
  expect_match(conditionMessage(error), "HTTP 429", fixed = TRUE)
  expect_identical(attempts, 1L)
})

test_that("zero retries also disables generic ArcGIS query recovery", {
  previous <- options(tampaBayOpenData.max_retries = 0L)
  on.exit(options(previous), add = TRUE)
  attempts <- 0L
  local_mocked_bindings(arcgis_http = function(...) {
    attempts <<- attempts + 1L
    fixture_response(list(error = list(
      code = 400L, message = "Unable to complete operation.", details = list())))
  })
  local_mocked_bindings(.operation_sleep = function(...) {
    stop("No retry wait expected", call. = FALSE)
  })

  expect_error(arcgis_request("https://example.invalid/FeatureServer/0/query"),
               "Unable to complete operation", class = "tampa_arcgis_error")
  expect_identical(attempts, 1L)
})

test_that("invalid retry counts fail before any network request", {
  previous <- options(tampaBayOpenData.max_retries = NULL)
  on.exit(options(previous), add = TRUE)
  attempts <- 0L
  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    stop("unexpected dispatch")
  }, .package = "httr2")

  for (value in list(-1L, 11L, 1.5, NA_integer_, "3", c(1L, 2L))) {
    options(tampaBayOpenData.max_retries = value)
    expect_error(arcgis_request("https://example.invalid/FeatureServer/0/query"),
                 "max_retries", class = "tampa_input_error")
  }
  expect_identical(attempts, 0L)
})

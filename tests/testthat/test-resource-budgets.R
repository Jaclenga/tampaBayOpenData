test_that("operation budgets validate inputs and preserve a tighter parent deadline", {
  local_mocked_bindings(.operation_clock = function() 10)
  timeout <- .operation_timeout(30, 5)
  expect_equal(.operation_remaining(timeout), 5)
  expect_identical(as.numeric(timeout), 30)
  expect_identical(.operation_timeout(timeout, 100), timeout)
  expect_identical(.operation_timeout(timeout, Inf), timeout)
  expect_null(attr(.operation_timeout(30, Inf), "tampa_deadline"))
  for (invalid in list(0, -1, NA_real_, NaN, "10", c(1, 2))) {
    expect_error(get_dataset("construction-permits", total_timeout = invalid),
                 class = "tampa_input_error")
  }
  expect_error(get_dataset("construction-permits", integrity = "unchecked"),
               class = "tampa_input_error")
  expect_error(get_dataset("construction-permits", timeout = 0.0001),
               class = "tampa_input_error")
})

test_that("expiration between requests fails before fetching any feature page", {
  clock <- new.env(parent = emptyenv())
  clock$value <- 0
  transport <- fixture_transport()
  local_mocked_bindings(
    .operation_clock = function() clock$value,
    arcgis_http = function(...) {
      response <- transport$http(...)
      clock$value <- clock$value + 1
      response
    }
  )
  error <- tryCatch(get_dataset("construction-permits", total_timeout = 3),
                    error = identity)
  expect_s3_class(error, "tampa_timeout_error")
  expect_identical(error$dataset_id, "construction-permits")
  expect_match(conditionMessage(error), "total_timeout")
  expect_length(transport$state$requests, 3L)
  expect_length(fixture_queries(transport, "features"), 0L)
})

test_that("late parsing cannot return a successful result after the budget expires", {
  clock <- new.env(parent = emptyenv())
  clock$value <- 0
  parse <- arcgis_parse
  local_mocked_bindings(
    .operation_clock = function() clock$value,
    arcgis_http = fixture_transport()$http,
    arcgis_parse = function(...) {
      result <- parse(...)
      clock$value <- 2
      result
    }
  )
  expect_error(get_dataset("construction-permits", total_timeout = 1),
               "total_timeout", class = "tampa_timeout_error")
})

test_that("each budgeted transport retry gets only the remaining transfer time", {
  clock <- new.env(parent = emptyenv())
  clock$value <- 0
  requests <- list()
  local_mocked_bindings(.operation_clock = function() clock$value,
                        .operation_sleep = function(seconds) {
                          clock$value <- clock$value + seconds
                        })
  local_mocked_bindings(req_perform = function(req, ...) {
    requests[[length(requests) + 1L]] <<- req
    clock$value <- clock$value + 1
    httr2::response(status_code = if (length(requests) == 1L) 429L else 200L,
      url = req$url, headers = list(`Retry-After` = "0"),
      body = charToRaw('{"count":2}'))
  }, .package = "httr2")
  result <- arcgis_request("https://example.invalid/FeatureServer/0",
                           timeout = .operation_timeout(30, 5))
  expect_identical(result$count, 2L)
  expect_length(requests, 2L)
  expect_equal(vapply(requests, function(x) x$options$timeout_ms, numeric(1)),
               c(5000, 4000))
  expect_true(all(vapply(requests, function(x) {
    is.null(x$policies$retry_max_tries)
  }, logical(1))))
})

test_that("budgeted waits cannot exceed the remaining time or hide timeout errors", {
  clock <- new.env(parent = emptyenv())
  clock$value <- 0
  attempts <- 0L
  local_mocked_bindings(.operation_clock = function() clock$value,
                        .operation_sleep = function(...) stop("unexpected sleep"))
  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    httr2::response(status_code = 503L, url = req$url,
      headers = list(`Retry-After` = "86400"), body = charToRaw('{}'))
  }, .package = "httr2")
  expect_error(arcgis_request("https://example.invalid/FeatureServer/0",
                              timeout = .operation_timeout(30, 1)),
               "time budget", class = "tampa_timeout_error")
  expect_identical(attempts, 1L)

  local_mocked_bindings(arcgis_http = function(...) fixture_response(list(
    error = list(code = 400L, message = "Unable to complete operation.",
                  details = list()))),
    .arcgis_retry_pause = function(...) stop("unexpected sleep"))
  expect_error(arcgis_request("https://example.invalid/FeatureServer/0/query",
                              timeout = .operation_timeout(30, 0.1)),
               "time budget", class = "tampa_timeout_error")
})

test_that("expired budgets block dispatch and unlimited operations retain retry policy", {
  local_mocked_bindings(.operation_clock = function() 5,
                        arcgis_http = function(...) stop("unexpected dispatch"))
  timeout <- 30
  attr(timeout, "tampa_deadline") <- 4
  expect_error(arcgis_request("probe", timeout = timeout),
               "total_timeout", class = "tampa_timeout_error")
  expect_invisible(.check_operation_timeout(30))
})

test_that("less than one millisecond remaining stops before transport dispatch", {
  local_mocked_bindings(.operation_clock = function() 0)
  local_mocked_bindings(req_perform = function(...) stop("unexpected dispatch"),
                        .package = "httr2")
  expect_error(arcgis_request("https://example.invalid/FeatureServer/0",
                              timeout = .operation_timeout(30, 0.0005)),
               "time budget", class = "tampa_timeout_error")
})

test_that("budgeted transport owns retries instead of stacking httr2 retry loops", {
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(.operation_sleep = function(seconds) {
    waits <<- c(waits, seconds)
  })
  local_mocked_bindings(
    req_perform = fixture_req_perform,
    req_perform1 = function(req, ...) {
      attempts <<- attempts + 1L
      httr2::response(status_code = if (attempts == 1L) 503L else 200L,
        url = req$url, headers = list(`Retry-After` = "1"),
        body = charToRaw('{"count":2}'))
    },
    sys_sleep = function(seconds, ...) {
      if (seconds > 0) stop("unexpected inner retry wait")
    },
    .package = "httr2"
  )
  result <- arcgis_request("https://example.invalid/FeatureServer/0",
                           timeout = .operation_timeout(30, 5))
  expect_identical(result$count, 2L)
  expect_identical(attempts, 2L)
  expect_identical(waits, 1)
})

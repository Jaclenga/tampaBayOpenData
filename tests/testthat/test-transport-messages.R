test_that("HTTP failures explain the status and a suitable next step", {
  previous <- options(tampaBayOpenData.max_retries = 0L)
  on.exit(options(previous), add = TRUE)
  cases <- list(
    list(status = 429L, problem = "limiting requests", next_step = "Wait and try again"),
    list(status = 503L, problem = "could not complete", next_step = "Try again later"),
    list(status = 403L, problem = "require permission", next_step = "access rules"),
    list(status = 404L, problem = "was not found", next_step = "source page"),
    list(status = 400L, problem = "rejected the request", next_step = "field names and filters"),
    list(status = 302L, problem = "redirected the request", next_step = "source page"),
    list(status = 206L, problem = "partial response", next_step = "stopped")
  )
  for (case in cases) {
    local_mocked_bindings(arcgis_http = function(...) {
      list(status = case$status, body = "{}", attempts = 1L)
    })
    error <- tryCatch(arcgis_request("https://example.invalid/FeatureServer/0"),
                      error = identity)
    expect_s3_class(error, "tampa_http_error")
    expect_match(conditionMessage(error), paste0("returned HTTP ", case$status), fixed = TRUE)
    expect_match(conditionMessage(error), case$problem, fixed = TRUE)
    expect_match(conditionMessage(error), case$next_step, fixed = TRUE)
  }
  expect_false(grepl("NA-second", .arcgis_http_failure(503L, 4L, NA_real_),
                     fixed = TRUE))
  expect_match(.arcgis_http_failure(429L, 1L, 5),
               "5-second Retry-After", fixed = TRUE)
})

test_that("transport timeouts and connection failures remain distinct and redact secrets", {
  previous <- options(tampaBayOpenData.max_retries = 0L)
  on.exit(options(previous), add = TRUE)
  attempts <- 0L
  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    failure <- simpleError(paste0(
      "Operation timed out at https://example.invalid/FeatureServer/0?token=hidden-token ",
      "api_key=hidden-key"))
    failure$code <- 28L
    class(failure) <- c("curl_error", class(failure))
    stop(failure)
  }, .package = "httr2")
  error <- tryCatch(arcgis_request("https://example.invalid/FeatureServer/0"),
                    error = identity)
  expect_s3_class(error, "tampa_http_error")
  expect_match(conditionMessage(error), "timed out", fixed = TRUE)
  expect_match(conditionMessage(error), "increase `timeout`", fixed = TRUE)
  expect_false(grepl("hidden-token|hidden-key", conditionMessage(error)))
  expect_identical(attempts, 1L)

  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    failure <- simpleError("synthetic connection reset")
    failure$code <- 7L
    class(failure) <- c("curl_error", class(failure))
    stop(failure)
  }, .package = "httr2")
  error <- tryCatch(arcgis_request("https://example.invalid/FeatureServer/0"),
                    error = identity)
  expect_s3_class(error, "tampa_http_error")
  expect_match(conditionMessage(error), "connection to the data publisher failed", fixed = TRUE)
  expect_match(conditionMessage(error), "check your connection", fixed = TRUE)
  expect_identical(attempts, 2L)
})

test_that("ArcGIS error bodies keep diagnostic codes without echoing secret URLs", {
  local_mocked_bindings(arcgis_http = function(...) {
    fixture_response(list(error = list(
      code = 400L,
      message = "Invalid SQL at https://example.invalid/query?token=hidden-token",
      details = list("Unknown field", "api_key=hidden-key"))))
  })
  error <- tryCatch(arcgis_request("https://example.invalid/FeatureServer/0/query"),
                    error = identity)
  expect_s3_class(error, "tampa_arcgis_error")
  expect_match(conditionMessage(error), "ArcGIS error 400: Invalid SQL", fixed = TRUE)
  expect_match(conditionMessage(error), "Unknown field", fixed = TRUE)
  expect_match(conditionMessage(error), "Check the field names", fixed = TRUE)
  expect_false(grepl("hidden-token|hidden-key", conditionMessage(error)))
})

test_that("invalid field and order choices point to exact source names", {
  metadata <- fixture_metadata()
  fields_error <- tryCatch(.selected_fields("made_up", metadata), error = identity)
  expect_s3_class(fields_error, "tampa_data_error")
  expect_match(conditionMessage(fields_error), "Unknown source field", fixed = TRUE)
  expect_match(conditionMessage(fields_error), "made_up", fixed = TRUE)
  expect_match(conditionMessage(fields_error), "tbod_dataset_info", fixed = TRUE)

  order_error <- tryCatch(.ordering("made_up DESC", metadata), error = identity)
  expect_s3_class(order_error, "tampa_data_error")
  expect_match(conditionMessage(order_error), "made_up DESC", fixed = TRUE)
  expect_match(conditionMessage(order_error), "ASC or DESC", fixed = TRUE)

  metadata$advancedQueryCapabilities$supportsOrderBy <- FALSE
  unsupported <- tryCatch(.ordering(metadata$objectIdField, metadata), error = identity)
  expect_s3_class(unsupported, "tampa_data_error")
  expect_match(conditionMessage(unsupported), "ordering with pagination", fixed = TRUE)
  expect_match(conditionMessage(unsupported), "Omit `order_by`", fixed = TRUE)
})

test_that("protected query parameters identify the name and the public arguments", {
  error <- tryCatch(.query_params(list(token = "hidden-token")), error = identity)
  expect_s3_class(error, "tampa_input_error")
  expect_match(conditionMessage(error), "protected `query` parameter", fixed = TRUE)
  expect_match(conditionMessage(error), "token", fixed = TRUE)
  expect_match(conditionMessage(error), "`fields`", fixed = TRUE)
  expect_false(grepl("hidden-token", conditionMessage(error), fixed = TRUE))
})

test_that("remote diagnostic details omit bearer tokens and tolerate empty text", {
  expect_identical(.arcgis_safe_detail("Authorization: Bearer hidden-token"),
                   "Authorization=[redacted]")
  expect_identical(.arcgis_safe_detail("Authorization: Basic hidden-password"),
                   "Authorization=[redacted]")
  expect_identical(.arcgis_safe_detail(NULL), "[detail unavailable]")
  expect_identical(.arcgis_safe_detail(NA_character_), "[detail unavailable]")
  expect_identical(.arcgis_safe_detail(""), "[detail unavailable]")
})

test_that("user-facing HTTP errors omit credentials in endpoint URLs", {
  local_mocked_bindings(arcgis_http = function(...) {
    list(status = 403L, body = "{}", attempts = 1L)
  })
  error <- tryCatch(arcgis_request(
    "https://reader:hidden-password@example.invalid/FeatureServer/0?token=hidden-token"),
    error = identity)
  expect_s3_class(error, "tampa_http_error")
  expect_match(conditionMessage(error), "HTTP 403", fixed = TRUE)
  expect_false(grepl("hidden-password|hidden-token", conditionMessage(error)))
  expect_false(grepl("hidden-password|hidden-token", error$url))
})

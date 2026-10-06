test_that("invalid transport statuses fail with source context before body parsing", {
  entry <- tbod_dataset_info("construction-permits")
  url <- paste0(entry$service_url, "/", entry$layer_id)
  for (status in list(NULL, NA_real_, NaN, Inf, "200", TRUE, c(200, 201))) {
    local_mocked_bindings(arcgis_http = function(...) {
      list(status = status, body = '{"name":"ignored"}')
    }, .package = "tampaBayOpenData")
    error <- tryCatch(arcgis_request(url, dataset = entry), error = identity)
    expect_s3_class(error, "tampa_response_error")
    expect_identical(error$dataset_id, entry$id)
    expect_identical(error$url, url)
    expect_match(conditionMessage(error), "invalid response status")
    expect_match(conditionMessage(error), entry$source_url, fixed = TRUE)
  }
})

test_that("a rate limit is retried, while nontransient statuses fail immediately", {
  attempts <- 0L
  waits <- numeric()
  local_mocked_bindings(
    req_perform = fixture_req_perform,
    req_perform1 = function(req, ...) {
      attempts <<- attempts + 1L
      status <- if (attempts == 1L) 429L else 200L
      httr2::response(status_code = status, url = req$url,
                      headers = list(`Retry-After` = "0"),
                      body = charToRaw('{"count":2}'))
    },
    sys_sleep = function(seconds, ...) waits <<- c(waits, seconds),
    .package = "httr2"
  )
  result <- arcgis_request("https://example.invalid/FeatureServer/0")
  expect_identical(result$count, 2L)
  expect_identical(attempts, 2L)
  expect_true(length(waits) >= 1L)
  expect_true(all(is.finite(waits) & waits >= 0 & waits <= 30))

  for (status in c(400L, 404L, 501L)) {
    attempts <- 0L
    local_mocked_bindings(req_perform1 = function(req, ...) {
      attempts <<- attempts + 1L
      httr2::response(status_code = status, url = req$url,
                      body = charToRaw('{"error":"synthetic"}'))
    }, .package = "httr2")
    expect_error(arcgis_request("https://example.invalid/FeatureServer/0"),
                 paste0("HTTP ", status), class = "tampa_http_error")
    expect_identical(attempts, 1L)
  }
})

test_that("generic ArcGIS query failures retry without hiding specific errors", {
  url <- "https://example.invalid/FeatureServer/0/query"
  intermittent <- fixture_response(list(error = list(
    code = 400L, message = "Unable to complete operation.", details = list())))
  attempts <- 0L
  waits <- integer()
  local_mocked_bindings(
    arcgis_http = function(...) {
      attempts <<- attempts + 1L
      if (attempts <= 2L) intermittent else fixture_response(list(count = 2L))
    },
    .arcgis_retry_pause = function(attempt) waits <<- c(waits, attempt),
    .package = "tampaBayOpenData"
  )
  expect_identical(arcgis_request(url)$count, 2L)
  expect_identical(attempts, 3L)
  expect_identical(waits, 1:2)

  attempts <- 0L
  local_mocked_bindings(arcgis_http = function(...) {
    attempts <<- attempts + 1L
    intermittent
  }, .package = "tampaBayOpenData")
  expect_error(arcgis_request(url), "Unable to complete operation",
               class = "tampa_arcgis_error")
  expect_identical(attempts, 4L)

  attempts <- 0L
  local_mocked_bindings(arcgis_http = function(...) {
    attempts <<- attempts + 1L
    fixture_response(list(error = list(code = 400L,
      message = "Invalid field", details = list("Unknown column"))))
  }, .package = "tampaBayOpenData")
  expect_error(arcgis_request(url), "Invalid field", class = "tampa_arcgis_error")
  expect_identical(attempts, 1L)
})

test_that("object-ID manifests require JSON arrays, including for zero matches", {
  cases <- list(
    list(features = fixture_features(), change = function(payload) {
      names(payload$objectIds) <- paste0("id", seq_along(payload$objectIds))
      payload
    }),
    list(features = fixture_features(1L), change = function(payload) {
      payload$objectIds <- 1L
      payload
    }),
    list(features = list(), change = function(payload) {
      payload["objectIds"] <- list(NULL)
      payload
    })
  )
  for (case in cases) {
    transport <- fixture_transport(features = case$features,
      transform = function(payload, params, ...) {
        if (identical(params$returnIdsOnly, "true")) payload <- case$change(payload)
        payload
      })
    local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
    error <- tryCatch(tbod_get_dataset("construction-permits"), error = identity)
    expect_s3_class(error, "tampa_integrity_error")
    expect_match(conditionMessage(error), "malformed or duplicate object IDs")
    expect_length(fixture_queries(transport, "features"), 0L)
  }

  empty <- fixture_transport(features = list())
  local_mocked_bindings(arcgis_http = empty$http, .package = "tampaBayOpenData")
  result <- tbod_get_dataset("construction-permits", fields = "OBJECTID")
  expect_identical(result$OBJECTID, integer())
  expect_true(tbod_provenance(result)$complete)
  expect_length(fixture_queries(empty, "features"), 0L)
})

test_that("sparse object IDs cross the 32 bit boundary without rounding or omission", {
  features <- fixture_features(1:4)
  ids <- c(2147483649, -3, 2147483648, 0)
  for (i in seq_along(features)) features[[i]]$attributes$OBJECTID <- ids[[i]]
  transport <- fixture_transport(features = features)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  result <- tbod_get_dataset("construction-permits", fields = c("OBJECTID", "RECORD_ID"),
                        page_size = 2)
  expect_identical(result$OBJECTID, sort(ids))
  expect_identical(result$RECORD_ID, c("synthetic-2", "synthetic-4",
                                       "synthetic-3", "synthetic-1"))
  batches <- vapply(fixture_queries(transport, "features"),
                    function(x) x$params$objectIds, character(1))
  expect_identical(batches, c("-3,0", "2147483648,2147483649"))
  expect_true(tbod_provenance(result)$complete)
})

test_that("page and limit boundaries preserve exact counts in both retrieval modes", {
  for (order_by in list(NULL, "OBJECTID DESC")) {
    for (limit in c(0, 1, 3, 4, 5, 6, Inf)) {
      transport <- fixture_transport()
      local_mocked_bindings(arcgis_http = transport$http,
                            .package = "tampaBayOpenData")
      result <- tbod_get_dataset("construction-permits", order_by = order_by,
                            page_size = 3, limit = limit)
      target <- min(limit, 5)
      expected <- if (is.null(order_by)) seq_len(target) else (5:1)[seq_len(target)]
      expect_identical(result$OBJECTID, expected)
      provenance <- tbod_provenance(result)
      expect_equal(provenance$matched_rows, 5)
      expect_equal(provenance$returned_rows, target)
      expect_identical(provenance$complete, target == 5)
      expect_length(fixture_queries(transport, "features"), ceiling(target / 2))
    }
  }
})

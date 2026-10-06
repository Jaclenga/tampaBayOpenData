# These tests replace only req_perform(). The package builds a real httr2
# request and consumes a real httr2 response; no sockets or retry waits run.
http_fixture_response <- function(req, body, status = 200L) {
  httr2::response(
    status_code = status, url = req$url,
    method = getFromNamespace("req_method_get", "httr2")(req),
    headers = list(`Content-Type` = "application/json; charset=utf-8"),
    body = charToRaw(enc2utf8(body))
  )
}

http_capture <- function(body = '{"name":"Synthetic layer"}', status = 200L,
                         .env = parent.frame()) {
  requests <- list()
  local_mocked_bindings(
    req_perform = function(req, ...) {
      requests[[length(requests) + 1L]] <<- req
      http_fixture_response(req, body, status)
    },
    .package = "httr2", .env = .env
  )
  function() requests
}

http_form_params <- function(req) {
  lapply(req$body$data, function(value) {
    decoded <- utils::URLdecode(value)
    # URLdecode leaves the encoding unmarked; form text is UTF-8 on the wire.
    Encoding(decoded) <- "UTF-8"
    decoded
  })
}

test_that("metadata uses a GET with one protected JSON format parameter", {
  capture <- http_capture()
  url <- "https://example.invalid/FeatureServer/0"
  result <- arcgis_request(url, params = list(f = "pjson", token = "a+b & 50%"))

  expect_identical(result$name, "Synthetic layer")
  requests <- capture()
  expect_length(requests, 1L)
  req <- requests[[1L]]
  expect_identical(getFromNamespace("req_method_get", "httr2")(req), "GET")
  expect_null(req$body)
  parsed <- httr2::url_parse(req$url)
  expect_identical(parsed$path, "/FeatureServer/0")
  expect_identical(parsed$query$f, "json")
  expect_identical(parsed$query$token, "a+b & 50%")
  expect_identical(names(parsed$query), c("f", "token"))
})

test_that("query POST forms preserve quoted SQL, Unicode, and spatial precision", {
  capture <- http_capture('{"count":1}')
  where <- "NAME = 'D''Angelo & Jos\u00e9 + 50%' AND COST > 0"
  geometry <- list(xmin = -82.4584321987654, ymin = 27.9516987654321,
                   xmax = -82.4500123456789, ymax = 27.9600987654321,
                   spatialReference = list(wkid = 4326))
  params <- c(list(where = where, f = "html"),
              .query_params(list(geometry = geometry,
                                 geometryType = "esriGeometryEnvelope", inSR = 4326)))
  url <- "https://example.invalid/FeatureServer/0/query"
  result <- arcgis_request(url, params, timeout = 12)

  expect_identical(result$count, 1L)
  req <- capture()[[1L]]
  expect_identical(req$url, url)
  expect_identical(getFromNamespace("req_method_get", "httr2")(req), "POST")
  expect_identical(req$body$type, "form")
  expect_null(httr2::url_parse(req$url)$query)
  decoded <- http_form_params(req)
  expect_identical(decoded$where, enc2utf8(where))
  expect_identical(decoded$f, "json")
  expect_identical(decoded$geometryType, "esriGeometryEnvelope")
  expect_identical(decoded$inSR, "4326")
  # A zero tolerance detects default JSON rounding at four decimal places.
  expect_equal(jsonlite::fromJSON(decoded$geometry), geometry, tolerance = 0)
})

test_that("prepared POST bytes retain accented characters in SQL filters", {
  capture <- http_capture('{"count":1}')
  where <- "NAME = 'Jos\u00e9 & D''Angelo + 50%'"
  arcgis_request("https://example.invalid/FeatureServer/0/query", list(where = where))
  req <- getFromNamespace("req_body_apply", "httr2")(capture()[[1L]])
  body <- rawToChar(req$options$postfields)

  expect_match(body, "Jos%C3%A9", fixed = TRUE)
  params <- httr2::url_parse(paste0("https://example.invalid/?", body))$query
  Encoding(params$where) <- "UTF-8"
  expect_identical(params$where, enc2utf8(where))
  expect_identical(params$f, "json")
})

test_that("requests carry the package headers, caller timeout, and bounded retry policy", {
  capture <- http_capture()
  arcgis_http("https://example.invalid/FeatureServer/0", list(f = "json"), 17.5)
  req <- capture()[[1L]]

  expect_identical(req$headers$Accept, "application/json")
  expect_identical(req$options$useragent, "tampaBayOpenData/0.1.0")
  expect_equal(req$options$timeout_ms, 17500)
  expect_equal(req$policies$retry_max_tries, 3)
  expect_true(req$policies$retry_on_failure)
  # HTTP statuses must reach arcgis_request() so its source-aware errors run.
  for (status in c(404L, 429L, 503L)) {
    response <- http_fixture_response(req, '{"error":"synthetic"}', status)
    expect_false(req$policies$error_is_error(response))
  }
  expect_length(capture(), 1L)
})

test_that("a user agent option applies to metadata and query requests", {
  previous <- options(tampaBayOpenData.user_agent =
                        "regional-research/2.0 (contact: data@example.org)")
  on.exit(options(previous), add = TRUE)
  capture <- http_capture()
  arcgis_request("https://example.invalid/FeatureServer/0")
  arcgis_request("https://example.invalid/FeatureServer/0/query")

  requests <- capture()
  expect_length(requests, 2L)
  expect_identical(vapply(requests, function(req) req$options$useragent, character(1)),
                   rep("regional-research/2.0 (contact: data@example.org)", 2L))
})

test_that("invalid user agent options fail before HTTP", {
  previous <- options(tampaBayOpenData.user_agent = NULL)
  on.exit(options(previous), add = TRUE)
  capture <- http_capture()
  for (agent in list("", NA_character_, c("one", "two"), 1, "one\r\ntwo")) {
    options(tampaBayOpenData.user_agent = agent)
    expect_error(arcgis_request("https://example.invalid/FeatureServer/0"),
                 "tampaBayOpenData.user_agent", class = "tampa_input_error")
  }
  expect_length(capture(), 0L)
})

test_that("the HTTP boundary preserves status codes and UTF-8 response bodies", {
  body <- '{"name":"Jos\u00e9 Park","note":"synthetic"}'
  for (status in c(202L, 206L, 429L, 503L)) {
    capture <- http_capture(body, status)
    result <- arcgis_http("https://example.invalid/FeatureServer/0",
                          list(f = "json"), 30)
    expect_identical(result$status, status)
    expect_identical(result$body, enc2utf8(body))
    expect_length(capture(), 1L)
  }
})

test_that("incomplete successful HTTP statuses are rejected before JSON parsing", {
  entry <- tbod_dataset_info("construction-permits")
  url <- paste0(entry$service_url, "/", entry$layer_id)
  for (status in c(202L, 206L)) {
    capture <- http_capture('{"name":"looks complete"}', status)
    error <- tryCatch(arcgis_request(url, dataset = entry), error = identity)

    expect_s3_class(error, "tampa_http_error")
    expect_identical(error$dataset_id, entry$id)
    expect_identical(error$url, url)
    expect_match(conditionMessage(error), paste0("HTTP ", status), fixed = TRUE)
    expect_length(capture(), 1L)
  }
})

test_that("HTTP response errors retain dataset and endpoint context after transport", {
  capture <- http_capture('{"error":"maintenance"}', 503L)
  entry <- tbod_dataset_info("construction-permits")
  url <- paste0(entry$service_url, "/", entry$layer_id)
  error <- tryCatch(arcgis_request(url, dataset = entry), error = identity)

  expect_s3_class(error, "tampa_http_error")
  expect_identical(error$dataset_id, entry$id)
  expect_identical(error$url, url)
  expect_match(conditionMessage(error), "HTTP 503", fixed = TRUE)
  expect_match(conditionMessage(error), entry$publisher, fixed = TRUE)
  expect_match(conditionMessage(error), entry$source_url, fixed = TRUE)
  expect_length(capture(), 1L)
})

test_that("transport failures are wrapped with their cause and source context", {
  requests <- list()
  local_mocked_bindings(req_perform = function(req, ...) {
    requests[[length(requests) + 1L]] <<- req
    stop("synthetic connection reset", call. = FALSE)
  }, .package = "httr2")
  entry <- tbod_dataset_info("construction-permits")
  url <- paste0(entry$service_url, "/", entry$layer_id, "/query")
  error <- tryCatch(arcgis_request(url, list(where = "1=1"), entry, timeout = 9),
                    error = identity)

  expect_s3_class(error, "tampa_http_error")
  expect_identical(error$dataset_id, entry$id)
  expect_identical(error$url, url)
  expect_match(conditionMessage(error), "could not be reached.*synthetic connection reset")
  expect_match(conditionMessage(error), entry$source_url, fixed = TRUE)
  expect_length(requests, 1L)
  expect_equal(requests[[1L]]$policies$retry_max_tries, 3)
  expect_equal(requests[[1L]]$options$timeout_ms, 9000)
})

test_that("dataset retrieval traverses real HTTP request construction for every stage", {
  transport <- fixture_transport()
  requests <- list()
  local_mocked_bindings(req_perform = function(req, ...) {
    requests[[length(requests) + 1L]] <<- req
    parsed <- httr2::url_parse(req$url)
    params <- if (is.null(req$body)) parsed$query else http_form_params(req)
    url <- sub("\\?.*$", "", req$url)
    response <- transport$http(url, params, req$options$timeout_ms / 1000)
    http_fixture_response(req, response$body, response$status)
  }, .package = "httr2")
  where <- "RECORD_ID = 'synthetic & Jos\u00e9 + 50%'"
  result <- tbod_get_dataset("construction-permits", where = where,
                        page_size = 2, timeout = 11)

  expect_identical(result$OBJECTID, 1:5)
  expect_length(requests, 6L)
  methods <- vapply(requests, getFromNamespace("req_method_get", "httr2"), character(1))
  expect_identical(methods, c("GET", rep("POST", 5L)))
  queries <- fixture_queries(transport)
  expect_length(queries, 5L)
  expect_identical(queries[[1L]]$params$returnCountOnly, "true")
  expect_identical(queries[[2L]]$params$returnIdsOnly, "true")
  expect_true(all(vapply(queries, function(x) identical(x$params$where, enc2utf8(where)),
                        logical(1))))
  expect_true(all(vapply(transport$state$requests, function(x) identical(x$params$f, "json"),
                        logical(1))))
  expect_true(all(vapply(transport$state$requests, function(x) identical(x$timeout, 11),
                        logical(1))))
  expect_true(tbod_provenance(result)$complete)
})

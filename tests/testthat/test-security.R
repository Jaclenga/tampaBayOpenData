test_that("remote WKT cannot name a local CRS file", {
  skip_if_not_installed("sf")
  path <- tempfile(fileext = ".prj")
  on.exit(unlink(path))
  writeLines(sf::st_crs(4326)$wkt, path)
  expect_error(arcgis_spatial_crs(list(wkt = path)),
               "inline coordinate-system definition", class = "tampa_spatial_error")
})

test_that("CRS locators are rejected before the native resolver is called", {
  calls <- 0L
  local_mocked_bindings(.resolve_arcgis_crs = function(...) {
    calls <<- calls + 1L
    stop("The native CRS resolver must not receive a locator.")
  })
  locators <- c("https://example.invalid/crs", "http://127.0.0.1/crs",
                "file:///etc/proj/epsg", "/etc/proj/epsg", "../crs.prj",
                "C:/private/crs.prj", "\\\\server\\share\\crs.prj",
                "/vsicurl/https://example.invalid/crs", "EPSG:4326",
                "+proj=longlat +datum=WGS84", "ESRI::GEOGCS[anything]",
                "<SpatialReference>anything</SpatialReference>")
  for (locator in locators) {
    expect_error(arcgis_spatial_crs(list(wkt = locator, wkid = 4326L)),
                 "inline coordinate-system definition", class = "tampa_spatial_error")
  }
  expect_identical(calls, 0L)
})

test_that("inline WKT1 and WKT2 remain usable", {
  skip_if_not_installed("sf")
  legacy <- paste0('GEOGCS["WGS 84",DATUM["WGS_1984",',
                   'SPHEROID["WGS 84",6378137,298.257223563]],',
                   'PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433],',
                   'AUTHORITY["EPSG","4326"]]')
  wgs84 <- sf::st_crs(4326)
  for (wkt in c(legacy, wgs84$wkt, paste0(" \n\t", wgs84$wkt, "\n"))) {
    expect_true(isTRUE(arcgis_spatial_crs(list(wkt = wkt)) == wgs84))
  }
  expect_error(arcgis_spatial_crs(list(wkt = "GEOGCRS[not-a-definition]")),
               "could not be resolved", class = "tampa_spatial_error")
})

test_that("public spatial retrieval gives source context for a malicious WKT locator", {
  skip_if_not_installed("sf")
  transport <- fixture_transport(transform = function(payload, params, url, ...) {
    if (!is.null(payload$features)) {
      payload$spatialReference <- list(wkt = "https://example.invalid/crs")
    }
    payload
  })
  local_mocked_bindings(arcgis_http = transport$http)
  error <- tryCatch(tbod_get_dataset("construction-permits", spatial = TRUE), error = identity)
  expect_s3_class(error, "tampa_spatial_error")
  expect_identical(error$dataset_id, "construction-permits")
  expect_match(conditionMessage(error), "inline coordinate-system definition")
  expect_match(conditionMessage(error), tbod_dataset_info("construction-permits")$source_url,
               fixed = TRUE)
})

test_that("deep JSON is rejected with context before recursive validation exhausts R", {
  entry <- tbod_dataset_info("construction-permits")
  url <- paste0(entry$service_url, "/", entry$layer_id)
  for (depth in c(64L, 3000L)) {
    body <- paste0('{"ignored":', strrep("[", depth), "0", strrep("]", depth), "}")
    local_mocked_bindings(arcgis_http = function(...) list(status = 200L, body = body))
    error <- tryCatch(arcgis_request(url, dataset = entry), error = identity)
    expect_s3_class(error, "tampa_response_error")
    expect_match(conditionMessage(error), "64-level nesting limit")
    expect_identical(error$dataset_id, entry$id)
    expect_identical(error$url, url)
    expect_match(conditionMessage(error), entry$source_url, fixed = TRUE)
  }
  body <- paste0('{"ignored":', strrep("[", 63L), "0", strrep("]", 63L), "}")
  local_mocked_bindings(arcgis_http = function(...) list(status = 200L, body = body))
  expect_type(arcgis_request(url, dataset = entry), "list")
})

test_that("HTTP redirects fail without authorizing a second destination", {
  requests <- list()
  local_mocked_bindings(req_perform1 = function(req, ...) {
    requests[[length(requests) + 1L]] <<- req
    httr2::response(status_code = 302L, url = req$url,
                   headers = list(Location = "http://127.0.0.1/internal"),
                   body = charToRaw("{}"))
  }, .package = "httr2")
  # Override the ordinary test dispatch guard; actual sockets remain mocked.
  local_mocked_bindings(req_perform = fixture_req_perform,
                        .package = "httr2")
  entry <- tbod_dataset_info("construction-permits")
  url <- paste0(entry$service_url, "/", entry$layer_id)
  error <- tryCatch(arcgis_request(url, dataset = entry), error = identity)
  expect_s3_class(error, "tampa_http_error")
  expect_match(conditionMessage(error), "HTTP 302", fixed = TRUE)
  expect_identical(error$dataset_id, entry$id)
  expect_length(requests, 1L)
  expect_identical(requests[[1L]]$options$followlocation, FALSE)
})

test_that("server retry headers cannot request an unbounded sleep", {
  headers <- c("0", "5", "86400", "1e100", "-5", "invalid", "Inf", "-Inf", "NaN")
  expected <- c(0, 5, 30, 30, 0, NA_real_, NA_real_, NA_real_, NA_real_)
  for (i in seq_along(headers)) {
    response <- httr2::response(status_code = 503L,
                                headers = list(`Retry-After` = headers[[i]]))
    expect_identical(.bounded_retry_after(response), expected[[i]])
  }
  expect_identical(.bounded_retry_after(httr2::response(status_code = 503L)), NA_real_)
  for (date in c("Wed, 30 Sep 2026 08:00:00 GMT", "Mon, 28 Sep 2026 08:00:00 GMT")) {
    response <- httr2::response(status_code = 503L,
                                headers = list(Date = "Tue, 29 Sep 2026 08:00:00 GMT",
                                               `Retry-After` = date))
    expect_identical(.bounded_retry_after(response), if (startsWith(date, "Wed")) 30 else 0)
  }
})

test_that("the actual retry loop limits a one-day header without real sleeps", {
  waits <- numeric()
  attempts <- 0L
  # Restore real retry orchestration while replacing its network and sleep sinks.
  real_perform <- fixture_req_perform
  local_mocked_bindings(req_perform = real_perform,
                        req_perform1 = function(req, ...) {
                          attempts <<- attempts + 1L
                          httr2::response(status_code = 503L, url = req$url,
                                          headers = list(`Retry-After` = "86400"),
                                          body = charToRaw("{}"))
                        }, sys_sleep = function(seconds, ...) {
                          waits <<- c(waits, seconds)
                        }, .package = "httr2")
  response <- arcgis_http("https://example.invalid/FeatureServer/0", list(f = "json"), 1)
  expect_identical(response$status, 503L)
  expect_identical(attempts, 3L)
  expect_true(length(waits) > 0L)
  expect_true(all(is.finite(waits) & waits >= 0 & waits <= 30))
  expect_equal(sum(waits), 60)
})

test_that("oversized responses fail before JSON parsing with source context", {
  # Lower the internal ceiling to exercise rejection without allocating 50 MiB.
  local_mocked_bindings(.arcgis_response_limit = 12L)
  entry <- tbod_dataset_info("construction-permits")
  url <- paste0(entry$service_url, "/", entry$layer_id)
  body <- strrep("x", 13L)
  local_mocked_bindings(arcgis_http = function(...) list(status = 200L, body = body))
  error <- tryCatch(arcgis_request(url, dataset = entry), error = identity)
  expect_s3_class(error, "tampa_response_error")
  expect_match(conditionMessage(error), "response-size limit", fixed = TRUE)
  expect_identical(error$dataset_id, entry$id)
  expect_identical(error$url, url)
  body <- '{"value":12}'
  expect_identical(arcgis_request(url, dataset = entry)$value, 12L)
})

test_that("real requests configure the transport response ceiling", {
  requests <- list()
  local_mocked_bindings(req_perform = function(req, ...) {
    requests[[length(requests) + 1L]] <<- req
    httr2::response(status_code = 200L, url = req$url, body = charToRaw("{}"))
  }, .package = "httr2")
  arcgis_http("https://example.invalid/FeatureServer/0", list(f = "json"), 1)
  expect_identical(requests[[1L]]$options$maxfilesize_large, 50 * 1024^2)
})

test_that("HTTP response text cannot select an alternate JSON source", {
  path <- tempfile(fileext = ".json")
  on.exit(unlink(path))
  writeLines('{"name":"benign local data"}', path)
  entry <- tbod_dataset_info("construction-permits")
  url <- paste0(entry$service_url, "/", entry$layer_id)
  for (body in c(path, "https://example.invalid/json", "http://127.0.0.1/json")) {
    local_mocked_bindings(arcgis_http = function(...) list(status = 200L, body = body))
    error <- tryCatch(arcgis_request(url, dataset = entry), error = identity)
    expect_s3_class(error, "tampa_response_error")
    expect_match(conditionMessage(error), "malformed JSON", fixed = TRUE)
    expect_identical(error$dataset_id, entry$id)
    expect_identical(error$url, url)
  }
})

test_that("literal JSON may contain URL and filename values without following them", {
  body <- '{"url":"https://example.invalid/json","path":"/etc/private.json","note":"Jos\\u00e9"}'
  local_mocked_bindings(arcgis_http = function(...) list(status = 200L, body = body))
  result <- arcgis_request("https://example.invalid/FeatureServer/0")
  expect_identical(result$url, "https://example.invalid/json")
  expect_identical(result$path, "/etc/private.json")
  expect_identical(result$note, "Jos\u00e9")
})

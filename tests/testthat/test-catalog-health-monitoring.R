monitoring_case <- function() {
  entry <- .lookup_dataset("construction-permits")
  list(entry = entry,
       endpoint = paste0(entry$service_url, "/", entry$layer_id),
       metadata = source_schema_fixtures()[[entry$id]]$metadata)
}

test_that("the default catalog check remains metadata-only", {
  case <- monitoring_case()
  urls <- character()
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    urls <<- c(urls, url)
    fixture_response(case$metadata)
  })

  report <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(urls, case$endpoint)
  expect_identical(report$status, "healthy")
  expect_identical(report$health_state, "healthy")
  expect_identical(report$query_status, "not_checked")
  expect_true(is.na(report$query_http_status))
  expect_true(is.numeric(report$response_time_ms))
  expect_true(is.finite(report$response_time_ms))
  expect_gte(report$response_time_ms, 0)
  expect_s3_class(report$checked_at, "POSIXct")
  expect_identical(attr(report$checked_at, "tzone"), "UTC")
})

test_that("a zero-match count verifies query capability without fetching features", {
  case <- monitoring_case()
  requests <- list()
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    requests[[length(requests) + 1L]] <<- list(url = url, params = params,
                                               timeout = timeout)
    if (identical(url, case$endpoint)) return(fixture_response(case$metadata))
    if (identical(url, paste0(case$endpoint, "/query"))) {
      return(fixture_response(list(count = 0L)))
    }
    stop("unexpected ArcGIS request", call. = FALSE)
  })

  report <- tbod_check_catalog(ids = case$entry$id, pause = 0,
                               probe_query = TRUE)
  expect_identical(vapply(requests, `[[`, character(1), "url"),
                   c(case$endpoint, paste0(case$endpoint, "/query")))
  expect_identical(requests[[2L]]$params$where, "1=0")
  expect_identical(requests[[2L]]$params$returnCountOnly, "true")
  expect_identical(requests[[2L]]$params$returnGeometry, "false")
  expect_identical(report$query_status, "verified")
  expect_identical(report$query_http_status, 200L)
  expect_identical(report$status, "healthy")
  expect_identical(report$health_state, "healthy")
  expect_true(is.na(report$query_failure_type))
  expect_true(is.numeric(report$response_time_ms))
  expect_true(is.finite(report$response_time_ms))
  expect_gte(report$response_time_ms, 0)
})

test_that("query count errors distinguish confirmed failures from transient faults", {
  case <- monitoring_case()
  previous <- options(tampaBayOpenData.max_retries = 0L)
  on.exit(options(previous), add = TRUE)
  cases <- list(
    list(response = fixture_response(list(count = "zero")),
         query_status = "failed", health_state = "degraded", http_status = 200L,
         failure_type = "malformed_response"),
    list(response = fixture_response(list(count = 1L)),
         query_status = "failed", health_state = "degraded", http_status = 200L,
         failure_type = "malformed_response"),
    list(response = list(status = 200L, body = "not JSON"),
         query_status = "failed", health_state = "degraded", http_status = 200L,
         failure_type = "malformed_response"),
    list(response = list(status = 99L, body = "{}"),
         query_status = "failed", health_state = "degraded", http_status = NA_integer_,
         failure_type = "malformed_response"),
    list(response = list(status = 403L, body = ""),
         query_status = "failed", health_state = "degraded", http_status = 403L,
         failure_type = "access_denied"),
    list(response = list(status = 302L, body = ""),
         query_status = "failed", health_state = "degraded", http_status = 302L,
         failure_type = "unexpected_http"),
    list(response = list(status = 503L, body = ""),
         query_status = "unknown", health_state = "unknown", http_status = 503L,
         failure_type = "transient_http")
  )
  for (scenario in cases) {
    urls <- character()
    local_mocked_bindings(arcgis_http = function(url, params, timeout) {
      urls <<- c(urls, url)
      if (identical(url, case$endpoint)) return(fixture_response(case$metadata))
      if (identical(url, paste0(case$endpoint, "/query"))) {
        return(scenario$response)
      }
      stop("unexpected ArcGIS request", call. = FALSE)
    })
    report <- tbod_check_catalog(ids = case$entry$id, pause = 0,
                                 probe_query = TRUE)
    expect_identical(urls,
                     c(case$endpoint, paste0(case$endpoint, "/query")))
    expect_identical(report$query_status, scenario$query_status)
    expect_identical(report$health_state, scenario$health_state)
    expect_identical(report$query_http_status, scenario$http_status)
    expect_identical(report$query_failure_type, scenario$failure_type)
    expect_true(is.character(report$query_failure_type) &&
                  !is.na(report$query_failure_type) &&
                  nzchar(report$query_failure_type))
    expect_true(is.character(report$query_details) &&
                  nzchar(report$query_details))
  }
})

test_that("an unexpected metadata HTTP response is reported as degraded", {
  case <- monitoring_case()
  urls <- character()
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    urls <<- c(urls, url)
    list(status = 302L, body = "")
  })

  report <- tbod_check_catalog(ids = case$entry$id, pause = 0,
                               probe_query = TRUE)
  expect_identical(urls, case$endpoint)
  expect_identical(report$status, "unsupported")
  expect_identical(report$health_state, "degraded")
  expect_identical(report$failure_type, "unexpected_http")
  expect_identical(report$http_status, 302L)
  expect_identical(report$query_status, "not_checked")
})

test_that("an ArcGIS query error and timeout are diagnosed without hiding metadata", {
  case <- monitoring_case()
  previous <- options(tampaBayOpenData.max_retries = 0L)
  on.exit(options(previous), add = TRUE)
  for (fault in c("arcgis", "timeout")) {
    local_mocked_bindings(arcgis_http = function(url, params, timeout) {
      if (identical(url, case$endpoint)) return(fixture_response(case$metadata))
      if (identical(fault, "arcgis")) {
        return(fixture_response(list(error = list(code = 403L,
          message = "Query denied", details = list()))))
      }
      .abort("synthetic timeout", subclass = "tampa_timeout_error")
    })
    report <- tbod_check_catalog(ids = case$entry$id, pause = 0,
                                 probe_query = TRUE)
    expect_identical(report$schema_status, "unchanged")
    expect_identical(report$service_status, "available")
    expect_identical(report$layer_status, "available")
    if (identical(fault, "arcgis")) {
      expect_identical(report$query_status, "failed")
      expect_identical(report$health_state, "degraded")
      expect_identical(report$query_http_status, 200L)
      expect_match(report$query_details, "403")
    } else {
      expect_identical(report$query_status, "unknown")
      expect_identical(report$health_state, "unknown")
      expect_true(is.na(report$query_http_status))
      expect_match(report$query_details, "timeout")
    }
  }
})

test_that("metadata drift stays degraded after a successful query probe", {
  case <- monitoring_case()
  changed <- case$metadata
  changed$fields <- c(changed$fields,
                      list(fixture_field("NEW_FIELD", "esriFieldTypeString")))
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    if (identical(url, case$endpoint)) return(fixture_response(changed))
    fixture_response(list(count = 0L))
  })

  report <- tbod_check_catalog(ids = case$entry$id, pause = 0,
                               probe_query = TRUE)
  expect_identical(report$status, "schema_changed")
  expect_identical(report$health_state, "degraded")
  expect_identical(report$query_status, "verified")
  expect_identical(report$schema_status, "compatible")
})

test_that("a transient query fault does not erase confirmed schema drift", {
  case <- monitoring_case()
  changed <- case$metadata
  changed$fields <- c(changed$fields,
                      list(fixture_field("NEW_FIELD", "esriFieldTypeString")))
  previous <- options(tampaBayOpenData.max_retries = 0L)
  on.exit(options(previous), add = TRUE)
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    if (identical(url, case$endpoint)) return(fixture_response(changed))
    expect_identical(url, paste0(case$endpoint, "/query"))
    list(status = 503L, body = "")
  })

  report <- tbod_check_catalog(ids = case$entry$id, pause = 0,
                               probe_query = TRUE)
  expect_identical(report$status, "schema_changed")
  expect_identical(report$failure_type, "schema_drift")
  expect_identical(report$health_state, "degraded")
  expect_identical(report$schema_status, "compatible")
  expect_identical(report$query_status, "unknown")
  expect_identical(report$query_failure_type, "transient_http")
  expect_identical(report$query_http_status, 503L)
})

test_that("missing layers and malformed metadata do not trigger a query probe", {
  case <- monitoring_case()
  previous <- options(tampaBayOpenData.max_retries = 0L)
  on.exit(options(previous), add = TRUE)
  scenarios <- list(
    list(layer = list(status = 404L, body = ""),
         root = fixture_response(list(currentVersion = 11.0,
           layers = list(list(id = 1L, name = "Other")), tables = list())),
         health_state = "unavailable"),
    list(layer = list(status = 200L, body = "not JSON"),
         root = NULL, health_state = "unknown")
  )
  for (scenario in scenarios) {
    urls <- character()
    local_mocked_bindings(arcgis_http = function(url, params, timeout) {
      urls <<- c(urls, url)
      if (identical(url, case$endpoint)) return(scenario$layer)
      if (identical(url, case$entry$service_url)) return(scenario$root)
      stop("query should not run after unusable metadata", call. = FALSE)
    })
    report <- tbod_check_catalog(ids = case$entry$id, pause = 0,
                                 probe_query = TRUE)
    expect_identical(report$health_state, scenario$health_state)
    expect_identical(report$query_status, "not_checked")
    expect_false(any(grepl("/query$", urls)))
  }
})

test_that("all 52 checked entries can be monitored offline without changing the catalog", {
  entries <- .read_registry()
  expect_length(entries, 52L)
  snapshots <- source_schema_fixtures()
  endpoints <- vapply(entries, function(entry) {
    paste0(entry$service_url, "/", entry$layer_id)
  }, character(1))
  catalog_file <- system.file("extdata", "datasets.json",
                              package = "tampaBayOpenData")
  expect_true(nzchar(catalog_file))
  before <- unname(tools::md5sum(catalog_file))
  requests <- character()
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    requests <<- c(requests, url)
    if (grepl("/query$", url)) {
      expect_identical(params$where, "1=0")
      return(fixture_response(list(count = 0L)))
    }
    index <- match(url, endpoints)
    if (is.na(index)) stop("unexpected ArcGIS request", call. = FALSE)
    fixture_response(snapshots[[entries[[index]]$id]]$metadata)
  })

  report <- tbod_check_catalog(pause = 0, probe_query = TRUE)
  expect_equal(nrow(report), 52L)
  expect_setequal(report$endpoint, endpoints)
  expect_true(all(report$query_status == "verified"))
  expect_true(all(report$health_state == "healthy"))
  expect_length(requests, 104L)
  expect_identical(unname(tools::md5sum(catalog_file)), before)

  local_mocked_bindings(arcgis_http = function(...) {
    list(status = 503L, body = "")
  })
  previous <- options(tampaBayOpenData.max_retries = 0L)
  on.exit(options(previous), add = TRUE)
  failed <- tbod_check_catalog(ids = entries[[1L]]$id, pause = 0,
                               probe_query = TRUE)
  expect_identical(failed$health_state, "unknown")
  expect_identical(unname(tools::md5sum(catalog_file)), before)
})

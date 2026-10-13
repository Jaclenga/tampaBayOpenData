catalog_health_fixture <- function() {
  entry <- .lookup_dataset("construction-permits")
  list(entry = entry,
       endpoint = paste0(entry$service_url, "/", entry$layer_id),
       metadata = source_schema_fixtures()[[entry$id]]$metadata)
}

test_that("catalog health reports a checked layer with matching live metadata", {
  case <- catalog_health_fixture()
  requests <- list()
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    requests[[length(requests) + 1L]] <<- list(url = url, timeout = timeout)
    expect_identical(url, case$endpoint)
    fixture_response(case$metadata)
  })

  report <- tbod_check_catalog(ids = case$entry$id, pause = 0,
                               timeout = 3, total_timeout = 30)
  expect_s3_class(report, "tbl_df")
  expect_equal(nrow(report), 1L)
  expect_identical(report$dataset_id, case$entry$id)
  expect_identical(report$endpoint, case$endpoint)
  expect_identical(report$publisher, case$entry$publisher)
  expect_identical(report$jurisdiction, case$entry$jurisdiction)
  expect_identical(report$status, "healthy")
  expect_identical(report$schema_status, "unchanged")
  expect_s3_class(report$checked_at, "POSIXct")
  expect_identical(attr(report$checked_at, "tzone"), "UTC")
  expect_length(report$schema_issues[[1L]]$category, 0L)
  expect_length(requests, 1L)
  expect_lte(as.numeric(requests[[1L]]$timeout), 3)
})

test_that("catalog health keeps transient HTTP and timeout failures as unknown", {
  case <- catalog_health_fixture()
  for (status in c(429L, 503L)) {
    local_mocked_bindings(arcgis_http = function(url, params, timeout) {
      fixture_response(list(error = "maintenance"), status)
    })
    server <- tbod_check_catalog(ids = case$entry$id, pause = 0)
    expect_identical(server$status, "unknown")
    expect_identical(server$http_status, status)
    expect_match(server$details, as.character(status), fixed = TRUE)
    expect_identical(server$endpoint, case$endpoint)
  }

  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    stop("synthetic connection timed out", call. = FALSE)
  })
  timeout <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(timeout$status, "unknown")
  expect_true(is.na(timeout$http_status))
  expect_match(timeout$details, "timed out", fixed = TRUE)
})

test_that("catalog health succeeds after a bounded HTTP retry", {
  case <- catalog_health_fixture()
  previous <- options(tampaBayOpenData.max_retries = 1L)
  on.exit(options(previous), add = TRUE)
  attempts <- 0L
  waits <- numeric()
  urls <- character()
  local_mocked_bindings(.operation_sleep = function(seconds) {
    waits <<- c(waits, seconds)
  })
  local_mocked_bindings(req_perform = function(req, ...) {
    attempts <<- attempts + 1L
    urls <<- c(urls, req$url)
    httr2::response(
      status_code = if (attempts == 1L) 503L else 200L,
      url = req$url, headers = list(`Retry-After` = "0"),
      body = charToRaw(if (attempts == 1L) "{}" else
        fixture_response(case$metadata)$body))
  }, .package = "httr2")

  report <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(report$status, "healthy")
  expect_identical(attempts, 2L)
  expect_length(waits, 1L)
  expect_true(all(startsWith(urls, case$endpoint)))
})

test_that("catalog health distinguishes a missing layer from a missing service", {
  case <- catalog_health_fixture()
  requests <- character()
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    requests <<- c(requests, url)
    if (identical(url, case$endpoint)) return(list(status = 404L, body = ""))
    if (identical(url, case$entry$service_url)) {
      return(fixture_response(list(currentVersion = 11.0,
                                   layers = list(list(id = 1L, name = "Other")),
                                   tables = list())))
    }
    stop("unexpected endpoint")
  })

  report <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(report$status, "unavailable")
  expect_identical(report$http_status, 404L)
  expect_identical(report$schema_status, "unavailable")
  expect_identical(requests, c(case$endpoint, case$entry$service_url))
})

test_that("ArcGIS error bodies identify a missing layer after a root probe", {
  case <- catalog_health_fixture()
  requests <- character()
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    requests <<- c(requests, url)
    if (identical(url, case$endpoint)) {
      return(fixture_response(list(error = list(
        code = 404L, message = "Layer not found", details = list()))))
    }
    fixture_response(list(currentVersion = 11.0,
                          layers = list(list(id = 1L, name = "Other")),
                          tables = list()))
  })

  report <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(report$status, "unavailable")
  expect_identical(report$failure_type, "layer_missing")
  expect_identical(report$http_status, 200L)
  expect_identical(requests, c(case$endpoint, case$entry$service_url))
})

test_that("a server error mentioning a missing layer stays transient", {
  case <- catalog_health_fixture()
  previous <- options(tampaBayOpenData.max_retries = 0L)
  on.exit(options(previous), add = TRUE)
  requests <- character()
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    requests <<- c(requests, url)
    fixture_response(list(error = list(code = 500L,
      message = "Layer not found", details = list())))
  })

  report <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(report$status, "unknown")
  expect_identical(report$failure_type, "transient_arcgis")
  expect_identical(requests, case$endpoint)
})

test_that("service-root evidence controls a layer disappearance claim", {
  case <- catalog_health_fixture()
  root_responses <- list(
    list(response = list(status = 404L, body = ""),
         status = "unavailable", failure = "service_missing"),
    list(response = list(status = 503L, body = ""),
         status = "unknown", failure = "layer_missing_service_unverified"),
    list(response = fixture_response(list(layers = list(), tables = list())),
         status = "unknown", failure = "inconsistent_service_metadata"),
    list(response = fixture_response(list(currentVersion = 11.0,
           layers = list(list(id = case$entry$layer_id, name = "Still listed")),
           tables = list())),
         status = "unknown", failure = "inconsistent_service_response")
  )
  for (root in root_responses) {
    calls <- character()
    local_mocked_bindings(arcgis_http = function(url, params, timeout) {
      calls <<- c(calls, url)
      if (identical(url, case$endpoint)) return(list(status = 404L, body = ""))
      root$response
    })
    report <- tbod_check_catalog(ids = case$entry$id, pause = 0)
    expect_identical(report$status, root$status)
    expect_identical(report$failure_type, root$failure)
    expect_identical(calls, c(case$endpoint, case$entry$service_url))
  }
})

test_that("catalog health reports compatible and incompatible schema changes", {
  case <- catalog_health_fixture()
  added <- case$metadata
  added$fields <- c(added$fields,
                    list(fixture_field("NEW_FIELD", "esriFieldTypeString")))
  local_mocked_bindings(arcgis_http = function(...) fixture_response(added))
  compatible <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(compatible$status, "schema_changed")
  expect_identical(compatible$schema_status, "compatible")
  expect_true("added_field" %in% compatible$schema_issues[[1L]]$category)

  removed <- case$metadata
  removed$fields <- Filter(function(field) field$name != "PROJECTSTATUS",
                           removed$fields)
  local_mocked_bindings(arcgis_http = function(...) fixture_response(removed))
  incompatible <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(incompatible$status, "schema_changed")
  expect_identical(incompatible$schema_status, "incompatible")
  expect_true("removed_field" %in% incompatible$schema_issues[[1L]]$category)
})

test_that("a removed object-ID field is visible as drift and unusable for retrieval", {
  case <- catalog_health_fixture()
  metadata <- case$metadata
  metadata$fields <- Filter(function(field) field$name != case$entry$object_id_field,
                            metadata$fields)
  local_mocked_bindings(arcgis_http = function(...) fixture_response(metadata))

  report <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(report$status, "schema_changed")
  expect_identical(report$schema_status, "incompatible")
  expect_true("removed_field" %in% report$schema_issues[[1L]]$category)
  expect_match(report$details, "record retrieval is unsupported", fixed = TRUE)

  untracked <- case$entry
  untracked$expected_schema <- NULL
  report <- .check_catalog_entries(list(untracked), timeout = 3, pause = 0)
  expect_identical(report$status, "unsupported")
  expect_identical(report$failure_type, "object_id_unavailable")
  expect_identical(report$schema_status, "unavailable")
})

test_that("confirmed schema drift remains visible when capabilities are unreported", {
  case <- catalog_health_fixture()
  metadata <- case$metadata
  metadata$capabilities <- NULL
  local_mocked_bindings(arcgis_http = function(...) fixture_response(metadata))

  unchanged <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(unchanged$status, "unknown")
  expect_identical(unchanged$failure_type, "capabilities_unreported")

  metadata$fields <- c(metadata$fields,
                       list(fixture_field("NEW_FIELD", "esriFieldTypeString")))
  changed <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(changed$status, "schema_changed")
  expect_identical(changed$schema_status, "compatible")
  expect_true("added_field" %in% changed$schema_issues[[1L]]$category)
  expect_match(changed$details, "Query capability is unreported", fixed = TRUE)
})

test_that("catalog health exposes malformed and unsupported layer responses", {
  case <- catalog_health_fixture()
  malformed <- case$metadata
  malformed$fields <- list(list(name = "BROKEN"))
  local_mocked_bindings(arcgis_http = function(...) fixture_response(malformed))
  bad <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(bad$status, "unknown")
  expect_match(bad$details, "field schema", fixed = TRUE)

  unsupported <- case$metadata
  unsupported$capabilities <- "Map"
  local_mocked_bindings(arcgis_http = function(...) fixture_response(unsupported))
  no_query <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(no_query$status, "unsupported")
  expect_match(no_query$details, "query support", fixed = TRUE)

  geometry <- case$metadata
  geometry$geometryType <- "invalidGeometry"
  local_mocked_bindings(arcgis_http = function(...) fixture_response(geometry))
  bad_geometry <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(bad_geometry$status, "unknown")
  expect_identical(bad_geometry$failure_type, "malformed_metadata")
  expect_identical(bad_geometry$http_status, 200L)
})

test_that("permanent access and operation failures are not called transient", {
  case <- catalog_health_fixture()
  for (status in c(400L, 403L, 405L)) {
    local_mocked_bindings(arcgis_http = function(...) {
      list(status = status, body = "")
    })
    report <- tbod_check_catalog(ids = case$entry$id, pause = 0)
    expect_identical(report$status, "unsupported")
    expect_identical(report$http_status, status)
    expect_match(report$details, "This status is not retried", fixed = TRUE)
  }
})

test_that("catalog health checks only selected checked IDs", {
  entries <- .read_registry()
  ids <- c("construction-permits", "capital-projects")
  selected <- Filter(function(entry) entry$id %in% ids, entries)
  snapshots <- source_schema_fixtures()
  calls <- character()
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    calls <<- c(calls, url)
    index <- match(url, vapply(selected, function(entry) {
      paste0(entry$service_url, "/", entry$layer_id)
    }, character(1)))
    if (is.na(index)) stop("unexpected catalog request")
    fixture_response(snapshots[[selected[[index]]$id]]$metadata)
  })

  report <- tbod_check_catalog(ids = ids, pause = 0)
  expect_equal(nrow(report), 2L)
  expect_setequal(report$dataset_id, ids)
  expect_true(all(report$status == "healthy"))
  expect_length(calls, 2L)
})

test_that("the full checked catalog can be verified from saved metadata fixtures", {
  entries <- .read_registry()
  snapshots <- source_schema_fixtures()
  endpoints <- vapply(entries, function(entry) {
    paste0(entry$service_url, "/", entry$layer_id)
  }, character(1))
  requests <- character()
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    requests <<- c(requests, url)
    index <- match(url, endpoints)
    if (is.na(index)) stop("unexpected service-root or network request")
    fixture_response(snapshots[[entries[[index]]$id]]$metadata)
  })

  report <- tbod_check_catalog(pause = 0)
  expect_equal(nrow(report), length(entries))
  expect_setequal(report$endpoint, endpoints)
  expect_true(all(report$status == "healthy"))
  expect_length(requests, length(entries))
})

test_that("unreached and untracked entries remain unknown", {
  case <- catalog_health_fixture()
  local_mocked_bindings(.operation_clock = function() 10,
                        arcgis_http = function(...) stop("unexpected network"))
  timeout <- 5
  attr(timeout, "tampa_deadline") <- 9
  unreached <- .check_catalog_entries(list(case$entry), timeout, pause = 0)
  expect_identical(unreached$status, "unknown")
  expect_identical(unreached$failure_type, "budget_exhausted")
  expect_identical(unreached$schema_status, "unavailable")

  no_baseline <- case$entry
  no_baseline$expected_schema <- NULL
  local_mocked_bindings(arcgis_http = function(...) fixture_response(case$metadata))
  current <- .check_catalog_entries(list(no_baseline), 10, pause = 0)
  expect_identical(current$status, "unknown")
  expect_identical(current$failure_type, "baseline_unavailable")
  expect_identical(current$schema_status, "unavailable")
})

test_that("the public catalog can check an entry without a schema baseline", {
  case <- catalog_health_fixture()
  schemas <- .read_expected_schemas()
  schemas[[paste(case$entry$jurisdiction, case$entry$id, sep = "/")]] <- NULL
  local_mocked_bindings(
    .read_expected_schemas = function() schemas,
    arcgis_http = function(...) fixture_response(case$metadata),
    .package = "tampaBayOpenData")

  catalog <- tbod_list_datasets(source = "checked")
  row <- catalog[catalog$id == case$entry$id, , drop = FALSE]
  expect_null(row$original_metadata[[1L]]$expected_schema)
  expect_identical(.coverage_dashboard_data(catalog)$summary$missing_baselines, 1L)
  report <- tbod_check_catalog(ids = case$entry$id, pause = 0)
  expect_identical(report$status, "unknown")
  expect_identical(report$failure_type, "baseline_unavailable")
  expect_identical(report$schema_status, "unavailable")
})

test_that("catalog selection and pacing options validate before HTTP", {
  calls <- 0L
  local_mocked_bindings(arcgis_http = function(...) {
    calls <<- calls + 1L
    stop("unexpected network")
  })
  for (ids in list(character(), c("construction-permits", "construction-permits"),
                   NA_character_, "no-such-checked-layer")) {
    expect_error(tbod_check_catalog(ids = ids, pause = 0),
                 class = "tampa_input_error")
  }
  expect_error(tbod_check_catalog(ids = "construction-permits", pause = -1),
               class = "tampa_input_error")
  expect_error(tbod_check_catalog(ids = "construction-permits", pause = 31),
               class = "tampa_input_error")
  expect_identical(calls, 0L)
})

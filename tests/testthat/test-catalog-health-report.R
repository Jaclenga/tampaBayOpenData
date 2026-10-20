catalog_report_tools <- function() {
  paths <- c(file.path("tools", "catalog-health-report.R"),
             file.path("..", "..", "tools", "catalog-health-report.R"))
  found <- paths[file.exists(paths)]
  if (!length(found)) {
    testthat::skip("The report-only tools are unavailable in this test environment")
  }
  environment <- new.env(parent = baseenv())
  sys.source(found[[1L]], envir = environment)
  environment
}

catalog_report_fixture <- function() {
  checked <- data.frame(
    publisher = c("City A", "City B"),
    jurisdiction = c("a", "b"),
    id = c("permits", "water"),
    service_url = c("https://example.org/a/FeatureServer",
                    "https://example.org/b/FeatureServer"),
    layer_id = c(0L, 2L), stringsAsFactors = FALSE
  )
  report <- data.frame(
    publisher = checked$publisher,
    jurisdiction = checked$jurisdiction,
    dataset_id = checked$id,
    endpoint = paste0(checked$service_url, "/", checked$layer_id),
    checked_at = as.POSIXct(c("2026-10-20 12:00:01", "2026-10-20 12:00:02"),
                           tz = "UTC"),
    status = c("healthy", "schema_changed"),
    failure_type = c(NA_character_, "schema_drift"),
    http_status = c(200L, 200L),
    service_status = c("available", "available"),
    layer_status = c("available", "available"),
    schema_status = c("unchanged", "incompatible"),
    details = c("Metadata and count valid", "Schema | drift\nfound"),
    health_state = c("healthy", "degraded"),
    response_time_ms = c(12.25, 32.5),
    query_status = c("verified", "verified"),
    query_failure_type = c(NA_character_, NA_character_),
    query_http_status = c(200L, 200L),
    query_details = c("", ""), stringsAsFactors = FALSE
  )
  report$schema_issues <- list(
    data.frame(),
    data.frame(category = "removed_field", field = "OBJECTID",
               severity = "incompatible", stringsAsFactors = FALSE)
  )
  list(checked = checked, report = report)
}

test_that("report runner checks every jurisdiction and requests count probes", {
  tools <- catalog_report_tools()
  fixture <- catalog_report_fixture()
  calls <- character()
  fake_check <- function(jurisdiction, probe_query, timeout, total_timeout, pause) {
    expect_true(probe_query)
    expect_identical(timeout, 10)
    expect_identical(total_timeout, 600)
    expect_identical(pause, 0.5)
    calls <<- c(calls, jurisdiction)
    fixture$report[fixture$report$jurisdiction == jurisdiction, , drop = FALSE]
  }
  result <- tools$catalog_health_run(fixture$checked, fake_check, workers = 1L)
  expect_identical(calls, c("a", "b"))
  expect_identical(result$dataset_id, fixture$checked$id)
  expect_silent(tools$catalog_health_validate(result, fixture$checked))
})

test_that("report validator rejects gaps, duplicates, and endpoint substitution", {
  tools <- catalog_report_tools()
  fixture <- catalog_report_fixture()
  expect_silent(tools$catalog_health_validate(fixture$report, fixture$checked))
  expect_error(tools$catalog_health_validate(fixture$report[1L, ], fixture$checked),
               "omitted or duplicated")
  duplicate <- rbind(fixture$report, fixture$report[1L, ])
  expect_error(tools$catalog_health_validate(duplicate, fixture$checked),
               "omitted or duplicated")
  wrong <- fixture$report
  wrong$endpoint[[2L]] <- "https://example.org/wrong/FeatureServer/2"
  expect_error(tools$catalog_health_validate(wrong, fixture$checked),
               "endpoints or publishers")
  wrong <- fixture$report
  wrong$health_state[[2L]] <- "unknown"
  expect_error(tools$catalog_health_validate(wrong, fixture$checked),
               "does not agree")
  wrong <- fixture$report
  wrong$query_status[[1L]] <- "not_checked"
  expect_error(tools$catalog_health_validate(wrong, fixture$checked),
               "Query probe results")
  transient_after_drift <- fixture$report
  transient_after_drift$query_status[[2L]] <- "unknown"
  transient_after_drift$query_failure_type[[2L]] <- "transient_http"
  transient_after_drift$query_http_status[[2L]] <- 503L
  expect_silent(tools$catalog_health_validate(transient_after_drift,
                                               fixture$checked))
})

test_that("report validator covers every bundled checked catalog entry", {
  tools <- catalog_report_tools()
  paths <- c(file.path("inst", "extdata", "datasets.json"),
             file.path("..", "..", "inst", "extdata", "datasets.json"))
  found <- paths[file.exists(paths)]
  if (!length(found)) testthat::skip("Bundled catalog unavailable in this test environment")
  registry <- jsonlite::fromJSON(found[[1L]], simplifyVector = FALSE)
  checked <- data.frame(
    publisher = vapply(registry, `[[`, character(1), "publisher"),
    jurisdiction = vapply(registry, `[[`, character(1), "jurisdiction"),
    id = vapply(registry, `[[`, character(1), "id"),
    service_url = vapply(registry, `[[`, character(1), "service_url"),
    layer_id = vapply(registry, `[[`, integer(1), "layer_id"),
    stringsAsFactors = FALSE
  )
  report <- catalog_report_fixture()$report[
    rep(1L, nrow(checked)), , drop = FALSE]
  report$publisher <- checked$publisher
  report$jurisdiction <- checked$jurisdiction
  report$dataset_id <- checked$id
  report$endpoint <- paste0(checked$service_url, "/", checked$layer_id)
  rownames(report) <- NULL
  expect_gte(nrow(checked), 52L)
  expect_silent(tools$catalog_health_validate(report, checked))
  expect_error(tools$catalog_health_validate(report[-nrow(report), ], checked),
               "omitted or duplicated")
})

test_that("JSON, CSV, RDS, and Markdown preserve health diagnostics", {
  tools <- catalog_report_tools()
  fixture <- catalog_report_fixture()
  prefix <- tempfile("catalog-health-report-")
  paths <- paste0(prefix, c(".rds", ".csv", ".json", "-summary.md"))
  on.exit(unlink(paths), add = TRUE)
  stamp <- as.POSIXct("2026-10-20 12:00:00", tz = "UTC")
  lines <- tools$catalog_health_write(fixture$report, prefix, stamp)
  expect_true(all(file.exists(paths)))
  expect_identical(readRDS(paths[[1L]])$schema_issues,
                   fixture$report$schema_issues)
  csv <- utils::read.csv(paths[[2L]], stringsAsFactors = FALSE)
  expect_equal(csv$response_time_ms, fixture$report$response_time_ms)
  expect_identical(csv$health_state, fixture$report$health_state)
  json <- jsonlite::fromJSON(paths[[3L]], simplifyVector = FALSE)
  expect_identical(json$schema_version, 1L)
  expect_identical(json$checked_entries, 2L)
  expect_identical(length(json$entries), 2L)
  expect_identical(json$entries[[1L]]$query_status, "verified")
  expect_equal(json$entries[[2L]]$response_time_ms, 32.5)
  expect_identical(json$entries[[2L]]$schema_issues[[1L]]$category,
                   "removed_field")
  expect_identical(json$health_counts$degraded, 1L)
  expect_identical(lines, readLines(paths[[4L]], warn = FALSE))
  expect_true(any(grepl("| degraded | 1 |", lines, fixed = TRUE)))
  expect_true(any(grepl("schema_drift", lines, fixed = TRUE)))
  expect_true(any(grepl("32.5", lines, fixed = TRUE)))
  expect_true(any(grepl("&#124;", lines, fixed = TRUE)))
  expect_true(any(grepl("2026-10-20 12:00:02", lines, fixed = TRUE)))
})

test_that("Markdown makes unreached entries and missing HTTP responses explicit", {
  tools <- catalog_report_tools()
  report <- catalog_report_fixture()$report
  report$status[[2L]] <- "unknown"
  report$health_state[[2L]] <- "unknown"
  report$failure_type[[2L]] <- "timeout"
  report$http_status[[2L]] <- NA_integer_
  report$query_status[[2L]] <- "not_checked"
  report$query_http_status[[2L]] <- NA_integer_
  report$response_time_ms[[2L]] <- NA_real_
  report$details[[2L]] <- "Operation budget expired before a response"
  lines <- tools$catalog_health_markdown(report)
  expect_true(any(grepl("| unknown | 1 |", lines, fixed = TRUE)))
  expect_true(any(grepl("| unknown | - | not_checked | - | - | timeout |",
                        lines, fixed = TRUE)))
})

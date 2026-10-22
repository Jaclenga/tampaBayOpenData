dashboard_catalog_fixture <- function(per_publisher = 3L, publishers = 2L) {
  checked <- tbod_list_datasets(source = "checked")
  selected <- unique(checked$publisher)[seq_len(publishers)]
  positions <- unlist(lapply(selected, function(publisher) {
    head(which(checked$publisher == publisher), per_publisher)
  }), use.names = FALSE)
  catalog <- checked[positions, , drop = FALSE]
  catalog$verified <- as.Date(rep("2026-09-01", nrow(catalog)))
  for (i in seq_len(nrow(catalog))) {
    catalog$original_metadata[[i]]$verified <- "2026-09-01"
  }
  catalog
}

dashboard_health_fixture <- function(catalog, i, status, checked_at,
                                     details = status) {
  row <- .catalog_health_row(catalog$original_metadata[[i]],
                             status = status, details = details)
  row$checked_at <- as.POSIXct(checked_at, tz = "UTC")
  row
}

test_that("coverage dashboard counts recent health and publisher status", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"))
  catalog <- dashboard_catalog_fixture()
  now <- as.POSIXct("2026-10-12 12:00:00", tz = "UTC")
  recent <- "2026-10-10 12:00:00"
  health <- do.call(rbind, list(
    dashboard_health_fixture(catalog, 1L, "healthy", recent),
    dashboard_health_fixture(catalog, 2L, "schema_changed", recent,
                             "A field was added."),
    dashboard_health_fixture(catalog, 3L, "unsupported", recent,
                             "Query is unavailable."),
    dashboard_health_fixture(catalog, 4L, "unavailable", recent,
                             "Layer is missing."),
    dashboard_health_fixture(catalog, 5L, "unknown", recent,
                             "Request timed out."),
    dashboard_health_fixture(catalog, 6L, "healthy",
                             "2026-09-10 12:00:00", "Old health result.")
  ))

  result <- .coverage_dashboard_data(catalog, health, recent_days = 30,
                                     now = now)
  expect_named(result, c("summary", "publishers", "datasets"))
  expect_equal(result$summary$checked_entries, 6L)
  expect_equal(result$summary$publishers, 2L)
  expect_equal(result$summary$recent_healthy, 1L)
  expect_equal(result$summary$problems, 3L)
  expect_equal(result$summary$unverified, 2L)
  expect_identical(result$summary$health_available, TRUE)
  expect_equal(result$summary$latest_health_check,
               as.POSIXct(recent, tz = "UTC"))
  expect_identical(result$summary$latest_catalog_verified,
                   as.Date("2026-09-01"))

  expect_s3_class(result$publishers, "tbl_df")
  expect_s3_class(result$datasets, "tbl_df")
  expect_setequal(result$datasets$dataset_id, catalog$id)
  rows <- match(catalog$id, result$datasets$dataset_id)
  expect_identical(result$datasets$verification_status[rows],
                   c("healthy", "problematic", "problematic", "problematic",
                     "unverified", "unverified"))
  expect_identical(result$datasets$verification_source[rows],
                   rep("health_report", 6L))
  expect_true(all(result$datasets$baseline_available))
  expect_true(all(vapply(seq_len(6L), function(i) {
    grepl(catalog$original_metadata[[i]]$scope_note,
          result$datasets$known_issues[[rows[[i]]]],
          fixed = TRUE)
  }, logical(1))))
  expect_match(result$datasets$known_issues[[rows[[2L]]]],
               "A field was added.", fixed = TRUE)
  expect_match(result$datasets$known_issues[[rows[[5L]]]],
               "Request timed out.", fixed = TRUE)
  expect_match(result$datasets$known_issues[[rows[[6L]]]],
               "older than the 30-day window", fixed = TRUE)
  expect_false(grepl("Old health result.",
                     result$datasets$known_issues[[rows[[6L]]]], fixed = TRUE))

  publishers <- match(unique(catalog$publisher), result$publishers$publisher)
  expect_equal(result$publishers$checked_entries[publishers], c(3L, 3L))
  expect_equal(result$publishers$healthy[publishers], c(1L, 0L))
  expect_equal(result$publishers$problematic[publishers], c(2L, 1L))
  expect_equal(result$publishers$unverified[publishers], c(0L, 2L))
  expect_s3_class(result$publishers$last_verification, "Date")
})

test_that("missing health and schema baselines remain visibly unverified", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"))
  catalog <- dashboard_catalog_fixture(per_publisher = 2L, publishers = 1L)
  catalog$original_metadata[[1L]]$expected_schema <- NULL
  now <- as.POSIXct("2026-10-12 12:00:00", tz = "UTC")

  result <- .coverage_dashboard_data(catalog, health = NULL, now = now)
  expect_identical(result$summary$health_available, FALSE)
  expect_equal(result$summary$checked_entries, 2L)
  expect_equal(result$summary$recent_healthy, 0L)
  expect_equal(result$summary$problems, 0L)
  expect_equal(result$summary$unverified, 2L)
  expect_equal(result$summary$missing_baselines, 1L)
  expect_true(is.na(result$summary$latest_health_check))
  expect_true(all(result$datasets$verification_status == "unverified"))
  expect_true(all(is.na(result$datasets$health_status)))
  expect_identical(result$datasets$baseline_available, c(FALSE, TRUE))
  expect_identical(result$datasets$verification_source,
                   rep("catalog_snapshot", 2L))
  expect_identical(result$datasets$last_verification,
                   as.Date(rep("2026-09-01", 2L)))
  expect_match(result$datasets$known_issues[[1L]],
               "No bundled schema baseline is available.", fixed = TRUE)
  expect_equal(result$publishers$unverified, 2L)
})

test_that("mismatched, invalid, and pre-baseline reports cannot verify a layer", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"))
  catalog <- dashboard_catalog_fixture(per_publisher = 4L, publishers = 1L)
  catalog$verified <- as.Date(rep("2026-09-01", nrow(catalog)))
  now <- as.POSIXct("2026-09-02 12:00:00", tz = "UTC")
  wrong_endpoint <- dashboard_health_fixture(catalog, 1L, "healthy",
                                             "2026-09-02 10:00:00")
  wrong_endpoint$endpoint <- paste0(wrong_endpoint$endpoint, "/wrong")
  old_baseline <- dashboard_health_fixture(catalog, 2L, "healthy",
                                           "2026-08-31 12:00:00")
  invalid_time <- dashboard_health_fixture(catalog, 3L, "healthy", NA)
  health <- do.call(rbind, list(wrong_endpoint, old_baseline, invalid_time))

  result <- .coverage_dashboard_data(catalog, health, recent_days = 30,
                                     now = now)
  expect_equal(result$summary$recent_healthy, 0L)
  expect_equal(result$summary$problems, 0L)
  expect_equal(result$summary$unverified, 4L)
  rows <- match(catalog$id, result$datasets$dataset_id)
  expect_identical(result$datasets$verification_status[rows],
                   rep("unverified", 4L))
  expect_identical(result$datasets$health_status[rows],
                   c(NA_character_, "healthy", NA_character_, NA_character_))
  expect_identical(result$datasets$verification_source[rows],
                   c("catalog_snapshot", "catalog_snapshot", "catalog_snapshot",
                     "catalog_snapshot"))
  expect_equal(result$publishers$unverified, 4L)
})

test_that("dashboard ignores unusable and future health rows", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"))
  catalog <- dashboard_catalog_fixture(per_publisher = 1L, publishers = 1L)
  valid <- dashboard_health_fixture(catalog, 1L, "healthy",
                                    "2026-10-10 12:00:00")
  invalid_status <- dashboard_health_fixture(catalog, 1L, "retired",
                                             "2026-10-11 12:00:00")
  missing_id <- dashboard_health_fixture(catalog, 1L, "unavailable",
                                         "2026-10-11 12:00:00")
  missing_id$dataset_id <- NA_character_
  missing_date <- dashboard_health_fixture(catalog, 1L, "unsupported", NA)
  future <- dashboard_health_fixture(catalog, 1L, "schema_changed",
                                     "2026-10-15 12:00:00")
  health <- do.call(rbind, list(valid, invalid_status, missing_id,
                                missing_date, future))

  result <- .coverage_dashboard_data(
    catalog, health, now = as.POSIXct("2026-10-12 12:00:00", tz = "UTC"))
  expect_identical(result$datasets$verification_status, "healthy")
  expect_identical(result$datasets$health_status, "healthy")
  expect_equal(result$datasets$health_checked_at,
               as.POSIXct("2026-10-10 12:00:00", tz = "UTC"))
  expect_equal(result$summary$recent_healthy, 1L)
})

test_that("dashboard uses the newest matching health report for each layer", {
  catalog <- dashboard_catalog_fixture(per_publisher = 1L, publishers = 1L)
  health <- do.call(rbind, list(
    dashboard_health_fixture(catalog, 1L, "healthy",
                             "2026-10-09 12:00:00", "Earlier result."),
    dashboard_health_fixture(catalog, 1L, "schema_changed",
                             "2026-10-10 12:00:00", "First latest result."),
    dashboard_health_fixture(catalog, 1L, "unknown",
                             "2026-10-10 12:00:00", "Second latest result.")
  ))

  result <- .coverage_dashboard_data(
    catalog, health, now = as.POSIXct("2026-10-12 12:00:00", tz = "UTC"))
  expect_identical(result$datasets$health_status, "schema_changed")
  expect_identical(result$datasets$verification_status, "problematic")
  expect_equal(result$datasets$health_checked_at,
               as.POSIXct("2026-10-10 12:00:00", tz = "UTC"))
  expect_match(result$datasets$known_issues, "First latest result.", fixed = TRUE)
  expect_false(grepl("Second latest result.", result$datasets$known_issues,
                     fixed = TRUE))
})

test_that("coverage dashboard ignores absent and corrupt health artifacts", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"))
  directory <- tempfile("tbod-dashboard-", tmpdir = tempdir())
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  expect_null(.coverage_load_health_report(directory))

  catalog <- dashboard_catalog_fixture(per_publisher = 1L, publishers = 1L)
  valid <- dashboard_health_fixture(catalog, 1L, "healthy",
                                    "2026-10-10 12:00:00")
  saveRDS(valid, file.path(directory, "catalog-health-20261010T120000Z.rds"))
  writeLines("incomplete report", file.path(
    directory, "catalog-health-20261011T120000Z.rds"))
  loaded <- .coverage_load_health_report(directory)
  expect_s3_class(loaded, "tbl_df")
  expect_identical(loaded$dataset_id, valid$dataset_id)
  expect_identical(loaded$checked_at, valid$checked_at)
})

test_that("coverage HTML renders no-report metrics and escapes catalog text", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"))
  catalog <- dashboard_catalog_fixture(per_publisher = 2L, publishers = 1L)
  catalog$title[[1L]] <- 'Synthetic <script> & "quoted" title'
  catalog$original_metadata[[1L]]$scope_note <-
    "Curated <b>issue</b> & 'limit'."
  data <- .coverage_dashboard_data(
    catalog, health = NULL,
    now = as.POSIXct("2026-10-12 12:00:00", tz = "UTC"))
  html <- .coverage_dashboard_html(data)

  expect_equal(nrow(data$datasets), 2L)
  expect_equal(sum(gregexpr('<tr data-publisher=', html,
                           fixed = TRUE)[[1L]] > 0L), 2L)
  expect_equal(sum(gregexpr('class="tb-coverage-metric-value">No report</div>',
                           html, fixed = TRUE)[[1L]] > 0L), 2L)
  expect_match(html, "No matching health report was available", fixed = TRUE)
  expect_match(html,
               'class="tb-coverage-metric-label">Latest verification</div><div class="tb-coverage-metric-value">2026-09-01</div>',
               fixed = TRUE)
  expect_match(html, "Bundled catalog check; time unavailable", fixed = TRUE)
  expect_match(html,
               'Synthetic &lt;script&gt; &amp; &quot;quoted&quot; title',
               fixed = TRUE)
  expect_match(html,
               'Curated &lt;b&gt;issue&lt;/b&gt; &amp; &#39;limit&#39;.',
               fixed = TRUE)
  expect_false(grepl("<script>", html, fixed = TRUE))
})

test_that("coverage HTML displays counts from a matching health report", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"))
  catalog <- dashboard_catalog_fixture(per_publisher = 3L, publishers = 1L)
  checked_at <- "2026-10-10 12:00:00"
  health <- do.call(rbind, list(
    dashboard_health_fixture(catalog, 1L, "healthy", checked_at),
    dashboard_health_fixture(catalog, 2L, "schema_changed", checked_at,
                             "Field type changed."),
    dashboard_health_fixture(catalog, 3L, "unknown", checked_at,
                             "Request timed out.")
  ))
  data <- .coverage_dashboard_data(catalog, health,
                                   now = as.POSIXct("2026-10-12", tz = "UTC"))
  html <- .coverage_dashboard_html(data)

  expect_equal(data$summary$recent_healthy, 1L)
  expect_equal(data$summary$problems, 1L)
  expect_match(html, 'class="tb-coverage-metric-label">Recently healthy</div><div class="tb-coverage-metric-value">1</div>',
               fixed = TRUE)
  expect_match(html, 'class="tb-coverage-metric-label">Detected problems</div><div class="tb-coverage-metric-value">1</div>',
               fixed = TRUE)
  expect_match(html, "2026-10-10 12:00 UTC", fixed = TRUE)
  expect_equal(sum(gregexpr('data-status="healthy"', html,
                           fixed = TRUE)[[1L]] > 0L), 1L)
  expect_equal(sum(gregexpr('data-status="problematic"', html,
                           fixed = TRUE)[[1L]] > 0L), 1L)
  expect_equal(sum(gregexpr('data-status="unverified"', html,
                           fixed = TRUE)[[1L]] > 0L), 1L)
  expect_match(html, "Field type changed.", fixed = TRUE)
  expect_match(html, "Request timed out.", fixed = TRUE)
  for (status in c("healthy", "problematic", "unverified")) {
    option <- paste0('<option value="', status, '">',
                     tools::toTitleCase(status), '</option>')
    expect_match(html, option, fixed = TRUE)
  }
})

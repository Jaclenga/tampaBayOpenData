# These summaries power the static pkgdown coverage article. Catalog rows are
# the sole source of coverage counts; health reports are separate observations.

.coverage_usable_health_rows <- function(health) {
  !is.na(health$checked_at) &
    stats::complete.cases(health[c("publisher", "jurisdiction",
                                   "dataset_id", "endpoint", "status")]) &
    health$status %in% c("healthy", "unavailable", "schema_changed",
                         "unsupported", "unknown")
}

.coverage_health_valid <- function(health) {
  required <- c("publisher", "jurisdiction", "dataset_id", "endpoint",
                "checked_at", "status", "details")
  is.data.frame(health) && nrow(health) > 0L &&
    all(required %in% names(health)) &&
    all(vapply(health[c("publisher", "jurisdiction", "dataset_id",
                        "endpoint", "status", "details")], is.character,
               logical(1))) &&
    inherits(health$checked_at, "POSIXct") &&
    any(.coverage_usable_health_rows(health))
}

.coverage_latest_date <- function(dates) {
  dates <- as.Date(dates)
  if (!length(dates) || all(is.na(dates))) return(as.Date(NA))
  max(dates, na.rm = TRUE)
}

.coverage_latest_health <- function(key, health, now) {
  n <- length(key)
  checked_at <- as.POSIXct(rep(NA_real_, n), origin = "1970-01-01", tz = "UTC")
  status <- rep(NA_character_, n)
  details <- rep("", n)
  if (.coverage_health_valid(health)) {
    valid <- .coverage_usable_health_rows(health) & health$checked_at <= now
    current <- health[valid, , drop = FALSE]
    if (nrow(current)) {
      health_key <- paste(current$jurisdiction, current$dataset_id,
                          current$endpoint, current$publisher, sep = "\r")
      newest <- order(current$checked_at, decreasing = TRUE)
      matched <- match(key, health_key[newest])
      has_match <- !is.na(matched)
      index <- newest[matched[has_match]]
      checked_at[has_match] <- current$checked_at[index]
      status[has_match] <- current$status[index]
      details[has_match] <- current$details[index]
    }
  }
  details[is.na(details)] <- ""
  list(checked_at = checked_at, status = status, details = details)
}

.coverage_dashboard_data <- function(catalog, health = NULL, recent_days = 30,
                                     now = Sys.time()) {
  required <- c("id", "title", "publisher", "jurisdiction", "category",
                "service_url", "layer_id", "verified", "source_url")
  if (!is.data.frame(catalog) || !all(required %in% names(catalog)) ||
      !is.character(catalog$id) || !is.character(catalog$publisher) ||
      !is.character(catalog$jurisdiction) ||
      !inherits(catalog$verified, "Date")) {
    .abort("`catalog` must be a checked catalog table with dated entries.",
           subclass = "tampa_input_error")
  }
  .number(recent_days, "recent_days", min = 1, integer = TRUE)
  if (!inherits(now, "POSIXct") || length(now) != 1L || is.na(now)) {
    .abort("`now` must be one nonmissing POSIXct instant.",
           subclass = "tampa_input_error")
  }
  n <- nrow(catalog)
  endpoint <- paste0(catalog$service_url, "/", catalog$layer_id)
  key <- paste(catalog$jurisdiction, catalog$id, endpoint,
               catalog$publisher, sep = "\r")
  if (anyDuplicated(key)) {
    .abort("The checked catalog has duplicate dataset endpoints.",
           subclass = "tampa_input_error")
  }

  baseline_available <- if ("original_metadata" %in% names(catalog) &&
                            is.list(catalog$original_metadata)) {
    vapply(catalog$original_metadata, function(entry) {
      is.list(entry) && !is.null(entry$expected_schema)
    }, logical(1))
  } else rep(FALSE, n)

  matched_health <- .coverage_latest_health(key, health, now)
  health_at <- matched_health$checked_at
  health_status <- matched_health$status
  health_details <- matched_health$details

  catalog_at <- as.POSIXct(catalog$verified, tz = "UTC")
  recent <- !is.na(health_at) &
    health_at >= now - as.difftime(recent_days, units = "days") &
    (is.na(catalog_at) | health_at >= catalog_at)
  problematic <- c("unavailable", "schema_changed", "unsupported")
  verification_status <- rep("unverified", n)
  verification_status[recent & health_status == "healthy"] <- "healthy"
  verification_status[recent & health_status %in% problematic] <- "problematic"
  last_verification <- catalog$verified
  use_health_date <- !is.na(health_at) &
    (is.na(catalog_at) | health_at >= catalog_at)
  last_verification[use_health_date] <- as.Date(health_at[use_health_date], tz = "UTC")
  verification_source <- ifelse(use_health_date, "health_report",
                                ifelse(!is.na(catalog$verified), "catalog_snapshot",
                                       "unavailable"))
  scope <- if ("scope_note" %in% names(catalog)) {
    as.character(catalog$scope_note)
  } else if ("original_metadata" %in% names(catalog) &&
             is.list(catalog$original_metadata)) {
    vapply(catalog$original_metadata, function(entry) {
      if (is.list(entry) && !is.null(entry$scope_note)) {
        as.character(entry$scope_note)[[1L]]
      } else ""
    }, character(1))
  } else rep("", n)
  scope[is.na(scope)] <- ""
  known_issues <- vapply(seq_len(n), function(i) {
    notes <- character()
    if (nzchar(trimws(scope[[i]]))) notes <- c(notes, trimws(scope[[i]]))
    if (!baseline_available[[i]]) {
      notes <- c(notes, "No bundled schema baseline is available.")
    }
    if (!is.na(health_at[[i]]) && !recent[[i]]) {
      reason <- if (!is.na(catalog_at[[i]]) &&
                    health_at[[i]] < catalog_at[[i]]) {
        "Health result predates the current catalog verification."
      } else paste0("Health result is older than the ", recent_days,
                    "-day window.")
      notes <- c(notes, reason)
    }
    if (recent[[i]] && !identical(health_status[[i]], "healthy") &&
        nzchar(trimws(health_details[[i]]))) {
      notes <- c(notes, trimws(health_details[[i]]))
    }
    paste(notes, collapse = " ")
  }, character(1))

  datasets <- tibble::tibble(
    dataset_id = catalog$id,
    title = catalog$title,
    publisher = catalog$publisher,
    jurisdiction = catalog$jurisdiction,
    category = catalog$category,
    endpoint = endpoint,
    source_url = catalog$source_url,
    last_verification = last_verification,
    verification_source = verification_source,
    verification_status = verification_status,
    health_status = health_status,
    known_issues = known_issues,
    baseline_available = baseline_available,
    catalog_verified = catalog$verified,
    health_checked_at = health_at
  )

  names <- sort(unique(catalog$publisher))
  publishers <- lapply(names, function(name) {
    selected <- datasets$publisher == name
    checked <- datasets[selected, , drop = FALSE]
    last <- .coverage_latest_date(checked$last_verification)
    latest_health <- checked$verification_source == "health_report" &
      checked$last_verification == last
    tibble::tibble(
      publisher = name,
      checked_entries = as.integer(nrow(checked)),
      last_verification = last,
      verification_source = if (any(latest_health, na.rm = TRUE)) "health_report" else
        if (!is.na(last)) "catalog_snapshot" else "unavailable",
      healthy = as.integer(sum(checked$verification_status == "healthy")),
      problematic = as.integer(sum(checked$verification_status == "problematic")),
      unverified = as.integer(sum(checked$verification_status == "unverified"))
    )
  })
  publishers <- if (length(publishers)) do.call(rbind, publishers) else
    tibble::tibble(publisher = character(), checked_entries = integer(),
                   last_verification = as.Date(character()),
                   verification_source = character(), healthy = integer(),
                   problematic = integer(), unverified = integer())
  latest_health <- if (all(is.na(health_at))) {
    as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
  } else max(health_at, na.rm = TRUE)
  list(
    summary = list(
      checked_entries = as.integer(n),
      publishers = as.integer(length(names)),
      recent_healthy = as.integer(sum(verification_status == "healthy")),
      problems = as.integer(sum(verification_status == "problematic")),
      unverified = as.integer(sum(verification_status == "unverified")),
      latest_health_check = latest_health,
      latest_catalog_verified = .coverage_latest_date(catalog$verified),
      health_available = any(!is.na(health_at)),
      missing_baselines = as.integer(sum(!baseline_available)),
      recent_days = as.integer(recent_days)
    ),
    publishers = publishers,
    datasets = datasets
  )
}

# A report is optional during local builds and CRAN checks. Read the newest
# usable RDS from the website workflow's artifact directory, if present.
.coverage_load_health_report <- function(directory = NULL) {
  if (is.null(directory)) {
    configured <- Sys.getenv("TAMPA_OPEN_DATA_HEALTH_REPORT_DIR", unset = "")
    directory <- if (nzchar(configured)) configured else
      c(file.path(".artifacts", "catalog-health"),
        file.path("..", ".artifacts", "catalog-health"))
  }
  directories <- directory[dir.exists(directory)]
  if (!length(directories)) return(NULL)
  files <- unlist(lapply(directories, function(path) {
    list.files(path, pattern = "^catalog-health-[0-9]{8}T[0-9]{6}Z\\.rds$",
               recursive = TRUE, full.names = TRUE)
  }), use.names = FALSE)
  if (!length(files)) return(NULL)
  files <- files[order(basename(files), decreasing = TRUE)]
  for (file in files) {
    health <- tryCatch(readRDS(file), error = function(e) NULL)
    if (.coverage_health_valid(health)) return(health)
  }
  NULL
}

.coverage_escape_html <- function(value) {
  value <- as.character(value)
  value[is.na(value)] <- ""
  value <- gsub("&", "&amp;", value, fixed = TRUE)
  value <- gsub("<", "&lt;", value, fixed = TRUE)
  value <- gsub(">", "&gt;", value, fixed = TRUE)
  value <- gsub('"', "&quot;", value, fixed = TRUE)
  gsub("'", "&#39;", value, fixed = TRUE)
}

.coverage_date_html <- function(date, source = "unavailable") {
  if (length(date) != 1L || is.na(date)) return("Not available")
  stamp <- format(as.Date(date), "%Y-%m-%d")
  source_label <- switch(source,
    health_report = "health report",
    catalog_snapshot = "catalog check",
    "")
  paste0('<time datetime="', stamp, '">', stamp, '</time>',
         if (nzchar(source_label)) paste0('<span class="tb-coverage-source">',
                                          source_label, '</span>') else "")
}

.coverage_dashboard_html <- function(data) {
  summary <- data$summary
  publishers <- data$publishers
  datasets <- data$datasets
  h <- .coverage_escape_html
  has_health <- isTRUE(summary$health_available)
  has_catalog_date <- !is.na(summary$latest_catalog_verified)
  latest_from_health <- has_health &&
    (!has_catalog_date || summary$latest_health_check >=
       as.POSIXct(summary$latest_catalog_verified, tz = "UTC"))
  if (latest_from_health) {
    latest <- format(summary$latest_health_check, "%Y-%m-%d %H:%M UTC",
                     tz = "UTC")
    latest_note <- "Latest matching health report"
  } else if (has_catalog_date) {
    latest <- format(summary$latest_catalog_verified, "%Y-%m-%d")
    latest_note <- "Bundled catalog check; time unavailable"
  } else {
    latest <- "Not available"
    latest_note <- "No dated verification evidence"
  }
  metric <- function(label, value, note) {
    paste0('<div class="tb-coverage-metric"><div class="tb-coverage-metric-label">',
           h(label), '</div><div class="tb-coverage-metric-value">', h(value),
           '</div><div class="tb-coverage-metric-note">', h(note), '</div></div>')
  }
  metrics <- c(
    metric("Checked entries", summary$checked_entries,
           "Selected layers in the bundled catalog"),
    metric("Publishers represented", summary$publishers,
           "Organizations in the checked catalog"),
    metric("Recently healthy", if (has_health) summary$recent_healthy else "No report",
           paste0("Successful checks within ", summary$recent_days, " days")),
    metric("Detected problems", if (has_health) summary$problems else "No report",
           "Recent unavailable, changed, or unsupported layers"),
    metric("Missing schema baselines", summary$missing_baselines,
           "Layers without a saved field and geometry comparison"),
    metric("Latest verification", latest, latest_note))

  publisher_rows <- if (nrow(publishers)) {
    vapply(seq_len(nrow(publishers)), function(i) {
      row <- publishers[i, , drop = FALSE]
      paste0('<tr><th scope="row">', h(row$publisher), '</th><td>',
             row$checked_entries, '</td><td>',
             .coverage_date_html(row$last_verification,
                                 row$verification_source), '</td><td>',
             row$healthy, '</td><td>', row$problematic, '</td><td>',
             row$unverified, '</td></tr>')
    }, character(1))
  } else '<tr><td colspan="6">No checked entries are available.</td></tr>'

  status_label <- c(healthy = "Healthy", problematic = "Problematic",
                    unverified = "Unverified")
  status_options <- paste0('<option value="', names(status_label), '">',
                           unname(status_label), '</option>')
  dataset_rows <- if (nrow(datasets)) {
    vapply(seq_len(nrow(datasets)), function(i) {
      row <- datasets[i, , drop = FALSE]
      status <- row$verification_status[[1L]]
      issue <- row$known_issues[[1L]]
      issue_html <- if (nzchar(trimws(issue))) {
        paste0('<details><summary>Read notes</summary><p>', h(issue),
               '</p></details>')
      } else "None recorded"
      category <- row$category[[1L]]
      if (is.na(category) || !nzchar(trimws(category))) category <- "Not specified"
      endpoint <- row$endpoint[[1L]]
      paste0('<tr data-publisher="', h(row$publisher), '" data-status="',
             h(status), '"><th scope="row">', h(row$title), '</th><td>',
             h(row$publisher), '</td><td>', h(category), '</td><td>',
             '<a href="', h(endpoint), '">', h(endpoint), '</a></td><td>',
             .coverage_date_html(row$last_verification,
                                 row$verification_source), '</td><td>',
             '<span class="tb-coverage-status tb-coverage-status-', h(status),
             '">', h(status_label[[status]]), '</span></td><td>',
             issue_html, '</td></tr>')
    }, character(1))
  } else '<tr><td colspan="7">No checked entries are available.</td></tr>'
  publisher_options <- if (nrow(publishers)) {
    paste0('<option value="', h(publishers$publisher), '">',
           h(publishers$publisher), '</option>')
  } else character()

  paste(c(
    '<section class="tb-coverage-dashboard" aria-label="Checked catalog dashboard">',
    '<div class="tb-coverage-metrics" aria-label="Catalog and health summary">',
    metrics,
    '</div>',
    if (!has_health) paste0(
      '<p class="tb-coverage-notice" role="status">No matching health report was ',
      'available for this build. All current health statuses are unverified; ',
      'dated catalog checks remain visible below.</p>') else
      paste0('<p class="tb-coverage-notice">', summary$unverified,
             ' checked entries have no conclusive recent health result.</p>'),
    '<h2 id="coverage-by-publisher">By publisher</h2>',
    '<div class="tb-coverage-table-wrap"><table class="tb-coverage-table">',
    '<caption>Checked catalog entries and current verification by publisher</caption>',
    '<thead><tr><th scope="col">Publisher</th><th scope="col">Checked entries</th>',
    '<th scope="col">Last verification</th><th scope="col">Healthy</th>',
    '<th scope="col">Problematic</th><th scope="col">Unverified</th></tr></thead><tbody>',
    publisher_rows,
    '</tbody></table></div>',
    '<h2 id="coverage-by-dataset">By dataset</h2>',
    '<div class="tb-coverage-filters" id="tb-coverage-filters" hidden>',
    '<label for="tb-coverage-search">Search datasets</label>',
    '<input id="tb-coverage-search" type="search" placeholder="Name, topic, endpoint, or issue">',
    '<label for="tb-coverage-publisher">Publisher</label>',
    '<select id="tb-coverage-publisher"><option value="">All publishers</option>',
    publisher_options,
    '</select><label for="tb-coverage-status">Status</label>',
    '<select id="tb-coverage-status"><option value="">All statuses</option>',
    status_options,
    '</select>',
    '</div>',
    paste0('<p id="tb-coverage-count" class="tb-coverage-filter-count" ',
           'role="status" aria-live="polite" hidden></p>'),
    '<div class="tb-coverage-table-wrap"><table class="tb-coverage-table" id="tb-coverage-datasets">',
    '<caption>Checked datasets, dated evidence, current status, and source limits</caption>',
    '<thead><tr><th scope="col">Dataset</th><th scope="col">Publisher</th>',
    '<th scope="col">Category</th><th scope="col">ArcGIS endpoint</th>',
    '<th scope="col">Last verification</th><th scope="col">Status</th>',
    '<th scope="col">Known issues or limits</th></tr></thead><tbody>',
    dataset_rows,
    '</tbody></table></div>',
    '</section>'
  ), collapse = "\n")
}

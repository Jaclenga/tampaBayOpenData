# Report-only helpers for tools/check-catalog.R. They do not read or update the
# checked registry; the caller supplies its public checked-catalog table.

catalog_health_run <- function(checked, check_fun, timeout = 10,
                               total_timeout = 600, pause = 0.5,
                               workers = if (.Platform$OS.type == "windows") 1L else 2L) {
  if (!is.data.frame(checked) || !nrow(checked) ||
      !"jurisdiction" %in% names(checked) ||
      anyNA(checked$jurisdiction)) {
    stop("Expected a nonempty checked catalog with jurisdiction values.")
  }
  if (!is.function(check_fun) || !is.numeric(workers) || length(workers) != 1L ||
      is.na(workers) || workers < 1 || workers > 2 || workers != floor(workers)) {
    stop("The checker must be a function and workers must be 1 or 2.")
  }
  jurisdictions <- unique(checked$jurisdiction)
  run_one <- function(jurisdiction) {
    tryCatch(list(report = check_fun(jurisdiction = jurisdiction,
                                      probe_query = TRUE, timeout = timeout,
                                      total_timeout = total_timeout,
                                      pause = pause), error = NULL),
             error = function(e) list(report = NULL, error = conditionMessage(e)))
  }
  pieces <- if (.Platform$OS.type == "windows" || workers == 1L) {
    lapply(jurisdictions, run_one)
  } else {
    parallel::mclapply(jurisdictions, run_one, mc.cores = min(2L, workers),
                       mc.preschedule = FALSE, mc.set.seed = FALSE)
  }
  failed <- which(vapply(pieces, function(x) !is.list(x) || !is.null(x$error),
                         logical(1)))
  if (length(failed)) {
    reasons <- vapply(failed, function(i) {
      paste0(jurisdictions[[i]], ": ",
             if (is.list(pieces[[i]])) pieces[[i]]$error else
               "parallel worker did not return a report")
    }, character(1))
    stop("Catalog checks failed: ", paste(reasons, collapse = "; "), call. = FALSE)
  }
  if (!all(vapply(pieces, function(x) is.data.frame(x$report), logical(1)))) {
    stop("A catalog check did not return a report table.", call. = FALSE)
  }
  report <- do.call(rbind, lapply(pieces, `[[`, "report"))
  rownames(report) <- NULL
  report
}

catalog_health_validate <- function(report, checked) {
  required <- c("publisher", "jurisdiction", "dataset_id", "endpoint",
                "checked_at", "status", "failure_type", "http_status",
                "service_status", "layer_status", "schema_status",
                "schema_issues", "details", "health_state",
                "response_time_ms", "query_status", "query_failure_type",
                "query_http_status", "query_details")
  if (!is.data.frame(report) || !nrow(report) ||
      !all(required %in% names(report)) ||
      !inherits(report$checked_at, "POSIXct") || anyNA(report$checked_at) ||
      !is.list(report$schema_issues) ||
      !all(vapply(report[c("publisher", "jurisdiction", "dataset_id",
                           "endpoint", "status", "health_state", "query_status",
                           "failure_type", "query_failure_type", "details",
                           "query_details")], is.character, logical(1))) ||
      anyNA(report[c("publisher", "jurisdiction", "dataset_id", "endpoint",
                     "status", "health_state", "query_status")]) ||
      !all(report$status %in% c("healthy", "unavailable", "schema_changed",
                                "unsupported", "unknown")) ||
      !all(report$health_state %in% c("healthy", "degraded", "unavailable",
                                      "unknown")) ||
      !all(report$query_status %in% c("not_checked", "verified", "failed",
                                      "unknown")) ||
      !is.numeric(report$response_time_ms) ||
      any(!is.na(report$response_time_ms) &
          (!is.finite(report$response_time_ms) | report$response_time_ms < 0)) ||
      !is.numeric(report$http_status) ||
      !is.numeric(report$query_http_status)) {
    stop("Catalog check did not return a complete, valid health-report table.",
         call. = FALSE)
  }
  state_for_status <- c(healthy = "healthy", schema_changed = "degraded",
                        unsupported = "degraded", unavailable = "unavailable",
                        unknown = "unknown")
  if (!identical(report$health_state,
                 unname(state_for_status[report$status]))) {
    stop("Health state does not agree with the catalog status.", call. = FALSE)
  }
  if (any(report$health_state == "healthy" & report$query_status != "verified") ||
      any(report$query_status == "failed" & report$health_state != "degraded") ||
      any(report$query_status == "unknown" & report$health_state != "unknown" &
          report$status != "schema_changed")) {
    stop("Query probe results do not agree with the reported health states.",
         call. = FALSE)
  }
  if (!is.data.frame(checked) || !nrow(checked) ||
      !all(c("jurisdiction", "id", "service_url", "layer_id", "publisher") %in%
           names(checked))) {
    stop("Checked catalog did not return a complete table.", call. = FALSE)
  }
  report_keys <- paste(report$jurisdiction, report$dataset_id, sep = "\r")
  catalog_keys <- paste(checked$jurisdiction, checked$id, sep = "\r")
  if (anyDuplicated(report_keys) || anyDuplicated(catalog_keys) ||
      length(report_keys) != length(catalog_keys) ||
      !setequal(report_keys, catalog_keys)) {
    stop("Catalog check omitted or duplicated checked catalog entries.",
         call. = FALSE)
  }
  matched <- match(report_keys, catalog_keys)
  expected_endpoints <- paste0(checked$service_url[matched], "/",
                               checked$layer_id[matched])
  if (!identical(report$endpoint, expected_endpoints) ||
      !identical(report$publisher, checked$publisher[matched])) {
    stop("Catalog check returned endpoints or publishers that differ from the checked catalog.",
         call. = FALSE)
  }
  invisible(report)
}

catalog_health_state_counts <- function(report) {
  states <- c("healthy", "degraded", "unavailable", "unknown")
  counts <- tabulate(match(report$health_state, states), nbins = length(states))
  stats::setNames(as.integer(counts), states)
}

catalog_health_cell <- function(value) {
  if (length(value) != 1L || is.na(value) || !nzchar(as.character(value))) {
    return("-")
  }
  value <- as.character(value)
  value <- gsub("&", "&amp;", value, fixed = TRUE)
  value <- gsub("<", "&lt;", value, fixed = TRUE)
  value <- gsub(">", "&gt;", value, fixed = TRUE)
  value <- gsub("|", "&#124;", value, fixed = TRUE)
  value <- gsub("[\r\n]+", " ", value)
  value
}

catalog_health_reasons <- function(report, i) {
  reasons <- unique(c(report$failure_type[[i]], report$query_failure_type[[i]]))
  reasons <- reasons[!is.na(reasons) & nzchar(reasons)]
  if (!length(reasons)) return("-")
  catalog_health_cell(paste(reasons, collapse = ", "))
}

catalog_health_markdown <- function(report, generated_at = Sys.time()) {
  counts <- catalog_health_state_counts(report)
  observed <- report$response_time_ms[is.finite(report$response_time_ms)]
  timing <- if (length(observed)) {
    paste0("Median response time: ",
           format(round(stats::median(observed), 1), nsmall = 1, trim = TRUE),
           " ms across ", length(observed), " reached entries.")
  } else {
    "Median response time: unavailable; no entry returned a timed response."
  }
  lines <- c(
    "# Catalog health check", "",
    paste0("Generated: ", format(generated_at, "%Y-%m-%d %H:%M:%S UTC",
                                 tz = "UTC")),
    paste0("Checked entries: ", nrow(report)), timing,
    "",
    "| Health state | Entries |", "| --- | ---: |",
    paste0("| ", names(counts), " | ", as.integer(counts), " |"),
    "", "## Dataset results", "",
    "| Jurisdiction | Dataset ID | Checked at (UTC) | Health | Metadata HTTP | Query | Query HTTP | Response (ms) | Failure reason |",
    "| --- | --- | --- | --- | ---: | --- | ---: | ---: | --- |"
  )
  for (i in seq_len(nrow(report))) {
    ms <- if (is.na(report$response_time_ms[[i]])) "-" else
      format(round(report$response_time_ms[[i]], 1), nsmall = 1, trim = TRUE)
    cells <- c(report$jurisdiction[[i]], report$dataset_id[[i]],
               format(report$checked_at[[i]], "%Y-%m-%d %H:%M:%S", tz = "UTC"),
               report$health_state[[i]], report$http_status[[i]],
               report$query_status[[i]], report$query_http_status[[i]], ms)
    lines <- c(lines, paste0("| ",
                             paste(c(vapply(cells, catalog_health_cell,
                                            character(1)),
                                     catalog_health_reasons(report, i)),
                                   collapse = " | "), " |"))
  }
  findings <- which(report$health_state != "healthy")
  if (length(findings)) {
    lines <- c(lines, "", "## Findings", "")
    for (i in findings) {
      details <- c(report$details[[i]], report$query_details[[i]])
      details <- details[!is.na(details) & nzchar(details)]
      lines <- c(lines, paste0("- **", catalog_health_cell(report$jurisdiction[[i]]),
                               "/", catalog_health_cell(report$dataset_id[[i]]),
                               "** (", catalog_health_cell(report$health_state[[i]]),
                               "): ", catalog_health_reasons(report, i),
                               if (length(details)) paste0(" - ",
                                 catalog_health_cell(paste(unique(details), collapse = " "))) else
                                 ""))
    }
  }
  c(lines, "", "This point-in-time check does not measure source record freshness or change the checked catalog.")
}

catalog_health_write <- function(report, prefix, generated_at = Sys.time()) {
  # RDS retains structured diagnostics; CSV stores list columns as JSON text.
  saveRDS(report, paste0(prefix, ".rds"))
  csv_report <- report
  list_columns <- vapply(csv_report, is.list, logical(1))
  for (name in names(csv_report)[list_columns]) {
    csv_report[[name]] <- vapply(csv_report[[name]], function(value) {
      as.character(jsonlite::toJSON(value, auto_unbox = TRUE, null = "null",
                                    na = "null", POSIXt = "ISO8601"))
    }, character(1))
  }
  utils::write.csv(csv_report, paste0(prefix, ".csv"), row.names = FALSE, na = "")

  json_report <- report
  json_report$checked_at <- format(report$checked_at, "%Y-%m-%dT%H:%M:%SZ",
                                   tz = "UTC")
  envelope <- list(
    schema_version = 1L,
    generated_at = format(generated_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    checked_entries = nrow(report),
    health_counts = as.list(catalog_health_state_counts(report)),
    entries = json_report
  )
  jsonlite::write_json(envelope, paste0(prefix, ".json"),
                       pretty = TRUE, dataframe = "rows", auto_unbox = TRUE,
                       na = "null", null = "null")
  lines <- catalog_health_markdown(report, generated_at)
  writeLines(lines, paste0(prefix, "-summary.md"), useBytes = TRUE)
  lines
}

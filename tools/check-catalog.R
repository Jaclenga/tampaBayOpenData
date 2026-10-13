# Check the bundled catalog against live ArcGIS metadata without changing it.
# Run from the package root after installing the current package:
#   Rscript tools/check-catalog.R
#   Rscript tools/check-catalog.R /path/to/report-directory
# Results are saved outside inst/extdata/ as a lossless RDS report, a portable
# CSV report, and a short Markdown summary. The default directory is ignored
# by Git; the scheduled workflow uploads it as a run artifact.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1L) {
  stop("Usage: Rscript tools/check-catalog.R [report-directory]")
}
if (!file.exists("DESCRIPTION") || !file.exists("inst/extdata/datasets.json")) {
  stop("Run this script from the tampaBayOpenData package root.")
}
if (!requireNamespace("tampaBayOpenData", quietly = TRUE) ||
    !requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Install the current tampaBayOpenData package before running this script.")
}

report_dir <- if (length(args)) args[[1L]] else file.path(".artifacts", "catalog-health")
catalog_dir <- normalizePath(file.path("inst", "extdata"), winslash = "/")
destination <- normalizePath(report_dir, winslash = "/", mustWork = FALSE)
if (.Platform$OS.type == "windows") {
  catalog_dir <- tolower(catalog_dir)
  destination <- tolower(destination)
}
if (identical(destination, catalog_dir) ||
    startsWith(destination, paste0(catalog_dir, "/"))) {
  stop("Write catalog health reports outside inst/extdata.")
}
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(report_dir)) stop("Could not create report directory: ", report_dir)

stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
prefix <- file.path(report_dir, paste0("catalog-health-", stamp))
fail <- function(message) {
  writeLines(c(
    paste("Catalog check failed at", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    message
  ), paste0(prefix, "-error.txt"))
  stop(message, call. = FALSE)
}

report <- tryCatch(
  tampaBayOpenData::tbod_check_catalog(),
  error = function(e) fail(conditionMessage(e))
)
required <- c("publisher", "jurisdiction", "dataset_id", "endpoint",
              "checked_at", "status", "failure_type", "http_status",
              "service_status", "layer_status", "schema_status",
              "schema_issues", "details")
if (!is.data.frame(report) || !nrow(report) ||
    !all(required %in% names(report)) ||
    !is.character(report$status) || !is.list(report$schema_issues) ||
    !inherits(report$checked_at, "POSIXct") || anyNA(report$checked_at) ||
    anyNA(report$status) ||
    !all(report$status %in% c("healthy", "unavailable", "schema_changed",
                              "unsupported", "unknown"))) {
  fail("Catalog check did not return a complete, valid health-report table.")
}
checked <- tampaBayOpenData::tbod_list_datasets(source = "checked")
report_keys <- paste(report$jurisdiction, report$dataset_id, sep = "\r")
catalog_keys <- paste(checked$jurisdiction, checked$id, sep = "\r")
if (anyDuplicated(report_keys) || length(report_keys) != length(catalog_keys) ||
    !setequal(report_keys, catalog_keys)) {
  fail("Catalog check omitted or duplicated checked catalog entries.")
}
matched <- match(report_keys, catalog_keys)
expected_endpoints <- paste0(checked$service_url[matched], "/",
                             checked$layer_id[matched])
if (!identical(report$endpoint, expected_endpoints) ||
    !identical(report$publisher, checked$publisher[matched])) {
  fail("Catalog check returned endpoints or publishers that differ from the checked catalog.")
}

# The RDS preserves any structured diagnostic columns. Encode those columns
# as JSON only in the companion CSV so standard spreadsheet tools can read it.
saveRDS(report, paste0(prefix, ".rds"))
csv_report <- report
list_columns <- vapply(csv_report, is.list, logical(1))
for (name in names(csv_report)[list_columns]) {
  csv_report[[name]] <- vapply(csv_report[[name]], function(value) {
    as.character(jsonlite::toJSON(value, auto_unbox = TRUE, null = "null",
                                  na = "null", POSIXt = "ISO8601"))
  }, character(1))
}
write.csv(csv_report, paste0(prefix, ".csv"), row.names = FALSE, na = "")

counts <- table(report$status, useNA = "ifany")
summary <- c(
  "# Catalog health check",
  "",
  paste("Verified at:", format(Sys.time(), tz = "UTC", usetz = TRUE)),
  paste("Checked entries:", nrow(report)),
  "",
  "| Status | Entries |",
  "| --- | ---: |",
  paste0("| ", names(counts), " | ", as.integer(counts), " |")
)
summary_file <- paste0(prefix, "-summary.md")
writeLines(summary, summary_file)
cat(paste(summary, collapse = "\n"), "\n")

step_summary <- Sys.getenv("GITHUB_STEP_SUMMARY", unset = "")
if (nzchar(step_summary)) {
  cat(paste(summary, collapse = "\n"), "\n", file = step_summary, append = TRUE)
}

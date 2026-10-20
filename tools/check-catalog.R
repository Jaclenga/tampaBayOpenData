# Check the bundled catalog against live ArcGIS metadata without changing it.
# Run from the package root after installing the current package:
#   Rscript tools/check-catalog.R
#   Rscript tools/check-catalog.R /path/to/report-directory
# Results are saved outside inst/extdata/ as lossless RDS, portable CSV and
# JSON reports, and a readable Markdown summary. The default directory is
# ignored by Git; the scheduled workflow uploads it as a run artifact.

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
source(file.path("tools", "catalog-health-report.R"), local = TRUE)

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

generated_at <- Sys.time()
stamp <- format(generated_at, "%Y%m%dT%H%M%SZ", tz = "UTC")
prefix <- file.path(report_dir, paste0("catalog-health-", stamp))
fail <- function(message) {
  writeLines(c(
    paste("Catalog check failed at", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    message
  ), paste0(prefix, "-error.txt"))
  stop(message, call. = FALSE)
}

checked <- tryCatch(tampaBayOpenData::tbod_list_datasets(source = "checked"),
                    error = function(e) fail(conditionMessage(e)))
report <- tryCatch(catalog_health_run(
  checked, tampaBayOpenData::tbod_check_catalog,
  timeout = 10, total_timeout = 600, pause = 0.5),
  error = function(e) fail(conditionMessage(e)))
tryCatch(catalog_health_validate(report, checked),
         error = function(e) fail(conditionMessage(e)))
summary <- tryCatch(catalog_health_write(report, prefix, generated_at),
                    error = function(e) fail(conditionMessage(e)))
cat(paste(summary, collapse = "\n"), "\n")

step_summary <- Sys.getenv("GITHUB_STEP_SUMMARY", unset = "")
if (nzchar(step_summary)) {
  cat(paste(summary, collapse = "\n"), "\n", file = step_summary, append = TRUE)
}

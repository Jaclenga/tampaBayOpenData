#' List the supported public-data catalog
#'
#' Discovery reads the versioned registry bundled with the package and does not
#' contact government services. The catalog contains supported datasets, rather
#' than every dataset in the City's portal.
#' @param jurisdiction Government provider. v0.1 supports only `"tampa"`.
#' @return A tibble of dataset metadata, including source and service URLs,
#'   verification dates, and list columns for tags and declared date fields.
#' @export
#' @examples
#' list_datasets()
list_datasets <- function(jurisdiction = "tampa") {
  .catalog_table(.jurisdiction_entries(jurisdiction))
}

#' Search the supported dataset catalog
#'
#' Searches titles, descriptions, tags, categories, and package IDs using
#' case-insensitive literal substring matching. Multiple whitespace-separated
#' words must all match somewhere in the record. An empty query lists all records.
#' @param query A single search string; punctuation is treated literally.
#' @inheritParams list_datasets
#' @return A tibble with the same columns as [list_datasets()].
#' @export
#' @examples
#' search_datasets("permit")
#' search_datasets("capital projects")
search_datasets <- function(query, jurisdiction = "tampa") {
  .string(query, "query", allow_empty = TRUE)
  catalog <- list_datasets(jurisdiction)
  words <- strsplit(tolower(trimws(query)), "[[:space:]]+")[[1L]]
  words <- words[nzchar(words)]
  if (!length(words)) return(catalog)
  text <- tolower(paste(catalog$id, catalog$title, catalog$description,
                        catalog$category, vapply(catalog$tags, paste, character(1), collapse = " ")))
  keep <- rep(TRUE, nrow(catalog))
  for (word in words) keep <- keep & grepl(word, text, fixed = TRUE)
  catalog[keep, , drop = FALSE]
}

#' Inspect a dataset and its government source
#'
#' The default is an offline registry lookup. Set `refresh = TRUE` to retrieve
#' the current layer schema, aliases, field types, CRS, query capabilities, and
#' upstream editing metadata when available. Registry verification dates are
#' endpoint checks, not dates when government records were updated.
#' @param id Stable package dataset ID from [list_datasets()].
#' @inheritParams list_datasets
#' @param refresh Whether to request live layer metadata.
#' @param timeout Per-request timeout in seconds.
#' @return A named list of registry metadata. Live inspection adds `fields`
#'   (a tibble), `metadata` (the raw layer metadata), and `inspected_at` (UTC).
#' @export
#' @examples
#' dataset_info("construction-permits")
#' \dontrun{
#' info <- dataset_info("construction-permits", refresh = TRUE)
#' info$fields
#' }
dataset_info <- function(id, jurisdiction = "tampa", refresh = FALSE, timeout = 30) {
  .flag(refresh, "refresh")
  .number(timeout, "timeout", min = .Machine$double.eps)
  entry <- .lookup_dataset(id, jurisdiction)
  if (refresh) {
    metadata <- arcgis_layer(entry, timeout)
    entry$fields <- tibble::tibble(
      name = .field_names(metadata),
      type = vapply(metadata$fields, function(x) x$type, character(1)),
      alias = vapply(metadata$fields, function(x) x$alias %||% x$name, character(1)))
    entry$metadata <- metadata
    entry$inspected_at <- .utc_now()
  }
  entry
}

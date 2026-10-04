#' Retrieve City of Tampa permit locations
#'
#' A thin wrapper for `get_dataset("construction-permits", ...)`. The source is
#' the City's PermitsAll layer used by its active-permits viewer, not a guaranteed
#' historical archive of every permit. Source values and scope are preserved.
#' @param ... Arguments passed unchanged to [get_dataset()], excluding `id`.
#' @inherit get_dataset return
#' @export
#' @examples
#' dataset_info("construction-permits")$title
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   permits <- get_permits(limit = 10)
#'   dataset_provenance(permits)$source_url
#' }
get_permits <- function(...) get_dataset("construction-permits", ...)

#' Retrieve City of Tampa active development case locations
#'
#' A thin wrapper for `get_dataset("development-cases", ...)`. The upstream
#' layer covers active entitlement locations, not all historical development.
#' @inheritParams get_permits
#' @inherit get_permits return
#' @export
#' @examples
#' dataset_info("development-cases")$title
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   cases <- get_development_cases(limit = 10)
#'   nrow(cases)
#' }
get_development_cases <- function(...) get_dataset("development-cases", ...)

#' Retrieve City of Tampa public capital project locations
#'
#' A thin wrapper for `get_dataset("capital-projects", ...)`. The City service
#' publishes only records marked PUBLIC; this client preserves that source scope.
#' @inheritParams get_permits
#' @inherit get_permits return
#' @export
#' @examples
#' dataset_info("capital-projects")$title
#' if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
#'   projects <- get_capital_projects(limit = 10)
#'   nrow(projects)
#' }
get_capital_projects <- function(...) get_dataset("capital-projects", ...)

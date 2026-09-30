#' Discover and retrieve City of Tampa public open data
#'
#' A small catalog-driven interface to authoritative City of Tampa ArcGIS
#' feature and map services. Start with [list_datasets()], [search_datasets()],
#' and [dataset_info()], then use [get_dataset()] to retrieve a tibble or an
#' optional `sf` object. [dataset_provenance()] exposes the source and query.
#'
#' Only the City of Tampa is supported in version 0.1. This independent package
#' was inspired by rOpenSci's nycOpenData; it is not affiliated with rOpenSci or
#' any government publisher. Government datasets retain their upstream terms.
#' @keywords internal
"_PACKAGE"

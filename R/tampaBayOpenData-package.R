#' Discover and retrieve City of Tampa public open data
#'
#' Search public City of Tampa and Tampa Bay Regional Planning Council ArcGIS
#' services with [list_datasets()] or [search_datasets()]. The bundled catalog
#' identifies 20 City layers checked by package maintainers. Use [get_dataset()]
#' for a checked ID or discovered layer, or [get_arcgis_layer()] for a direct
#' compatible URL. Results are tibbles or optional `sf` objects;
#' [dataset_provenance()] exposes the source, validation status, and query.
#'
#' This independent package was inspired by rOpenSci's nycOpenData; it is not
#' affiliated with rOpenSci or any government publisher. Government datasets
#' retain their upstream terms.
#' @keywords internal
"_PACKAGE"

#' Discover and retrieve Tampa Bay public data
#'
#' Search public Tampa, St. Petersburg, Clearwater, Hillsborough County, Pinellas
#' County, and Tampa Bay Regional Planning Council ArcGIS services with
#' [list_datasets()] or [search_datasets()]. [list_portals()] reads the publisher
#' configuration. Catalogs can filter jurisdiction, publisher, validation,
#' geometry, topics, categories, and modification dates.
#' The bundled catalog identifies 35 layers checked by package maintainers;
#' catalog browsing defaults to all jurisdictions. Use [get_dataset()]
#' for a checked ID or discovered layer, or [get_arcgis_layer()] for a direct
#' compatible URL. Results are tibbles or optional `sf` objects;
#' [dataset_provenance()] exposes the source, validation status, and query.
#' [download_dataset()] and [download_arcgis_layer()] write validated chunks to
#' a caller-selected directory and can resume an interrupted download.
#'
#' This independent package was inspired by rOpenSci's nycOpenData; it is not
#' affiliated with rOpenSci or any government publisher. Government datasets
#' retain their upstream terms.
#'
#' @section Request identity:
#' Web requests use `tampaBayOpenData/0.1.0` as the default user agent. Set
#' `options(tampaBayOpenData.user_agent = "my-project/1.0 (contact: me@example.org)")`
#' before calling a function that contacts a publisher to identify your own
#' application. Set the option to `NULL` to restore the default. The setting
#' applies to discovery, retrieval, and downloads.
#' @section Live examples:
#' Examples that contact public ArcGIS services run when
#' `TAMPA_OPEN_DATA_LIVE=true` is set in the R environment. Without this opt-in,
#' the examples use only the bundled registry and run offline.
#' @keywords internal
"_PACKAGE"

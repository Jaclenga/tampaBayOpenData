#' Discover and retrieve public ArcGIS data
#'
#' The package includes a catalog of 52 checked layers from Tampa Bay
#' publishers. Use [tbod_list_datasets()] or [tbod_search_datasets()] with
#' `source = "checked"` to browse the catalog offline. The default also searches
#' public ArcGIS portals configured for Tampa, St. Petersburg, Clearwater,
#' Hillsborough County, Pinellas County, and the Tampa Bay Regional Planning
#' Council.
#' [tbod_list_portals()] lists those publishers.
#'
#' [tbod_discover()] searches another ArcGIS portal or lists layers in a
#' FeatureServer or MapServer service. [tbod_get_dataset()] accepts a bundled
#' ID, discovered row, stable ArcGIS ID, or direct layer URL and returns a tibble
#' or optional `sf` object. [tbod_provenance()] reads its source and query
#' record. [tbod_download_dataset()] saves resumable chunks.
#'
#' Checked layers have saved schema snapshots. [tbod_schema()] reads a saved or
#' current schema, and [tbod_check_schema()] reports changes. Retrieval warns
#' for compatible drift and stops before querying for incompatible drift.
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

# Discover and retrieve public ArcGIS data

The package includes a catalog of 52 checked layers from Tampa Bay
publishers. Use
[`tbod_list_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_datasets.md)
or
[`tbod_search_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_search_datasets.md)
with `source = "checked"` to browse the catalog offline. The default
also searches public ArcGIS portals configured for Tampa, St.
Petersburg, Clearwater, Hillsborough County, Pinellas County, and the
Tampa Bay Regional Planning Council.
[`tbod_list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_portals.md)
lists those publishers.

## Details

[`tbod_discover()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_discover.md)
searches another ArcGIS portal or lists layers in a FeatureServer or
MapServer service.
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
accepts a bundled ID, discovered row, stable ArcGIS ID, or direct layer
URL and returns a tibble or optional `sf` object.
[`tbod_provenance()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_provenance.md)
reads its source and query record.
[`tbod_download_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_download_dataset.md)
saves resumable chunks.

Checked layers have saved schema snapshots.
[`tbod_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_schema.md)
reads a saved or current schema, and
[`tbod_check_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_check_schema.md)
reports changes. Retrieval warns for compatible drift and stops before
querying for incompatible drift.

This independent package was inspired by rOpenSci's nycOpenData; it is
not affiliated with rOpenSci or any government publisher. Government
datasets retain their upstream terms.

## Request identity

Web requests use `tampaBayOpenData/0.1.0` as the default user agent. Set
`options(tampaBayOpenData.user_agent = "my-project/1.0 (contact: me@example.org)")`
before calling a function that contacts a publisher to identify your own
application. Set the option to `NULL` to restore the default. The
setting applies to discovery, retrieval, and downloads.

## Live examples

Examples that contact public ArcGIS services run when
`TAMPA_OPEN_DATA_LIVE=true` is set in the R environment. Without this
opt-in, the examples use only the bundled registry and run offline.

## See also

Useful links:

- <https://jaclenga.github.io/tampaBayOpenData/>

- <https://github.com/Jaclenga/tampaBayOpenData>

- Report bugs at <https://github.com/Jaclenga/tampaBayOpenData/issues>

## Author

**Maintainer**: Jack Lenga <jlenga@alumni.cmu.edu>
([ORCID](https://orcid.org/0009-0003-1153-8105)) \[copyright holder\]

Authors:

- Jack Lenga <jlenga@alumni.cmu.edu>
  ([ORCID](https://orcid.org/0009-0003-1153-8105)) \[copyright holder\]

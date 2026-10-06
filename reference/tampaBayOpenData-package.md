# Discover and retrieve public ArcGIS data

The bundled Tampa Bay configuration covers Tampa, St. Petersburg,
Clearwater, Hillsborough County, Pinellas County, and the Tampa Bay
Regional Planning Council.
[`tbod_list_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_datasets.md)
and
[`tbod_search_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_datasets.md)
browse its checked catalog and configured live portals. The catalog
identifies 35 layers checked by package maintainers;
`source = "checked"` reads them offline.
[`tbod_list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_portals.md)
shows the bundled publisher configuration.

[`tbod_discover()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_discover.md)
searches another public ArcGIS sharing REST portal or enumerates a
FeatureServer or MapServer service. Pass a discovered row, bundled ID,
stable ArcGIS item ID, or direct layer URL to
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md).
Results are tibbles or optional `sf` objects.
[`tbod_provenance()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_provenance.md)
exposes their source, validation status, and query.
[`tbod_download_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_download_dataset.md)
saves validated chunks and can resume an interrupted download.

The bundled checked layers have expected schema snapshots.
[`tbod_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_schema.md)
inspects an expected or current schema, and
[`tbod_check_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_check_schema.md)
reports changes. Retrieval warns for compatible drift and stops before
querying for incompatible drift. Unprefixed function names remain
available for existing code; new code can use the `tbod_` entry points.

## Details

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

**Maintainer**: Jack Lenga <jack3lenga@gmail.com>
([ORCID](https://orcid.org/0009-0003-1153-8105)) \[copyright holder\]

Authors:

- Jack Lenga <jack3lenga@gmail.com>
  ([ORCID](https://orcid.org/0009-0003-1153-8105)) \[copyright holder\]

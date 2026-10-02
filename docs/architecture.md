# Architecture and research basis

The v0.1 client retrieves 11 City of Tampa ArcGIS layers. It does not host
government data or provide analysis. The selected layers, source terms, and
scope limits are recorded in [Tampa source research](research-tampa.md).

## Design basis

The [nycOpenData source audit](research-nycOpenData.md) informed the small
discovery and retrieval API. That package uses a live Socrata catalog and a
single limited retrieval request. This client uses independently written ArcGIS
code, a bundled registry of stable IDs, and checked pagination. It does not
reuse NYC endpoints, SoQL, or title-derived keys.

The City's [GIS page](https://www.tampa.gov/technology-and-innovation/geographic-information-systems)
links its GeoHub. The City's [REST directory](https://arcgis.tampagov.net/arcgis/rest/services)
also exposes queryable FeatureServer and MapServer layers. The registry stores
the verified service root and layer number for each supported dataset; GeoHub
discovery alone does not define this package's catalog.

## Client design

`inst/extdata/datasets.json` provides offline, deterministic discovery through
`list_datasets()`, `search_datasets()`, and default `dataset_info()`. The latter
can request current layer metadata with `refresh = TRUE`. `get_dataset()` uses
that live metadata for schema and capability checks. The three convenience
wrappers call the same retrieval path. Only `jurisdiction = "tampa"` is supported.

HTTP requests use `httr2`; `jsonlite` decodes responses, and `tibble` supplies
tabular results. Optional `sf` and GDAL decode spatial results. Source field
names and strings remain intact. Declared ArcGIS date fields become UTC
`POSIXct` values unless metadata marks their time zone as unknown. In that
case, dates remain epoch milliseconds, apart from UTC editor tracking dates
identified by layer metadata. The native CRS is read from metadata or the
response; it is never assumed. The spatial path keeps two-dimensional XY
geometry.

Retrieval requests a matching count and object-ID manifest, then checks each
bounded batch for missing, duplicate, or unexpected IDs and transfer limits.
By default it fetches object-ID batches, including from `fire-stations`, whose
joined layer has qualified field names and no offset pagination. Explicit
ordering uses supported offset pagination with an object-ID tie breaker;
`fire-stations` does not support `order_by`. A finite `limit` can request a
subset; provenance records its completeness. Queries matching more than one
million records are rejected because the client relies on the ArcGIS ID
manifest. Advanced `query` options allow selected ArcGIS spatial, time, and
version filters while protecting parameters that control response shape and
pagination. See the
[ArcGIS query reference](https://developers.arcgis.com/rest/services-reference/enterprise/query-feature-service-layer/).

Both table and spatial results carry publisher, endpoint, query, retrieval
time, row counts, and completeness metadata through `dataset_provenance()`.
Manifest checks detect changes in record membership during retrieval; they
cannot freeze attributes on a live service. No runtime data cache is maintained.
The [test guide](../tests/README.md) describes offline tests and opt-in live
checks; [validation](validation.md) records dated results.

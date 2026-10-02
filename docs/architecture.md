# Architecture and research basis

The client discovers public ArcGIS layers from the City of Tampa and Tampa Bay
Regional Planning Council organizations. A bundled registry identifies 20 City
layers that package maintainers have checked. It does not host government data
or provide analysis. The selected checked layers, source terms, and scope limits
are recorded in [Tampa source research](research-tampa.md).

## Design basis

The [nycOpenData source audit](research-nycOpenData.md) informed the small
discovery and retrieval API. That package uses a live Socrata catalog and a
single limited retrieval request. This client uses independently written ArcGIS
code, live portal search, a checked registry of stable IDs, and checked
pagination. It does not reuse NYC endpoints, SoQL, or title-derived keys.

The City's [GIS page](https://www.tampa.gov/technology-and-innovation/geographic-information-systems)
links its GeoHub. The City's [REST directory](https://arcgis.tampagov.net/arcgis/rest/services)
also exposes queryable FeatureServer and MapServer layers. The [regional planning
council](https://tbrpc.org/arcgis-geohub/) links its own GeoHub. Live discovery
searches the organizations' public ArcGIS service items and expands each service
into candidate layers and tables. Retrieval checks current Query capability
and schema for the selected layer. This is broader than either Hub's featured
dataset collection, but portal indexing can lag and some direct City services
have no matching public item. `get_arcgis_layer()` accepts a compatible direct
layer URL for those cases.

## Client design

`list_datasets()` and `search_datasets()` combine live discovery with the
checked registry by default. `source = "checked"` reads only
`inst/extdata/datasets.json` and remains offline and deterministic;
`source = "live"` returns only portal-listed layers. The public catalog marks
each row `checked` or `discovered`, deduplicates matching service/layer URLs,
and uses item ID plus layer ID for discovered keys. Titles are display text,
not identifiers. Both City and regional organizations are searched by default;
`portals` narrows them. An inaccessible or malformed item is skipped without
discarding other results, and its issue is recorded on the result. If one
portal fails, discovery warns and retains results from the other. If every
portal fails, `source = "live"` errors; the default combined search warns and
returns checked rows.

`dataset_info()` can inspect a checked ID offline or a discovered row or stable
ArcGIS ID. `get_dataset()` resolves those same inputs, retrieves the current
layer metadata, and applies one query engine for field and capability checks.
The three convenience wrappers call this path. The `jurisdiction` argument
selects the checked City registry; discovered rows carry their publisher and
jurisdiction separately.

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
The client retries the specific generic ArcGIS query error observed
intermittently in HTTP 200 responses, with at most four attempts. It keeps the
same completeness checks after a retry.
By default it fetches object-ID batches. Explicit ordering uses supported
offset pagination with an object-ID tie breaker; the current `fire-stations`
source supports this and exposes unqualified field names. A finite `limit` can
request a subset; provenance records its completeness. Queries matching more
than one million records are rejected because the client relies on the ArcGIS ID
manifest. Advanced `query` options allow selected ArcGIS spatial, time, and
version filters while protecting parameters that control response shape and
pagination. See the
[ArcGIS query reference](https://developers.arcgis.com/rest/services-reference/enterprise/query-feature-service-layer/).

Both table and spatial results carry publisher, endpoint, ArcGIS item and
portal when available, validation status, original metadata, query, retrieval
time, row counts, and completeness through `dataset_provenance()`.
Manifest checks detect changes in record membership during retrieval; they
cannot freeze attributes on a live service. No runtime data cache is maintained.
The [test guide](../tests/README.md) describes offline tests and opt-in live
checks; [validation](validation.md) records dated results.

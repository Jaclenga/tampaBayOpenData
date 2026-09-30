# v0.1 research and architecture decision

Research completed on 2026-09-29 before implementation. v0.1 contains only
datasets published by the City of Tampa. The package is a data-access interface;
it does not publish government data or implement downstream analysis.

## Reference audit

The primary reference is [rOpenSci/nycOpenData](https://github.com/ropensci/nycOpenData),
main commit `39e9fd47f386b469c11f3949b47bfcafc30c1ebb`, version 0.2.3.
Its three exported functions provide catalog discovery and generic retrieval,
with a shared HTTP/JSON helper. Its catalog is a live Socrata table and its
dataset keys are generated from titles. Retrieval is a single limited request,
so pagination, spatial conversion, and attached provenance must be designed here.
The full source, tests, documentation, dependencies, and CI audit is recorded in
[research-nycOpenData.md](research-nycOpenData.md).

Preserve the small catalog-driven API, ordinary R objects, backend abstraction,
and documented discovery workflow. Do not port the NYC domain, Socrata dataset
identifiers, live Socrata catalog assumptions, SoQL, or request limits. All client
code in this package will be independently implemented. The reference's MIT
license permits adaptation with preservation of its notice; no source code
adaptation is needed. Credit inspiration without implying affiliation.

## Verified Tampa infrastructure

The City's [GIS page](https://www.tampa.gov/departments/geographic-information-systems)
links [City of Tampa GeoHub](https://city-tampa.opendata.arcgis.com/).
The public [ArcGIS REST directory](https://arcgis.tampagov.net/arcgis/rest/services)
contains both FeatureServer and queryable MapServer layers. GeoHub discovery
alone is not a complete description of the services. Service and layer metadata
and small queries must be verified before registration. Details, endpoint
evidence, source descriptions, update information, and terms appear in
[research-tampa.md](research-tampa.md).

The initial candidates include these verified layers:

| Package ID | Service and layer | Purpose |
| --- | --- | --- |
| `construction-permits` | `Planning/PermitsAll/FeatureServer/0` | Permit locations used in the City's active-permits viewer |
| `development-cases` | `Planning/ActiveEntitlementLocations/FeatureServer/0` | Active entitlement locations |
| `capital-projects` | `OpenData/CapitalProjects/MapServer/0` | Public capital project locations |
| `city-boundary` | `OpenData/Boundary/MapServer/6` | Shoreline-modified Tampa boundary |
| `neighborhoods` | `OpenData/Boundary/MapServer/5` | Neighborhood association boundaries |
| `council-districts` | `OpenData/Boundary/MapServer/0` | Council district boundaries |
| `riverwalk` | `OpenData/Planning/MapServer/4` | Riverwalk line segments |
| `parks` | `OpenData/Location/MapServer/10` | Park polygon coverage |

All eight layers passed live count, ordered-page, empty-response, and projection
checks. Permits contained 2,594 records, exceeding a single response's limit.
The verified layers advertise a 2,000-feature response limit, query support,
ordering, and offset pagination. Most use Web Mercator (`102100`, latest EPSG
`3857`), but capital projects use `103023`, latest EPSG `6443`. CRS cannot be
hard-coded. MapServer metadata can omit `objectIdField`; its field schema still
identifies the OID. The purported construction-inspections service groups permit
locations and contains copied descriptions, so an inspection-event interface is
not justified by the verified schema.

## Smallest useful architecture

Use a bundled, versioned JSON registry. Discovery is deterministic and offline.
Each record contains a package-owned stable ID, jurisdiction, upstream title and
description, publisher, source page, service root, layer number, geometry, date
fields, category/tags, terms and verification date. Runtime layer metadata is
fetched to validate field selection and parse the current schema. `dataset_info()`
has an optional live metadata mode. No runtime catalog cache is introduced.

The public API is `list_datasets()`, `search_datasets()`, `dataset_info()`, and
`get_dataset()`, with `jurisdiction = "tampa"`. A jurisdiction column and one
backend dispatch are sufficient for future expansion; no plugin system is needed.
Three thin wrappers for permits, development cases, and capital projects share
the exact generic retrieval path.

Use `httr2` for timeouts, bounded retries, and HTTP transport, `jsonlite` for JSON,
and `tibble` for tabular results. Spatial retrieval uses optional `sf`; users who
only need tables do not need to install its native dependencies. Preserve source
field names and values; convert declared dates from epoch milliseconds into UTC
POSIXct, and preserve date-looking string columns. Unknown time-zone metadata
must not be interpreted as a known instant.

## Retrieval integrity

Query a matching count and object-ID manifest before fetching bounded batches.
Check manifest size against the count, reject duplicate or malformed IDs, include
the OID internally even for selected fields, and verify every returned batch.
Detect truncation, missing rows, unexpected IDs, and duplicate pages instead of
returning an apparently complete table. This works for layers that cannot use
offset pagination. Esri's current documentation states a one-million-ID cap;
reject a count above that cap and ask the caller to filter.

For explicitly requested server ordering, use supported offset pagination with
an OID tie breaker and validate against the manifest. `limit` deliberately requests
a subset and provenance records whether it exhausts the matching records. A
changing service can cause a clear retryable integrity error. These checks verify
record membership; they cannot promise transactionally frozen attributes on a
live government API.

The advanced `query` list supports ArcGIS spatial/time filters and versioning,
while protecting parameters that control response shape, pagination, and field
parsing. Raw SQL `where` is sent to the read-only upstream query operation, with
errors retaining dataset and source context. No custom query language is added.

## Spatial, provenance, and quality

Read ArcGIS geometry using the mature `sf`/GDAL ESRIJSON driver; test points,
multipart lines, polygons with holes, missing geometry, empty results, and CRS.
Never label coordinates with an assumed CRS. Source metadata, retrieval time,
query parameters, expected and returned rows, dataset ID, and jurisdiction are
attached to both table and spatial results and exposed through an accessor.

Use deterministic `testthat` transport mocks and representative fixtures for
registry, retrieval integrity, error handling, types, geometry, and provenance.
Live integration tests are opt-in. Generate function help with roxygen2, build an
offline-safe introductory vignette, and run R CMD check locally. CI checks Linux,
macOS, and Windows; a separate manual workflow checks live endpoints. README,
troubleshooting, attribution, and contribution guidance are release deliverables.

Internally, `pagination.R` separates object-ID batches from ordered offsets and
passes accumulated features, IDs, and CRS explicitly between steps. Shared page
requests and CRS checks retain the same integrity checks and request order.
`parsing.R` dispatches declared field types to focused date and integer parsers.
`spatial.R` separates CRS selection and geometry validation from local GDAL
decoding. Native CRS fallback is shared with pagination and provenance, and
advanced query parameters are prepared once before retrieval.

Primary API references:
[ArcGIS layer query](https://developers.arcgis.com/rest/services-reference/enterprise/query-feature-service-layer/)
and [geometry objects](https://developers.arcgis.com/rest/services-reference/enterprise/geometry-objects/).

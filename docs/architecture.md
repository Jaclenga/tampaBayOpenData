# Architecture and research basis

The client searches public ArcGIS services from Tampa, St. Petersburg,
Clearwater, Hillsborough County, Pinellas County, and the Tampa Bay Regional
Planning Council. The package includes 52 checked catalog entries; it does not
host government data. `tbod_dataset_info(id)` gives each record's scope,
terms, and verification date. See the [catalog policy](checked-catalog-policy.md)
for selection decisions and [Tampa source research](research-tampa.md) for
source-specific findings.

## Design basis

The [nycOpenData source audit](research-nycOpenData.md) informed the API.
`nycOpenData` searches a live Socrata catalog; this package searches ArcGIS
portals and maintains checked IDs. Its ArcGIS client code is independent and
does not use NYC endpoints, SoQL, or title-derived keys.

The City's [GIS page](https://www.tampa.gov/technology-and-innovation/geographic-information-systems)
links its GeoHub, while its [REST directory](https://arcgis.tampagov.net/arcgis/rest/services)
exposes additional FeatureServer and MapServer layers. The
[St. Petersburg portal](https://csp.maps.arcgis.com/home/index.html),
[Clearwater portal](https://cityofclearwater.maps.arcgis.com/home/index.html),
and [regional planning council GeoHub](https://tbrpc.org/arcgis-geohub/)
identify other configured sources. Official publisher evidence and
organization metadata are recorded in the portal registry. Live discovery
expands public service items into candidate layers and tables. Portal indexing
can lag or omit a public service; `tbod_get_arcgis_layer()` accepts a
compatible direct layer URL.

## Client design

The `tbod_` entry points separate the reusable ArcGIS client from the bundled
Tampa Bay configuration. `tbod_discover()` accepts another public ArcGIS sharing
REST portal root, FeatureServer or MapServer service root, or layer URL and
returns rows that `tbod_get_dataset()` can retrieve.
`tbod_get_dataset()` also accepts a compatible HTTPS FeatureServer or MapServer
layer URL directly. Checked IDs, portal rows, and direct URLs use the same
metadata, pagination, parsing, spatial, and provenance code.
Portal results have `discovered` status; rows found from a service or layer URL
have `not_checked` status because they have no portal item identity.

Checked dataset records include expected field names and types, geometry, CRS,
object ID field, and endpoint from a dated metadata snapshot. The schema
snapshot is keyed by jurisdiction and checked dataset ID, so two publishers
can use the same short ID. A short ID shared by jurisdictions requires an
explicit `jurisdiction` on lookup. Before checked retrieval or download, the
client compares the live layer metadata with that snapshot. `tbod_schema()`
exposes the expected or live metadata, while
`tbod_check_schema()` reports categorized differences. Additive fields generate
a warning; removed or changed fields, geometry or CRS changes, and disappeared
endpoints stop the operation. Discovered rows and direct URLs have no maintainer
snapshot, so their current metadata is validated without a drift comparison.
Callers can save `tbod_schema(id, refresh = TRUE)` and pass it as `expected` to
`tbod_check_schema()` for an external source. A stable Enterprise item ID can
be inspected with the same `portal` argument used for retrieval.

`tbod_list_datasets()` and `tbod_search_datasets()` combine live discovery with
the checked registry by default. `source = "checked"` reads the bundled
snapshots offline. The live overlay matches endpoints against the entire
checked registry, including entries outside the selected jurisdiction.

`source = "live"` returns only portal-listed layers. Catalog rows are marked
`checked` or `discovered`; matching service/layer URLs are deduplicated, and
discovered keys use the item and layer IDs rather than titles. The portal
registry in `inst/extdata/portals.json` records publisher identity, source
URLs, and verification evidence. `tbod_list_portals()` reads it offline.
Adding a publisher requires a registry entry, not a retrieval branch.

Discovery inspects each layer's metadata, including its type, geometry, and
`Query` capability. It defaults to 25 service items per organization;
`max_items = Inf` requests an uncapped scan. Result attributes report scan
completeness and issues. A malformed or inaccessible item does not discard
other results. If a portal fails after yielding rows, discovery warns and
keeps them. If all selected portals fail before yielding rows, a live-only
search errors; the combined catalog warns and returns checked rows.

The checked overlay preserves stable IDs, titles, terms, and scope while
adding live tags, categories, and modification times. Live item and layer
snapshots remain in `original_metadata$discovery`. Publisher and jurisdiction
filters select organizations before a scan; other filters apply after merging.
A bounded scan can therefore miss matches. `modified_source` distinguishes
portal-item timestamps from checked snapshots; neither establishes feature
freshness. The [discovery guide](../vignettes/discovery.Rmd) documents filter
matching and scan limits.

`tbod_dataset_info()` can inspect a checked ID offline or a discovered row or stable
ArcGIS ID. `tbod_get_dataset()` resolves those same inputs, retrieves the current
layer metadata, and applies one query engine for field and capability checks.
The three dataset shortcuts call this path. Retrieval and download resolve
a uniquely named checked ID across publishers by default. Discovered rows
carry their publisher and jurisdiction. Direct URLs have `"unspecified"`
jurisdiction and do not accept a jurisdiction override.

HTTP requests use `httr2`; `jsonlite` decodes responses, and `tibble` supplies
tabular results. Optional `sf` and GDAL decode spatial results. Source field
names and text fields remain intact. ArcGIS epoch-millisecond date fields become
UTC `POSIXct` values unless metadata marks their time zone as unknown. In that
case, dates remain raw milliseconds with a warning, apart from UTC editor-tracking
creation and edit dates identified by layer metadata. Date-only fields become
`Date`; time-only and timestamp-offset fields remain strings.
The native CRS is read from metadata or the response; it is never assumed.
The spatial path keeps two-dimensional XY
geometry.

Retrieval requests a matching count and the applicable full or subset object-ID
manifest, then checks each bounded batch for missing, duplicate, or unexpected
IDs and transfer limits.
The client retries the specific generic ArcGIS query error observed
intermittently in HTTP 200 responses, with at most four attempts. It keeps the
same completeness checks after a retry.
By default it fetches object-ID batches. Explicit ordering uses supported
offset pagination with an object-ID tie breaker. A finite `limit` can
request a subset; provenance records its completeness. Full-manifest queries
matching more than one million records are rejected. With `integrity = "auto"`,
a finite preview of at most 1,000 rows on a source with more than 10,000 matches
uses ordered offsets and a returned-ID subset manifest when ordering and
pagination are supported and the preview is incomplete. Full retrievals and
`integrity = "full"` verify a full manifest; `limit = 0` uses only the matching
count. Provenance records this integrity path.
Advanced `query` options allow selected ArcGIS spatial, time, and version
filters while protecting pagination and response-shape parameters. See the
[retrieval guide](../vignettes/retrieval.Rmd) and
[ArcGIS query reference](https://developers.arcgis.com/rest/services-reference/enterprise/query-feature-service-layer/).

Both table and spatial results carry publisher, endpoint, ArcGIS item and
portal when available, validation status, original metadata, query, retrieval
time, row counts, and completeness through `tbod_provenance()`.
`timeout` applies to each HTTP attempt; `total_timeout` bounds the operation,
including metadata, queries, retries, and waits. Defaults are 120 seconds for
retrieval, 90 for discovery, and 60 for inspection. An explicit `Inf` disables
the overall deadline. Parsing checks the deadline when it finishes; native parsing
is not interrupted. Manifest checks detect changes in record membership during
retrieval; they cannot freeze attributes on a live service. No automatic runtime
data cache is maintained.

`tbod_download_dataset()` and `tbod_download_arcgis_layer()` provide an explicit resumable
disk path. They keep a full manifest and fixed query/schema/CRS signature, then
fetch, parse, and persist bounded feature batches as RDS tibbles or `sf` objects.
Immutable checksum checkpoints are published before atomic chunk renames, so
a stopped write can leave an unfinished checkpoint but not an accepted chunk
without its checksum. Resume rechecks the live manifest and schema, validates
completed chunks, and fetches missing batches. An exclusive directory lock
prevents concurrent writers; a lock left by a terminated process requires
explicit removal after confirming that writer has stopped. No all-page feature
list is accumulated. The ID manifest still uses memory and retains its
one-million-record limit. Chunk provenance describes each chunk; the returned
summary describes whole-download completeness. Attributes can change between
requests and across resumes. These downloads default to `total_timeout = Inf`.
The [test guide](../tests/README.md) describes offline tests and the bounded
live monitoring suite. [Validation](validation.md) records dated results,
including what each run did and did not check.

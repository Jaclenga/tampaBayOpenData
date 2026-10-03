# Architecture and research basis

The client discovers public ArcGIS layers from Tampa, St. Petersburg, Clearwater,
Hillsborough County, Pinellas County, and the Tampa Bay Regional Planning Council
organizations. A bundled registry
identifies 26 checked layers: 20 from Tampa and three each from St. Petersburg
and Clearwater. It does not host government data or provide analysis.
Tampa source terms and scope limits are recorded in
[Tampa source research](research-tampa.md). Each checked entry also records its
scope, terms, and verification date through `dataset_info(id)`.

## Design basis

The [nycOpenData source audit](research-nycOpenData.md) informed the small
discovery and retrieval API. That package uses a live Socrata catalog and a
single limited retrieval request. This client uses independently written ArcGIS
code, live portal search, a checked registry of stable IDs, and checked
pagination. It does not reuse NYC endpoints, SoQL, or title-derived keys.

The City's [GIS page](https://www.tampa.gov/technology-and-innovation/geographic-information-systems)
links its GeoHub. The City's [REST directory](https://arcgis.tampagov.net/arcgis/rest/services)
also exposes queryable FeatureServer and MapServer layers. Verified organization
metadata identifies the [St. Petersburg portal](https://csp.maps.arcgis.com/home/index.html)
and [Clearwater portal](https://cityofclearwater.maps.arcgis.com/home/index.html).
The configured county publishers are supported by official Hillsborough and
Pinellas GIS pages and their public organization metadata, recorded in the
portal registry's `evidence_url` and `metadata_url` fields.
The [regional planning council](https://tbrpc.org/arcgis-geohub/) links its own
GeoHub. Live discovery
searches the organizations' public ArcGIS service items and expands each service
into candidate layers and tables. Retrieval validates query responses and the
schema, and requires `Query` when the selected layer declares its capabilities.
This is broader than the Hubs' featured dataset collections, but portal indexing
can lag and some direct City services
have no matching public item. `get_arcgis_layer()` accepts a compatible direct
layer URL for those cases.

## Client design

`list_datasets()` and `search_datasets()` combine live discovery with the
checked registry by default. `source = "checked"` reads only
`inst/extdata/datasets.json` and remains offline and deterministic;
Catalog functions default to `jurisdiction = "all"`; codes or vectors filter
both checked and live results. County and regional jurisdictions are recognized
even when they have no checked entries. The live overlay
authenticates endpoints against all 26 checked layers regardless of the checked
entries selected for inclusion.

`source = "live"` returns only portal-listed layers. The public catalog marks
each row `checked` or `discovered`, deduplicates matching service/layer URLs,
and uses item ID plus layer ID for discovered keys. Titles are display text,
not identifiers. All six configured organizations are searched by default;
`portals` narrows them to `"city"`, `"tbrpc"`, `"stpete"`, `"clearwater"`,
`"hillsborough"`, or `"pinellas"`.
`list_portals()` reads the portal registry offline, exposing publisher identity
and source locations separately from the checked layer catalog. County portals
add live discovery without adding curated county layers.
The registry lives in `inst/extdata/portals.json`; adding a verified publisher
uses a registry entry rather than a new retrieval branch. Entries expose
official evidence URLs, portal metadata URLs, and verification dates.
The default `max_items = 25` caps service items per organization, while an explicit
`max_items = Inf` requests a full scan. Catalog attributes record whether discovery
completed, which portals were truncated, and how many items each portal scanned.
An inaccessible or malformed item is skipped without
discarding other results, and its issue is recorded on the result. If one
portal fails, discovery warns and retains results from the other selected
organizations. If every
portal fails, `source = "live"` errors; the default combined search warns and
returns checked rows.

Catalog filters use alternatives within a character vector and require matches
across separate filters. Publisher matching is exact and case-insensitive;
validation status distinguishes checked and discovered layers. Geometry filtering
distinguishes spatial layers and tables, excluding unknown geometry when used.
Topics match literal substrings in tags and categories; categories match a full
path or final label, both ignoring case. Catalog modification bounds accept whole
UTC dates or exact `POSIXct` instants and exclude missing modification times.
`modified_source` distinguishes live `portal_item` timestamps from upstream
timestamps saved as `checked_snapshot` values; neither establishes feature
freshness or replaces endpoint verification dates.
The checked overlay keeps stable identity, titles, source terms, and scope,
while retaining live tags, categories, and modification times on matching
endpoints. Live item and layer snapshots are retained separately in
`original_metadata$discovery`. Publisher and jurisdiction filters preselect organizations before
the service scan; other filters run after the catalog merge. A bounded scan can
therefore miss matching items, and its discovery attributes remain attached.

`dataset_info()` can inspect a checked ID offline or a discovered row or stable
ArcGIS ID. `get_dataset()` resolves those same inputs, retrieves the current
layer metadata, and applies one query engine for field and capability checks.
The three convenience wrappers call this path. Retrieval and download functions
retain a default `jurisdiction = "tampa"`; omitted jurisdiction also resolves a
uniquely named checked ID across cities. Discovered rows carry their own publisher
and jurisdiction.

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
offset pagination with an object-ID tie breaker; the current `fire-stations`
source supports this and exposes unqualified field names. A finite `limit` can
request a subset; provenance records its completeness. Full-manifest queries
matching more than one million records are rejected. With `integrity = "auto"`,
a finite preview of at most 1,000 rows on a source with more than 10,000 matches
uses ordered offsets and a returned-ID subset manifest when ordering and
pagination are supported and the preview is incomplete. Full retrievals and
`integrity = "full"` verify a full manifest; `limit = 0` uses only the matching
count. Provenance records this integrity path.
Advanced `query` options allow selected ArcGIS spatial, time, and
version filters while protecting parameters that control response shape and
pagination. See the
[ArcGIS query reference](https://developers.arcgis.com/rest/services-reference/enterprise/query-feature-service-layer/).

Both table and spatial results carry publisher, endpoint, ArcGIS item and
portal when available, validation status, original metadata, query, retrieval
time, row counts, and completeness through `dataset_provenance()`.
`timeout` applies to each HTTP attempt; `total_timeout` bounds the operation,
including metadata, queries, retries, and waits. Defaults are 120 seconds for
retrieval, 90 for discovery, and 60 for inspection. An explicit `Inf` disables
the overall deadline. Parsing checks the deadline when it finishes; native parsing
is not interrupted. Manifest checks detect changes in record membership during
retrieval; they cannot freeze attributes on a live service. No automatic runtime
data cache is maintained.

`download_dataset()` and `download_arcgis_layer()` provide an explicit resumable
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
The [test guide](../tests/README.md) describes offline tests, opt-in live
checks, and the twice-weekly bounded monitoring suite. Scheduled smoke runs
sample all checked sources and detect changes in selected schemas,
geometry, and provenance. They also check every configured portal and retrieve
county facilities through descriptors and stable IDs, including server projection
to EPSG:4326. Each retrieval requests at most two rows, and portal scans are
limited to one service item per publisher, with explicit request and operation
timeouts. Manual runs retain the full live integration suite.
[Validation](validation.md) records actual dated results. Configuring a schedule
does not establish future service availability.

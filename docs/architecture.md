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

### Module ownership and data flow

```text
User-facing tbod_* API
  -> discovery / checked catalog resolution
  -> ArcGIS transport -> metadata and schema validation
  -> pagination and retrieval -> typed results and provenance
```

Downloads share resolution, transport, schema checks, and the object-ID
manifest, then persist and validate bounded chunks. Catalog health is a
separate inspection workflow that uses transport and schema comparison but
does not retrieve features. The coverage dashboard transforms checked catalog
rows and optional health reports without making network requests.

| Module | Owns and important interface | Uses | Extension boundary |
| --- | --- | --- | --- |
| `api-discovery.R`, `catalog.R`, `live-discovery.R` | Public listing/search and stable discovery rows; checked/live overlay and portal scanning | Registry, ArcGIS transport | Add source discovery and catalog matching here; leave HTTP retries and feature paging to their owners. |
| `api-retrieval.R`, `api-download.R` | Public input normalization and calls into retrieval or download implementations; `.tbod_resolve_dataset_input()` shares stable-ID and direct-URL handling | Discovery, catalog resolution, operation budgets | Add entry-point options here; keep schema comparison and request execution in lower modules. |
| `arcgis.R` | `arcgis_request()` and `arcgis_http()` construct requests, validate responses, classify ArcGIS/HTTP failures, and apply bounded retries and response limits | `request-budget.R` deadlines and waits | Add transport behavior here; keep page completeness checks in `pagination.R`. |
| `request-budget.R` | `.operation_timeout()` and related deadline and wait helpers | Monotonic clock | Add operation-budget rules here; keep HTTP execution in `arcgis.R`. |
| `schema.R` | Metadata schema description, checked-schema comparison, and drift reports through `.compare_schema()` | ArcGIS layer metadata and checked snapshots | Add shared schema rules here; do not infer confirmed drift from transient failures. |
| `pagination.R` | `arcgis_fetch()` selects offset or object-ID batches and verifies ordering, membership, and completeness | ArcGIS query requests, parsing, schema-validated metadata | Add page integrity rules here; leave generic HTTP retries and schema drift checks elsewhere. |
| `download.R` | Resumable manifests, chunk persistence, checksums, locks, and completion markers | ArcGIS requests, schema checks, bounded feature parsing | Add disk recovery rules here; do not accumulate all feature pages in memory. |
| `catalog-health.R` | `tbod_check_catalog()` coordinates layer/service checks, schema comparison, optional query probes, and health classifications | ArcGIS transport, schema comparison, checked registry | Add diagnostic checks here; never edit checked catalog entries in response to a live result. |
| `coverage-dashboard.R` | Match optional health evidence to checked rows and prepare coverage summaries and HTML | Checked catalog and saved health reports | Add presentation transforms here; do not perform network checks or claim publisher-wide coverage. |

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

`tbod_check_catalog()` enumerates selected bundled entries and checks current
layer metadata against saved schemas. By default it makes one layer request
per entry and probes a service root only after a missing-layer response.
`probe_query = TRUE` also sends a zero-match count query to test the advertised
Query operation without reading features. The report records the UTC check
time, elapsed request time in milliseconds, HTTP status when available,
service and layer status, schema drift, and a failure reason. Elapsed request
time includes retries and a missing-layer root probe, but excludes deliberate
rate pauses. `query_status` is `not_checked`, `verified`, `failed`, or `unknown`.
The existing `status` retains detailed diagnoses; `health_state`
groups them as `healthy` (`healthy`), `degraded` (`schema_changed` or
`unsupported`), `unavailable` (`unavailable`), and `unknown` (`unknown`). A
failed query probe is degraded when the failure is confirmed and unknown when
it is transient, unless confirmed schema drift already makes the result
degraded. A missing layer is unavailable only when the service-root
probe confirms it is absent; ambiguous or malformed responses remain unknown.

The shared ArcGIS request path supplies finite retries and per-attempt and
overall timeouts. The checker also accepts a pause between entries. The
`tools/check-catalog.R` runner checks all bundled entries, using at most two
jurisdictions concurrently on Ubuntu and a sequential pause within each
jurisdiction. It runs the query probe and writes timestamped JSON, RDS, CSV, and
Markdown reports outside `inst/extdata`. The scheduled workflow runs daily,
uploads the reports as artifacts, and verifies that the checked registry and
schema snapshots were not changed. Neither network failures nor report
generation promote, remove, or edit catalog entries. The reports are
point-in-time observations of selected endpoints, not an inventory of all
publisher data or a guarantee of future availability or feature freshness.

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
The shared ArcGIS request path retries rate limits, selected HTTP 5xx
responses, temporary connection failures, timeouts, matching ArcGIS error
codes inside HTTP 200 responses, and the specific generic ArcGIS query error
observed intermittently in HTTP 200 responses. Retries
have a finite attempt cap, exponential backoff with jitter, and a bounded
wait for valid `Retry-After` delay or HTTP-date values. The package option
`tampaBayOpenData.max_retries` sets additional retries per failure sequence
(default 3, integer 0 through 10). The HTTP transport and ArcGIS
errors in HTTP 200 responses have separate bounded sequences; mixed failures
may therefore require more than four HTTP attempts. Both sequences obey the
overall operation budget. Specific ArcGIS query and permission errors are
returned immediately. The same completeness checks run after a successful
retry.
By default it fetches object-ID batches. Explicit ordering uses supported
offset pagination with an object-ID tie breaker. Layer metadata is used to
cap page size and check ordering and result-offset support. Truncated or
unexpectedly short ID batches are split into smaller requests; a singleton
that remains truncated or missing fails. Empty or repeated ordered pages,
duplicate IDs, and unexpected records also fail instead of yielding an
apparently complete result. A finite `limit`
can request a subset; provenance records its completeness. Full-manifest queries
matching more than one million records are rejected. With `integrity = "auto"`,
a finite preview of at most 1,000 rows on a source with more than 10,000 matches
uses ordered offsets and a returned-ID subset manifest when ordering and
pagination are supported and the preview is incomplete. Full retrievals and
`integrity = "full"` verify a full manifest; `limit = 0` uses only the matching
count. If an automatic preview finds advertised offsets unusable, it can
restart using the full manifest and object-ID batches; an explicit `order_by`
request errors instead. Provenance records this integrity path.
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
summary describes whole-download completeness. An atomic `complete.rds` marker
is written after all chunks validate. Resume removes an existing marker after
matching the saved manifest and before revalidating chunks, then recreates it
only after successful completion. Attributes can change between
requests and across resumes. These downloads default to `total_timeout = Inf`.
The [test guide](../tests/README.md) describes offline tests and the bounded
live monitoring suite. [Validation](validation.md) records dated results,
including what each run did and did not check.

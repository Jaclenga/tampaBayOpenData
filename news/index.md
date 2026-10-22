# Changelog

## tampaBayOpenData (development version)

- Discovery recognizes `Query` capability tokens with spaces or case
  changes, accepts trailing slashes on service and layer URLs, and
  reports missing stable item IDs as unavailable.
- Spatial results accept WKT2-only coordinate references. Schema checks
  detect changed WKT definitions even when reported WKIDs match.
- Ordered pagination verifies big-integer sort keys without rounding.
  Public ArcGIS URL validation rejects single-label hosts.

## tampaBayOpenData 0.1.0

CRAN release: 2026-10-21

- Validates comparable sort keys within and across ordered pages,
  including internally requested sort fields, and rejects detected
  ordering violations. ArcGIS error objects with code 429 now respect
  valid `Retry-After` headers on HTTP 200 responses. Catalog health
  reports removed object-ID fields as schema drift; transient service
  failures remain transient during schema and stable-ID checks.
  Checked-catalog fallback results retain live discovery failure
  details. Source-dependent NULL placement and text collation can limit
  ordering verification.
- Retries rate limits, temporary connection failures and timeouts, HTTP
  500, 502, 503, and 504, ArcGIS error objects with those codes inside
  HTTP 200 responses, and generic transient ArcGIS query errors with
  bounded exponential backoff and jitter. Valid `Retry-After` delays and
  HTTP dates are honored within a bounded wait. Permanent HTTP and
  ArcGIS errors fail without retrying. Error messages identify the
  failed request and recovery attempts.
  `options(tampaBayOpenData.max_retries = 3L)` controls additional
  retries per HTTP transport or ArcGIS-body error sequence (integer 0
  through 10); existing public function signatures are unchanged.
- Uses service-advertised record limits and pagination capabilities.
  Where ordering and result offsets are unavailable, retrieval uses
  object-ID batches. A small automatic preview can fall back to
  object-ID batches if a service advertises but ignores offsets;
  explicit ordering still errors. Truncated or unexpectedly short
  object-ID batches are split. Persistently missing records, duplicate
  or unexpected IDs, and repeated ordered pages stop with an integrity
  error. Downloads retain validated chunks for resumption and write an
  atomic `complete.rds` marker only after all chunks validate. Resume
  clears that marker before chunk revalidation and recreates it on
  success.
- Includes a checked catalog of 52 ArcGIS layers from Tampa,
  St. Petersburg, Clearwater, Hillsborough County, Pinellas County, and
  the Tampa Bay Regional Planning Council. The [catalog
  policy](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/checked-catalog-policy.md)
  records selection criteria, source limits, candidate decisions, and
  topic coverage. The catalog is selective; it does not mirror publisher
  data.
- Exports 16 consistently named `tbod_*` functions for discovery,
  inspection, retrieval, and download. Twelve unprefixed development
  names were removed before the first release. See the [API migration
  guide](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/api-migration.md)
  for their replacements.
- Searches the six configured public ArcGIS organizations as well as the
  offline checked catalog. Catalog searches support jurisdiction,
  publisher, validation status, geometry, topic, category, and item-date
  filters. Live scans default to 25 service items per organization and
  report truncation, issues, and failed portals. A bounded scan can miss
  matches.
- Adds
  [`tbod_discover()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_discover.md)
  for another public ArcGIS sharing REST root, FeatureServer, MapServer,
  or layer URL. Queryable MapServer layers and FeatureServer layers use
  the same retrieval API. Discovered rows retain live item dates, tags,
  and categories; checked matches retain package IDs, scope, and terms.
  Direct URLs have `not_checked` status.
- Compares current fields, object ID, geometry, CRS, and endpoint
  metadata against saved schemas before checked retrieval and downloads.
  Added fields or changed aliases warn; removed or type-changed fields,
  geometry or CRS changes, and vanished layers stop retrieval.
  [`tbod_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_schema.md)
  and
  [`tbod_check_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_check_schema.md)
  expose the metadata and drift report.
- Retrieves tibbles or optional `sf` results with field selection,
  ArcGIS filters, ordering, row limits, and source provenance. Count and
  object-ID checks catch missing, duplicate, or unexpected pages.
  Eligible small previews can use a subset manifest; complete retrieval
  checks the full matching manifest when records exist; zero-match
  retrieval and downloads skip the object-ID request and report
  count-only integrity. Deliberate subsets remain marked incomplete.
  Sources can still change record attributes between requests.
- Parses declared ArcGIS field types, dates, geometry, and spatial
  references. Date fields with unknown time-zone semantics remain raw
  milliseconds, except UTC editor-tracking fields identified by
  metadata. Request and operation timeouts bound live work.
- Adds resumable RDS chunk downloads. Resuming rechecks current schema
  and full record membership, verifies saved checksums and provenance,
  and skips completed chunks. Atomic writes and an exclusive directory
  lock protect progress; live record attributes may differ across chunks
  or sessions.
- Moves Tampa `parks` and `fire-stations` to their dedicated services
  after matching source IDs. The current fire-station fields are
  unqualified (for example, `NAME`); older joined `GIS.GovServiceInfo.*`
  fields are unavailable. Terms were updated for the replacement
  endpoints. The source data is not labeled CC0 by the package.
- Adds offline catalog and schema checks, bounded twice-weekly live
  checks across all six publishers, and a separate manual integration
  suite. The [validation
  record](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/validation.md)
  gives dated evidence; live services can change afterward. CI actions
  are pinned to verified commits.
- Adds
  [`tbod_check_catalog()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_check_catalog.md)
  for a point-in-time live metadata and schema report across selected
  checked layers. It returns one diagnostic row per layer, including
  unavailable, unsupported, changed-schema, and unknown outcomes,
  without changing the bundled catalog. Missing schema baselines remain
  reportable as unknown; confirmed schema drift remains visible when
  Query capability is unreported. A separate weekly workflow saves
  timestamped RDS, CSV, and Markdown reports as run artifacts.
- Generates the Data coverage dashboard from the bundled checked catalog
  and an optional recent catalog-health report. Missing, stale, and
  unknown health results display as unverified; the site build makes no
  live ArcGIS requests. The [dashboard
  methodology](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/coverage-dashboard.md)
  explains the counts, limitations, and local build command.
- Adds three offline-build-friendly tutorials for housing and
  development, Hillsborough water-quality observations, and Tampa
  capital projects. Each uses checked catalog IDs and source fields,
  shows reproducible live analysis code and a `ggplot2` visualization,
  and explains source and sampling limits.
- Rejects malformed metadata and query responses, duplicate JSON keys,
  conflicting CRS identifiers, and invalid numeric object IDs. HTTP
  requests do not follow redirects; retry waits are capped at 30
  seconds, accepted responses at 50 MiB, and JSON nesting at 64
  containers. JSON is parsed as literal text, and spatial WKT must be
  inline. The package requires httr2 1.2.3 or later and jsonlite 1.6.0
  or later; older native curl builds still need decompression security
  updates.
- Credits `nycOpenData` as design inspiration. The ArcGIS client code is
  independently implemented.

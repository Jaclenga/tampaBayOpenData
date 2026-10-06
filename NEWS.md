# tampaBayOpenData 0.1.0

- Bundles 52 checked ArcGIS layers from Tampa, St. Petersburg, Clearwater,
  Hillsborough County, Pinellas County, and the Tampa Bay Regional Planning
  Council. The [catalog policy](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/checked-catalog-policy.md)
  records selection criteria, source limits, candidate decisions, and topic
  coverage. The catalog is selective; it does not mirror publisher data.
- Exports 15 consistently named `tbod_*` functions for discovery, inspection,
  retrieval, and download. Twelve unprefixed development names were removed
  before the first release. See the [API migration
  guide](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/api-migration.md)
  for their replacements.
- Searches the six configured public ArcGIS organizations as well as the
  offline checked catalog. Catalog searches support jurisdiction, publisher,
  validation status, geometry, topic, category, and item-date filters. Live
  scans default to 25 service items per organization and report truncation,
  issues, and failed portals. A bounded scan can miss matches.
- Adds `tbod_discover()` for another public ArcGIS sharing REST root,
  FeatureServer, MapServer, or layer URL. Queryable MapServer layers and
  FeatureServer layers use the same retrieval API. Discovered rows retain
  live item dates, tags, and categories; checked matches retain package IDs,
  scope, and terms. Direct URLs have `not_checked` status.
- Compares current fields, object ID, geometry, CRS, and endpoint metadata
  against saved schemas before checked retrieval and downloads. Added fields
  or changed aliases warn; removed or type-changed fields, geometry or CRS
  changes, and vanished layers stop retrieval. `tbod_schema()` and
  `tbod_check_schema()` expose the metadata and drift report.
- Retrieves tibbles or optional `sf` results with field selection, ArcGIS
  filters, ordering, row limits, and source provenance. Count and object-ID
  checks catch missing, duplicate, or unexpected pages. Eligible small
  previews can use a subset manifest; complete retrieval checks the full
  matching manifest. Deliberate subsets remain marked incomplete. Sources
  can still change record attributes between requests.
- Parses declared ArcGIS field types, dates, geometry, and spatial references.
  Date fields with unknown time-zone semantics remain raw milliseconds, except
  UTC editor-tracking fields identified by metadata. Request and operation
  timeouts bound live work.
- Adds resumable RDS chunk downloads. Resuming rechecks current schema and
  full record membership, verifies saved checksums and provenance, and skips
  completed chunks. Atomic writes and an exclusive directory lock protect
  progress; live record attributes may differ across chunks or sessions.
- Moves Tampa `parks` and `fire-stations` to their dedicated services after
  matching source IDs. The current fire-station fields are unqualified (for
  example, `NAME`); older joined `GIS.GovServiceInfo.*` fields are unavailable.
  Terms were updated for the replacement endpoints. The source data is not
  labeled CC0 by the package.
- Adds offline catalog and schema checks, bounded twice-weekly live checks
  across all six publishers, and a separate manual integration suite. The
  [validation record](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/validation.md)
  gives dated evidence; live services can change afterward. CI actions are
  pinned to verified commits.
- Rejects malformed metadata and query responses, duplicate JSON keys,
  conflicting CRS identifiers, and invalid numeric object IDs. HTTP requests
  do not follow redirects; retry waits are capped at 30 seconds, accepted
  responses at 50 MiB, and JSON nesting at 64 containers. JSON is parsed as
  literal text, and spatial WKT must be inline. The package requires
  httr2 1.2.3 or later and jsonlite 1.6.0 or later; older native curl builds
  still need decompression security updates.
- Credits `nycOpenData` as design inspiration. The ArcGIS client code is
  independently implemented.

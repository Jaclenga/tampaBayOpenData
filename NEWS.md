# tampaBayOpenData 0.1.0

- Adds Hillsborough County and Pinellas County publishers to live discovery and
  exposes the six configured organizations through offline `list_portals()`.
  The checked catalog remains 26 city layers.
- Makes `jurisdiction = "all"` the catalog default and adds jurisdiction,
  publisher, validation status, geometry, topic, category, and item-modification
  filters to listing and searching. Publisher and jurisdiction filters narrow
  portal scans; other filters retain the bounded-scan caveat. Retrieval and
  download jurisdiction defaults remain Tampa. Live checked matches preserve
  current item dates, tags, and categories alongside checked identity and terms.
  Catalog `modified_source` distinguishes live item timestamps from saved
  checked-source timestamps.
- Adds twice-weekly bounded live smoke checks for checked city, regional, and
  county sources, including county descriptor, stable-ID, and projected geometry
  retrieval, while preserving manually triggered full
  integration checks. Offline package checks continue to block live requests.
- Aligns the README, vignette, and architecture documentation on conditional
  Query capabilities, declared date types, and UTC editor-tracking exceptions
  when other dates have unknown time-zone semantics.
- Expands checked coverage to 26 layers across Tampa, St. Petersburg, and
  Clearwater, and adds the two municipal ArcGIS organizations to live discovery.
  `jurisdiction = "all"` selects all checked layers. Live checked overlays are
  matched against the full registry.
- Limits default live discovery to 25 service items per organization, reports
  partial-scan attributes, and adds overall operation deadlines. Eligible small
  previews verify a returned-ID subset manifest; explicit full integrity and
  complete retrieval continue to verify the full matching manifest.
- Adds `download_dataset()` and `download_arcgis_layer()` for resumable local
  RDS chunks. Each resume rechecks current metadata and full record membership,
  validates chunk checksums and provenance, and skips completed feature batches.
  Atomic writes and an exclusive directory lock protect saved progress; chunk
  attributes can still vary across requests and resumed sessions.
- Introduces an offline, verified City of Tampa dataset registry and the
  `list_datasets()`, `search_datasets()`, and `dataset_info()` discovery API.
- Expands the curated catalog to 20 layers, adding fire stations, bicycle and
  truck routes, recycling and water service areas, historic sites, police
  districts, zoning, redevelopment areas, and transportation safety layers.
- Adds live discovery across public Tampa, St. Petersburg, Clearwater, and
  Tampa Bay Regional Planning Council ArcGIS service items. The checked layers remain an
  offline `checked` overlay; other portal layers are marked `discovered`.
- Lets the generic `get_dataset()` retrieve a discovery row or stable ArcGIS
  item/layer ID, and adds `get_arcgis_layer()` for a direct compatible layer URL.
  Provenance records the portal, item ID, validation status, and source metadata.
- Adds generic retrieval from ArcGIS FeatureServer and queryable MapServer
  layers, field selection, server-side filters, ordering, and explicit row limits.
- Checks matching counts and object-ID manifests against retrieved batches to
  detect truncation, missing records, and duplicate pages.
- Retries the City's intermittent generic ArcGIS query error within a fixed
  limit, while preserving count and ID checks; live samples cover all 20 Tampa
  layers.
- Moves `parks` to the dedicated ParksPolygons service and `fire-stations` to
  the Fire service after matching their IDs against the earlier Location layers.
  Fire-station fields are now unqualified (for example, `NAME`), and joined
  `GIS.GovServiceInfo.*` fields are no longer available. Source terms were
  updated for the exact replacement endpoints; neither is labeled CC0.
- Returns tibbles by default and `sf` objects on request, using declared field
  types, date metadata, geometry, and spatial references.
- Attaches source, retrieval, query, and completeness provenance, exposed through
  `dataset_provenance()`.
- Adds thin convenience functions for permits, development cases, and capital
  projects.
- Includes deterministic tests, an offline-safe introductory vignette, platform
  checks, and separate scheduled and manual live integration checks.
- Exercises HTTP request construction and all 26 checked source schemas
  offline, and rejects malformed timezone and query-capability metadata before
  retrieving features.
- Separates pagination, declared-type parsing, and geometry decoding into
  focused helpers, passes retrieval state explicitly, and shares native CRS
  lookup while preparing advanced query parameters once.
- Accepts closed polygon rings with equivalent integer and decimal coordinates
  and rejects fractional or nonfinite numeric big integers before formatting.
- Rejects nested duplicate JSON keys, malformed metadata/aliases, invalid
  manifest flags, changed page ID declarations, named coordinate objects, and
  conflicting resolved WKIDs while preserving supported aliases and WKT.
- Requires httr2 1.2.3 or later for the configured transport retry option and
  locale-independent UTF-8 query encoding; tests the prepared POST bytes.
- Parses HTTP bodies as literal JSON with jsonlite 1.6.0 or later, and permits
  only inline spatial WKT, preventing response text from selecting files or URLs.
- Disables HTTP redirects, bounds server-requested retry waits at 30 seconds,
  rejects JSON nesting beyond 64 containers, and limits accepted responses to
  50 MiB. Older native curl builds still need decompression security updates.
- Pins CI actions to verified commits and configures weekly action updates.
- Credits `nycOpenData` as design inspiration. Client code is independently
  implemented for Tampa's ArcGIS services.

# tampaBayOpenData 0.1.0

- Introduces an offline, verified City of Tampa dataset registry and the
  `list_datasets()`, `search_datasets()`, and `dataset_info()` discovery API.
- Expands the curated catalog to 20 layers, adding fire stations, bicycle and
  truck routes, recycling and water service areas, historic sites, police
  districts, zoning, redevelopment areas, and transportation safety layers.
- Adds live discovery across public City of Tampa and Tampa Bay Regional
  Planning Council ArcGIS service items. The 20 bundled City layers remain an
  offline `checked` overlay; other portal layers are marked `discovered`.
- Lets the generic `get_dataset()` retrieve a discovery row or stable ArcGIS
  item/layer ID, and adds `get_arcgis_layer()` for a direct compatible layer URL.
  Provenance records the portal, item ID, validation status, and source metadata.
- Adds generic retrieval from ArcGIS FeatureServer and queryable MapServer
  layers, field selection, server-side filters, ordering, and explicit row limits.
- Checks matching counts and object-ID manifests against retrieved batches to
  detect truncation, missing records, and duplicate pages.
- Retries the City's intermittent generic ArcGIS query error within a fixed
  limit, while preserving count and ID checks; live samples cover all 20 layers.
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
  checks, and a separate manual workflow for live integration tests.
- Exercises HTTP request construction and all 20 verified source schemas
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

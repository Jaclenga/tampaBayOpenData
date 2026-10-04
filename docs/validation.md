# Dated validation record

These are local results on Windows 11 with R 4.5.1 or R 4.6.1 as noted.
Each result describes the source and dependencies used for that run; live
services can change.

## rOpenSci preparation (2026-10-03)

After the six publisher data-page links and user-agent override were added,
the fresh archive at
`.artifacts/ropensci-fixes-2026-10-03/tampaBayOpenData_0.1.0.tar.gz`
(SHA-256 `48e75f3fde5e4b44dd574aa58ed3b8050bd68e35304c6609950748d82b042024`)
completed full local `R CMD check --as-cran` with R 4.6.1: **zero errors,
zero warnings, and one environment NOTE**. The offline tests passed 3,281
assertions with zero failures or warnings and 18 expected live skips.
Examples, vignette rebuilding, and PDF and HTML manuals passed. The local
`.artifacts/ropensci-fixes-2026-10-03/tampaBayOpenData.Rcheck/00check.log`
records that R could not verify the system clock remotely.

This run placed the local TinyTeX, qpdf, HTML Tidy, and Pandoc binaries on
`PATH`. It set `_R_CHECK_CRAN_INCOMING_REMOTE_=FALSE` because this shell cannot
reach external sites, so it did not check public URLs or the ORCID remotely.
The earlier `.check/codex-submission-audit/tampaBayOpenData.Rcheck/00check.log`
recorded one error, two warnings, and four notes when PDF tools were missing
from `PATH` and external requests failed. Its tests and vignette rebuild had
passed; the post-edit full check above also passed both manuals with the
available local tools.

The stored `pkgcheck` 0.3.2 result is historical: it ran on commit `a3f7458`
and measured 95.17% coverage then. Its missing `_pkgdown.yml` and ORCID
findings no longer match the working source. A post-edit `pkgcheck` rerun was
attempted with local Universal Ctags and GNU Global, but stopped while
downloading GitHub data through the blocked network connection. The local
`.check/ropensci-fixes-pkgcheck-20261003-attempt5.log` records the
`127.0.0.1:9` connection failure. No new `pkgcheck` result was produced.
The [five-platform CI run](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/37164594446)
passed on an earlier revision; the post-edit source has not run in CI.

## Publisher registry and search filters (2026-10-02)

The publisher configuration now lives in `inst/extdata/portals.json` and is
available offline through `list_portals()`. It contains six organizations:
Tampa, TBRPC, St. Petersburg, Clearwater, Hillsborough County, and Pinellas
County. County identities were verified through the
[Hillsborough open-data page](https://hcfl.gov/about-hillsborough/open-data-and-gis),
[Pinellas GIS page](https://pinellas.gov/services/maps-gis/), and public ArcGIS
organization metadata. St. Petersburg was already configured before this
revision. No checked county datasets were added; the checked catalog remains
26 selected city layers, and county results retain `discovered` provenance.

The complete offline suite passed **3,246 assertions**, with zero failures or
warnings and 18 expected live skips, in 103.8 seconds on R 4.6.1 with
`LC_ALL=C`. A synthetic seventh publisher exercised the same discovery and
descriptor/stable-ID retrieval code using configuration alone. A separate
test used two organizations sharing one ArcGIS API root and verified their
organization-scoped searches and distinct publisher attribution.

The fresh source archive built its offline vignette and passed full
`R CMD check --as-cran`: **zero errors, zero warnings, and one expected
`New submission` NOTE**. Its package tests repeated all 3,246 passing offline
assertions; examples, rebuilt vignette outputs, and PDF and HTML manuals also
passed. The checked source matched the final package files. The archive is
`.artifacts/release-publishers/tampaBayOpenData_0.1.0.tar.gz`, with SHA-256
`0b35ef1864e6c3ff4cd7c8b27c510127f45304edec5060876a9c0e0a3cdd4894`.

The [county live tests](../tests/testthat/test-live-county-discovery.R) passed
**102 assertions**, with zero failures, warnings, or skips, in 11.0 seconds.
Bounded searches for Hillsborough public libraries and Pinellas fire stations
selected current discovery rows. Tabular retrieval through both a descriptor
and a stable ID returned at most two records per call; spatial retrieval by
stable ID returned nonempty EPSG:4326 point geometry. Source, publisher,
jurisdiction, unique IDs, row counts, and completeness agreed. Further searches
combined publisher, validation status, spatial, UTC modification-day, and
available tag/category filters from the current rows. They retained the same
source URLs and scanned only the selected county. The summaries in ignored
artifacts retain measurements rather than feature records.

Catalog functions now default to `jurisdiction = "all"`. Jurisdiction and
publisher filters apply to checked and live rows and select organizations
before HTTP requests. The remaining facets filter the merged catalog: checked
or discovered status, spatial layers or tables, literal topic substrings,
category paths or labels, and modification dates. Character alternatives use
OR within one filter; filters and the query use AND. Date bounds include
whole UTC days for Date or YYYY-MM-DD values, or exact POSIXct instants.
Unknown modification times are excluded only when a date bound is supplied.
Live metadata can enrich checked matches without replacing their checked
identity or terms; `modified_source` distinguishes portal-item timestamps
from saved checked snapshots. These timestamps do not establish row freshness.

Facets applied after a capped scan can miss matching older items. Scan
completeness attributes remain attached even to empty filtered results;
`max_items = Inf` and a suitable time budget are required for an exhaustive
scan. Registering an organization does not prove comprehensive coverage or
validate every public item. The scheduled live gate now includes the bounded
county retrieval/filter tests alongside the existing source-monitoring suite.
It takes effect after pushing the workflow to the default branch; the new
source still needs the configured cross-platform CI matrix after pushing.

## Earlier regional coverage and resource controls (2026-10-02)

That revision had 26 checked layers: 20 Tampa, three St.
Petersburg, and three Clearwater. Public discovery searched those three
municipal organizations and the Tampa Bay Regional Planning Council. Checked
coverage is selected with `jurisdiction`; `portals` selects discovery sources.
These additions establish checked retrieval paths for selected municipal
layers, rather than comprehensive coverage of each city or the whole region.

On R 4.6.1 with `LC_ALL=C`, the complete offline suite passed **3,041
assertions**, with zero failures or warnings and 14 expected opt-in live skips
in the fresh archive check. These are assertion counts, including repeated
schema and pagination checks; they do not represent 3,041 independent live
scenarios. The suite includes 95 assertions for local chunk downloads, interruptions,
expired deadlines, resumed retrieval, changed manifests and queries, altered
chunks, exclusive locks, and recovery around atomic file writes.

The final fresh archive built its offline vignette and passed full
`R CMD check --as-cran` with **zero errors, zero warnings, and one expected
`New submission` NOTE**. Package tests, examples, rebuilt vignette output, and
PDF and HTML manuals passed. The check used the current package source,
including the final documentation edits; the release-file comparison found
no differences from the staged source. It started on October 2 at 22:43 EDT
and used the same qpdf, Pandoc, Tidy, and TinyTeX tools recorded below.
The checked archive is
`.artifacts/release-regional-ready/tampaBayOpenData_0.1.0.tar.gz`, with SHA-256
`d28a0d9128c9fa825958c4217a899aaf9f4791b47558e9fc299a40d74a71a97a`.
Generated download chunks and `development-cases.rds` are absent from its
release source.

The new bounded [live monitoring suite](../tests/testthat/test-live-monitoring.R)
passed **420 assertions**, with zero failures, warnings, or skips, in 50.0
seconds. It sampled all 26 checked layers as EPSG:4326 `sf` objects, checked
source identity, selected fields, geometry, unique IDs, counts, provenance, and
completeness, and tested all four portals with at most one service item each.
Each retrieval requested at most two feature rows with `page_size = 1`, a
15-second per-attempt timeout, and a 45-second overall budget. It also sampled
a discovered regional layer. The run used sf 1.1.3 and testthat 3.3.2.

A separate live comparison used the St. Petersburg streets layer's 12,853
matches with `fields = "OBJECTID"`, `limit = 2`, and `page_size = 1`. Default
`integrity = "auto"` returned the same two IDs as `integrity = "full"`, but
its subset manifest returned only two IDs in 62 decoded response bytes. The
full manifest returned 12,853 IDs in 102,872 bytes, a 99.94% reduction in that
response's size. Both paths made five HTTP calls and marked the sample
incomplete. Observed elapsed times were 1.110 and 0.990 seconds respectively;
one run per path provides no evidence of a speed improvement. Across all
responses, decoded body sizes were 36,947 and 139,699 bytes. The retained
summary contains request parameters and aggregate measurements, not feature
attribute or geometry records.

The live `download_dataset()` check filtered the same streets layer to two
current IDs, using one-row chunks. The initial call made two feature requests
and saved two chunks. Repeating it rechecked metadata, count, and the full
filtered manifest, then made **zero feature requests**. Both summaries were
complete; chunk filenames, checksums, and modification times stayed unchanged.
Downloaded files and measurement summaries remain in ignored local artifacts.
Full ID manifests remain subject to the one-million-match limit; chunking
bounds feature accumulation but does not impose a fixed byte limit on memory.

Default discovery scans at most 25 service items per organization and exposes
whether its result is complete. Small previews of large layers can validate
only their returned IDs. Retrieval, discovery, and metadata inspection now
share an overall operation deadline; HTTP attempts and retry waits use its
remaining budget. R and native parsing are checked after returning, rather
than interrupted during computation. Resumable downloads preserve completed
chunks after a finite deadline and reject changed query, schema, CRS, or ID
membership. Attribute values can still change across requests and resumes.

The [live workflow](../.github/workflows/live-check.yaml) schedules the small
monitoring suite on Tuesdays and Fridays at 06:17 UTC and retains the full
live suite for manual runs. The schedule takes effect when this workflow is
pushed to the default branch. This local run establishes current working
paths; sustained reliability requires evidence from future scheduled runs.

The [latest committed cross-platform run](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/37088075504)
passed Linux release, devel, and oldrel-1, Windows release, and macOS release
for `5f6bec32d887761ae474ccfc082e0e159f2f1786`. That commit predates this
regional and resource work. The current uncommitted changes still need the
same CI matrix after they are pushed; the earlier success does not validate
this revision across platforms.

## Historical runs

| Date | Offline testthat | Build and local check |
| --- | --- | --- |
| 2026-09-29 | 967 assertions; no failures or test warnings; two opt-in live tests skipped | `R CMD build .` succeeded, including the offline vignette. `R CMD check --no-manual` on the source archive reported zero errors, warnings, and notes. |
| 2026-09-30 | 1,037 assertions; no failures or test warnings; two opt-in live tests skipped | Rebuilt source archive and `R CMD check --no-manual` reported Status: OK. |
| 2026-10-02, before catalog expansion | 1,037 passed; zero failures or warnings; two live tests skipped. | Build and package check were not rerun for this result. |
| 2026-10-02, 11-layer catalog | 1,195 passed; zero failures or warnings; three opt-in live tests skipped. | Source archive built with the vignette; `R CMD check --no-manual` reported Status: OK. |
| 2026-10-02, expanded offline cases | 1,642 passed; zero failures or warnings; three opt-in live tests skipped. | Source archive built with the vignette; `R CMD check --no-manual` reported Status: OK with `LC_ALL=C` on Windows. |
| 2026-10-02, 20-layer catalog | 2,074 passed; zero failures or warnings; four opt-in live tests skipped. | Source archive built with the vignette; `R CMD check --no-manual` reported Status: OK with zero errors, warnings, or notes. |
| 2026-10-02, live recheck and retry fix | 2,085 passed; zero failures or warnings; five opt-in live tests skipped. | Source archive built with the vignette; `R CMD check --no-manual` reported Status: OK with zero errors, warnings, or notes. |
| 2026-10-02, Location source migration | 2,088 passed; zero failures or warnings; five opt-in live tests skipped. | Source archive built with the vignette; `R CMD check --no-manual` reported Status: OK with zero errors, warnings, or notes. |
| 2026-10-02, live discovery refactor | 2,228 passed; zero failures or warnings; six opt-in live tests skipped. | Source archive built with the offline vignette; `R CMD check --no-manual` reported Status: OK with zero errors, warnings, or notes. |
| 2026-10-02, catalog and parsing bug fixes | 2,271 assertions passed; zero failures or test warnings; six opt-in live tests skipped. | No build or package check was run for this interim revision. |
| 2026-10-02, CRS alias regression | 2,275 assertions passed on R 4.6.1; zero test failures or warnings; six opt-in live tests skipped. | Source archive built with its vignette. Full `R CMD check --as-cran`, including PDF and HTML manual checks, reported zero errors, zero warnings, and one `New submission` NOTE. |
| 2026-10-02, other-city compatibility tests | 2,416 assertions passed on R 4.6.1; zero failures or warnings; ten opt-in live tests skipped. | No build or package check was rerun for this test expansion. The four new municipal live tests passed 214 assertions without failures, warnings, or skips. |
| 2026-10-02, regional sources and resource controls | 3,041 assertions passed on R 4.6.1; zero failures or warnings; 14 opt-in live tests skipped. | Fresh source built with its vignette; full `R CMD check --as-cran` passed with zero errors, zero warnings, and one expected `New submission` NOTE. Bounded live monitoring passed 420 assertions; separate live preview and resume checks passed. |
| 2026-10-02, publisher registry and catalog filters | 3,246 assertions passed on R 4.6.1; zero failures or warnings; 18 opt-in live tests skipped. | Fresh archive passed full `R CMD check --as-cran`, including vignette and both manual formats, with zero errors, zero warnings, and one expected `New submission` NOTE. Bounded county discovery, retrieval, geometry, and filter tests passed 102 live assertions. |

The September 30 follow-up included fixes for UTC editor tracking dates,
response `attributes` validation, transient HTTP retries, and registry shape
checks. The September 29 work included the [bug scan](bug-scan.md) and
[security audit](security-audit.md). Those reports retain the finding-level
evidence and their own historical assertion counts.

The later October 2 offline run added regression coverage for checked-layer
labels in live search, incomplete spatial coordinates, exact geometry and CRS
response keys, and exact Query capability tokens. The 2,228-assertion archive
check predated those fixes.

The R 4.6.1 run added coverage for the water-service-area layer's legacy and
latest WKID aliases after a previous Linux and macOS CI run treated the two
identifiers as conflicting. The final full check used a fresh R 4.6.1 library
with httr2 1.3.0, jsonlite 2.0.0, tibble 3.3.1, sf 1.1.3, and testthat 3.3.2.
Package tests, examples, vignettes, and both manual formats passed. Online
incoming and future-timestamp checks were enabled; the only NOTE identified
the package as a new submission.

The final check ran with `LC_ALL=C`, qpdf 12.4.2, Pandoc 3.1.1, HTML Tidy
5.8.0, and TinyTeX with the Courier font and index builder available. It
started at 2026-10-03 00:00:29 UTC (October 2 in America/New_York). The fresh
archive excludes `development-cases.rds`; Git and package-build ignores now
exclude future copies. The checked `tampaBayOpenData_0.1.0.tar.gz` has SHA-256
`3736b68db7045e50fe391e68bf3afef59f5ac8d1a9484843ef2086b5802a209a`.

A bounded live smoke test of the current working source passed on October 2
with R 4.6.1, after the CRS alias fix. All 20 checked City IDs returned one or
two `sf` records in EPSG:4326, with unique object IDs and consistent count,
ID-manifest, and provenance checks. A native
EPSG:6443 capital-projects sample agreed with the service's EPSG:4326
projection within 1e-5. A City housing search and a regional live listing,
each limited to two portal items, returned three and two layers respectively,
with no recorded discovery issues or failed portals. Two-row spatial retrieval
succeeded from both discovery descriptors, a City stable ArcGIS ID, and a
regional direct layer URL; the direct result was marked `not_checked`. The
smoke test used `limit = 2` and `page_size = 1` for checked layers, so it did
not repeat full feature downloads. The client still fetched matching counts
and full object-ID manifests for those requests.

On October 2, the three new catalog entries were checked against public City
metadata, counts, object-ID manifests, and bounded R client queries. A
projected fire-station sample returned EPSG:4326 geometry. The opt-in live
suite then passed 58 assertions with no failures or skips. Its observed counts
and source limits are in [Tampa source research](research-tampa.md); live
results do not guarantee future availability or fixed row counts.

The later offline expansion exercised registry boundaries and all 11 saved
source schemas, retry and response variants, malformed ID manifests, page and
limit boundaries, and point, line, and polygon results for the three new layers.
The package check used the saved fixtures; it did not repeat the live suite.

For the 20-layer catalog, the nine further additions were checked against City
metadata, complete count and object-ID responses, two distinct ordered pages,
and one WGS 84 geometry sample per layer. The package check exercised their
saved schemas and synthetic records offline. The opt-in R client live suite was
not run for these nine during this check.

In the later October 2 live recheck, bounded `get_dataset()` calls returned one
or two real `sf` rows in EPSG:4326 for all 20 catalog layers. Each call checked
unique IDs, count and ID manifests, row counts, and provenance. The expanded
opt-in live suite passed 232 assertions with no failures or skips, including a
complete multi-page permit retrieval. Other layers were sampled, not fully
downloaded. Identical public queries to the City's Location service sometimes
returned ArcGIS error 400 in an HTTP 200 body and sometimes succeeded. The
client now retries only that generic query error, up to four total attempts;
count, ID, and feature consistency checks still run. A later repeat of the
`parks` and `fire-stations` samples failed when the Location service kept
returning that error through all retries. The client reported the upstream
failure rather than returning incomplete data. These dated runs do not
guarantee future upstream availability or feature freshness.

After moving `parks` to ParksPolygons/0 and `fire-stations` to Fire/10, bounded
live `get_dataset()` queries again returned EPSG:4326 `sf` samples for all 20
catalog layers with unique IDs and consistent provenance. The opt-in live suite
passed 232 assertions with no failures or skips. Full spatial downloads
returned all 208 parks and all 28 fire stations with complete provenance. The
replacement layers' full ID sets matched their former Location layers; selected
park attributes matched across all 208 records, and one fire station's name and
coordinates matched. Full ID-only client downloads also matched source counts
for bike lanes (6,858), truck routes (2,527), and zoning districts (3,933);
an ordered 50-row truck-route request worked across five pages. The new Fire
source uses unqualified fields and omits the former joined service-information
fields. Full geometry downloads for the other catalog layers were not run in
this validation pass.

The live-discovery check searched the City and regional planning council ArcGIS
organizations, expanded their paginated service items, and returned 323 distinct
portal layer URLs. The merged public `list_datasets()` result contained 327
rows: 20 checked and 307 discovered. One City portal item pointed to an HTTP
403 service; discovery recorded that issue and returned the other layers. A
live City housing search found four candidate layers; its first result returned
100 rows through the public `get_dataset()` workflow. Separate discovered City
and regional samples each returned two EPSG:4326 `sf` rows, with matching
provenance. Retrieval by a stable ArcGIS item/layer ID and by a direct layer
URL also succeeded. The opt-in suite passed 274 assertions with no failures or
skips. These observations establish working discovery and retrieval paths, not
that every portal item will stay queryable or that all discovered datasets have
been reviewed by package maintainers.

Additional September 29 checks:

- The two opt-in live tests passed 28 assertions. Full spatial retrieval
  succeeded for all eight registered layers; each result was checked against
  its count and ID manifest. Filtering, field selection, ordered pagination,
  and point, line, and polygon projection were also exercised. The observed
  counts and CRS are in [Tampa source research](research-tampa.md).
- Deterministic coverage was 98.69% with `covr`. HTTP tests used real `httr2`
  request construction with mocked dispatch; ordinary tests blocked accidental
  live requests.
- An isolated installation of the required minimum `httr2` 1.2.3 passed 64
  HTTP assertions with `LC_CTYPE=C`. Prepared POST bodies retained Unicode
  filters and geometry precision.
- Schema fixtures for all eight datasets used synthetic feature values. No
  bulk government datasets were packaged.

The local archive included built vignette documentation and tests. The
configured [CI workflow](../.github/workflows/R-CMD-check.yaml) checks Linux
release/devel/oldrel-1, Windows release, and macOS release; a separate manual
[workflow](../.github/workflows/live-check.yaml) runs live tests. The
[October 2 CI run](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/37079804102)
passed all five `--as-cran --no-manual` jobs for source commit
`7287b65c284141d5d9353d014ce8c66fbccc2203`: Linux release, devel, and
oldrel-1; Windows release; and macOS release. These CI jobs did not check the
PDF manual. Reproduction commands and current test scope are in the
[test suite guide](../tests/README.md).

## Other-city compatibility checks (2026-10-02)

The added [offline tests](../tests/testthat/test-other-cities.R) use selected
schemas from [St. Petersburg recreation centers](https://egis.stpete.org/arcgis/rest/services/ServicesDOTS/GoogleGen/MapServer/4)
and [Clearwater park buffers](https://gis.myclearwater.com/arcgis/rest/services/ArcGISMapServices/Clearwater_Park_Buffers/MapServer/0).
Both MapServer layers omit the object-ID metadata member but declare an OID
field, exercising inference from their actual schemas. Synthetic records
exercise field capitalization, strings, integer and double attributes, UTC
dates, ID batches, ordered offsets, limits, empty filters, native EPSG:2882
point and polygon geometry, and missing geometry. No retrieved feature records
were added to the repository. The new offline cases passed 141 assertions;
the complete offline suite passed 2,416 with zero failures or warnings and ten
expected opt-in live skips in 65.1 seconds.

The four [municipal live tests](../tests/testthat/test-live-other-cities.R)
passed 214 assertions with zero failures, warnings, or skips in 10.6 seconds.
Every retrieval requested at most two feature rows with `page_size = 1` and a
15-second per-attempt timeout. The client also fetched matching counts and
object-ID manifests. Each test selected current object IDs for a complete
bounded filter rather than assuming fixed upstream counts or IDs. Native
EPSG:2882 geometry agreed with each server's EPSG:4326 projection within the
tests' 1e-5 coordinate comparison tolerance. Both runs used R 4.6.1, sf 1.1.3,
testthat 3.3.2, and `LC_ALL=C`.

These checks exercised `get_arcgis_layer()` compatibility. Both direct sources
retained `not_checked` provenance; at that revision, the checked catalog and
automatic discovery sources were not expanded. The manual live workflow's
existing `filter = "live"`
includes the new tests. Package checks and cross-platform CI were not rerun
for this test expansion; their earlier results above describe earlier source
revisions.

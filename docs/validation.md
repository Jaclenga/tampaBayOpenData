# Dated validation record

These are local results on Windows 11 with R 4.5.1. Each result describes the
source and dependencies used for that run; live City services can change.

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

The September 30 follow-up included fixes for UTC editor tracking dates,
response `attributes` validation, transient HTTP retries, and registry shape
checks. The September 29 work included the [bug scan](bug-scan.md) and
[security audit](security-audit.md). Those reports retain the finding-level
evidence and their own historical assertion counts.

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
[workflow](../.github/workflows/live-check.yaml) runs live tests. Remote CI
results were not established by these local checks. Reproduction commands and
current test scope are in the [test suite guide](../tests/README.md).

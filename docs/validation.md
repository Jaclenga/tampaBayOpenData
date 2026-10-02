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

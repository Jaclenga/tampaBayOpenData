## Submission status

This is a new submission. `tampaBayOpenData` has not previously been on CRAN
and has no downstream CRAN dependencies. Version 0.1.0 currently exports 15
`tbod_*` functions and bundles 52 checked ArcGIS layers. Earlier unprefixed
development aliases were removed before the first CRAN release.

## Test environments

* Windows 11 x64, R 4.5.1 (local, 2026-10-07): full `--as-cran` check.
* Ubuntu 24.04, R 4.3.3 (WSL, 2026-10-07): `--as-cran --no-manual` check.
* Ubuntu 22.04, R 4.1.2 (WSL, 2026-10-07): `--as-cran --no-manual` check.

The current source has not been checked on macOS or R-devel. An earlier source
revision passed a [five-platform GitHub Actions R check on
2026-10-04](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/37223299725);
that result does not establish the status of this revision.

## R CMD check results

The final 2026-10-07 Windows `R CMD check --as-cran` ran on a clean source
archive (247,769 bytes): **0 errors, 0 warnings, 1 note**. The sole note is
`New submission`. Examples, vignettes, and PDF and HTML manuals passed. The
offline tests recorded 5,541 passes, 18 expected opt-in live-test skips, and
no failures or warnings.

Each Linux check had **0 errors, 0 warnings, 2 notes**: `New submission` and
inability to verify the clock in WSL. These were native builds of the final
source, with manual checks omitted. Checking the Windows-built archive with
these older R versions added one `Author`/`Authors@R` note because R versions
format the ORCID differently; native builds did not show that note.

All four vignettes and the packaged bicycle example were also rendered with
network access unavailable. Network-dependent help examples are gated. The
checked catalog's 52 live endpoints are not contacted during ordinary package
checks; live integration and monitoring tests require
`TAMPA_OPEN_DATA_LIVE=true`. Optional `sf` behavior was checked with `sf`
unavailable.

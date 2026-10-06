## Submission status

This is a new submission. `tampaBayOpenData` has not previously been on CRAN
and has no downstream CRAN dependencies. Version 0.1.0 currently exports 15
`tbod_*` functions and bundles 52 checked ArcGIS layers. Earlier unprefixed
development aliases were removed before the first CRAN release.

## Test environments

* Windows 11 x64, R 4.5.1 (local, 2026-10-06).
* The latest completed five-platform GitHub Actions R check, on an earlier
  source revision, passed on
  [2026-10-04](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/37223299725).

## R CMD check results

The 2026-10-06 local `R CMD check --no-manual` ran on a fresh source archive:
**0 errors, 0 warnings, 0 notes**. It built and checked the vignettes, ran
examples, and passed 5,541 offline test expectations with 18 expected opt-in
live-test skips.

An earlier source revision passed a local 2026-10-04
`R CMD check --as-cran` including PDF and HTML manuals: 0 errors, 0 warnings,
and 1 expected `New submission` note. That result predates the current catalog
and public API changes. Live integration tests run separately from routine
package checks; they have not been rerun for this source revision.

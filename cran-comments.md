## Test environments

* Windows 11 x64, R 4.6.1 (local, 2026-10-04).
* GitHub Actions matrix: Ubuntu R release, devel, and oldrel-1; Windows R
  release; macOS R release. The latest completed five-job run before this
  submission revision passed on
  [2026-10-04](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/37223299725).

## R CMD check results

The 2026-10-04 local `R CMD check --as-cran` ran on a fresh source archive,
including PDF and HTML manuals and rebuilt vignettes: **0 errors, 0 warnings,
1 note**. The note is `New submission`; this package has not previously been
on CRAN. Its offline tests passed 3,861 assertions with 18 expected live-test
skips.

## Additional checks

The opt-in live suite on 2026-10-04 exercised all six configured publishers
and all 35 checked layers: 1,489 passing assertions, no failures or skips, and
one GDAL performance warning while processing a large source polygon.

The latest completed rOpenSci `pkgcheck` Action reported 95% offline coverage,
examples for all 12 exported functions, and four HTML vignettes. Routine
package checks use offline fixtures and set `TAMPA_OPEN_DATA_LIVE=false`;
live integration tests run separately. There are no downstream CRAN
dependencies for this initial release.

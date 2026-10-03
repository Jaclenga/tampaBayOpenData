## Test environments

* Windows 11 x64, R 4.5.1 (local, 2026-10-03)
* GitHub Actions: Ubuntu R release, devel, and oldrel-1; Windows R release;
  macOS R release (results for this revision pending)

## R CMD check results

Local `R CMD check --as-cran` on a fresh source archive, including PDF and HTML
manual checks:
0 errors, 0 warnings, 1 note.

* The note is `New submission`; this package has not previously been on CRAN.

## Additional checks

Offline test coverage is 95.17%. Routine checks use offline fixtures and set
`TAMPA_OPEN_DATA_LIVE=false`; live integration tests are available separately.

There are no downstream CRAN dependencies for this initial release.

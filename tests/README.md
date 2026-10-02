# Test suite

Run these commands in an R console from the package root. Ordinary tests use
deterministic responses and block unmocked HTTP requests.

```r
install.packages(c("httr2", "jsonlite", "tibble", "testthat", "pkgload", "sf"))
testthat::test_local(stop_on_failure = TRUE)
```

`sf` is optional: spatial tests skip without it. For a focused run, `filter`
matches test filenames:

```r
testthat::test_local(filter = "http", stop_on_failure = TRUE)
testthat::test_local(filter = "dataset-sources", stop_on_failure = TRUE)
testthat::test_local(filter = "live-discovery", stop_on_failure = TRUE)
testthat::test_local(filter = "generic-retrieval", stop_on_failure = TRUE)
```

The suite covers the 20 checked source schemas, live portal paging and
searching, checked versus discovered overlays, item/layer resolution, direct
URL retrieval, HTTP requests and retries, record pagination, parsing, spatial
conversion, provenance, convenience functions, and error and security
regressions. Discovery uses synthetic portal items and service metadata, so
ordinary tests do not depend on the live ArcGIS index. The
[request cases](testthat/test-request-cases.R) exercise malformed manifests,
transport statuses, and page limits; the
[new source spatial cases](testthat/test-new-source-spatial.R) exercise point,
line, and polygon results with missing geometry.
[live discovery cases](testthat/test-live-discovery.R) exercise multiple layers,
tables, stale items, duplicates, and portal pagination; the
[catalog overlay cases](testthat/test-catalog-overlay.R) check the 20-entry
offline registry alongside discovered results. The
[generic retrieval cases](testthat/test-generic-retrieval.R) verify that checked,
discovered, and direct URL paths use the same query engine.
[test-http.R](testthat/test-http.R) checks real `httr2` request construction
with `req_perform()` mocked. The retry tests in
[test-http-integrity.R](testthat/test-http-integrity.R) and
[test-security.R](testthat/test-security.R) exercise retry handling with network
calls and waits mocked.

## Fixtures

[helper-fixtures.R](testthat/helper-fixtures.R) generates synthetic responses;
the [source schema fixtures](testthat/fixtures/README.md) contain trimmed City
layer metadata. Keep source field names, types, date references, and CRS
differences when updating them. Add a regression test for a bug and keep
ordinary tests independent of service availability.

[setup-offline.R](testthat/setup-offline.R) blocks accidental live dispatch.
Higher-level retrieval and discovery tests mock `arcgis_http()`.

## Live and package checks

Live tests run only when enabled explicitly:

```r
Sys.setenv(TAMPA_OPEN_DATA_LIVE = "true")
testthat::test_local(filter = "live", stop_on_failure = TRUE)
Sys.unsetenv("TAMPA_OPEN_DATA_LIVE")
```

The manual [live-check workflow](../.github/workflows/live-check.yaml) runs
opt-in checks against current City and regional ArcGIS services. Its bounded
samples cover all 20 checked layers, a live portal discovery case, and a
complete multi-page permit download. The
[R-CMD-check workflow](../.github/workflows/R-CMD-check.yaml) runs offline
package checks. To build and check a source archive locally:

```sh
R CMD build .
R CMD check --no-manual tampaBayOpenData_0.1.0.tar.gz
```

Building the vignette requires `knitr`, `rmarkdown`, and Pandoc. See
[CONTRIBUTING.md](../CONTRIBUTING.md) for the development workflow.

# Test suite

Run these commands from the package root. Ordinary tests use deterministic
responses and block unmocked HTTP requests.

```r
install.packages(c("httr2", "jsonlite", "tibble", "testthat", "pkgload", "sf"))
testthat::test_local(stop_on_failure = TRUE)
```

`sf` is optional: spatial tests skip without it. For a focused run, `filter`
matches test filenames:

```r
testthat::test_local(filter = "http", stop_on_failure = TRUE)
testthat::test_local(filter = "dataset-sources", stop_on_failure = TRUE)
```

The suite covers the catalog, all 11 saved source schemas, HTTP requests and
retries, pagination boundaries, parsing, spatial conversion, provenance,
convenience functions, and error and security regressions. The
[request cases](testthat/test-request-cases.R) exercise malformed manifests,
transport statuses, and page limits; the
[new source spatial cases](testthat/test-new-source-spatial.R) exercise point,
line, and polygon results with missing geometry.
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
Higher-level retrieval tests can mock `arcgis_http()`.

## Live and package checks

Live tests run only when enabled explicitly:

```r
Sys.setenv(TAMPA_OPEN_DATA_LIVE = "true")
testthat::test_local(filter = "live", stop_on_failure = TRUE)
Sys.unsetenv("TAMPA_OPEN_DATA_LIVE")
```

The manual [live-check workflow](../.github/workflows/live-check.yaml) runs
these checks against current City services. The
[R-CMD-check workflow](../.github/workflows/R-CMD-check.yaml) runs offline
package checks. To build and check a source archive locally:

```sh
R CMD build .
R CMD check --no-manual tampaBayOpenData_0.1.0.tar.gz
```

Building the vignette requires `knitr`, `rmarkdown`, and Pandoc. See
[CONTRIBUTING.md](../CONTRIBUTING.md) for the development workflow.

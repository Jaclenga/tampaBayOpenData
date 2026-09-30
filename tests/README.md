# Test suite

Run commands from the package root. The ordinary suite uses deterministic
responses and blocks unmocked HTTP requests before they reach the network.

## Run the suite

Install the runtime and test dependencies once:

```r
install.packages(c("httr2", "jsonlite", "tibble", "testthat", "pkgload", "sf"))
```

Then run:

```r
testthat::test_local(stop_on_failure = TRUE)
```

`sf` enables geometry and CRS checks. When it is unavailable, the spatial tests
skip; table retrieval and the missing-dependency regression still run.
Live integration cases skip unless explicitly enabled.

For a focused check, match test filenames with `filter`:

```r
testthat::test_local(filter = "http", stop_on_failure = TRUE)
testthat::test_local(filter = "dataset-sources", stop_on_failure = TRUE)
testthat::test_local(filter = "metadata-validation", stop_on_failure = TRUE)
```

## Coverage

| Test file | Behavior checked |
| --- | --- |
| [test-catalog.R](testthat/test-catalog.R) | Registry validity, discovery, search, and refreshed metadata |
| [test-http.R](testthat/test-http.R) | Real HTTP request construction, GET/POST encoding, precision, request options, responses, and contextual transport errors |
| [test-arcgis.R](testthat/test-arcgis.R) | ID manifests, pagination, transfer limits, ordering, filters, and incomplete or inconsistent responses |
| [test-dataset-sources.R](testthat/test-dataset-sources.R) | Verified schemas and endpoint routing for all eight Tampa datasets |
| [test-metadata-validation.R](testthat/test-metadata-validation.R) | Malformed date/capability metadata, absent optional `sf`, and the offline HTTP guard |
| [test-parsing.R](testthat/test-parsing.R) | Source strings, declared types, nulls, dates, and numeric precision |
| [test-spatial.R](testthat/test-spatial.R) | Points, lines, polygons, empty geometries, declared CRS, and spatial errors |
| [test-provenance.R](testthat/test-provenance.R) | Source/query metadata, selected fields, record limits, and completeness |
| [test-convenience.R](testthat/test-convenience.R) | Thin wrappers and argument forwarding |
| [test-review-regressions.R](testthat/test-review-regressions.R) | Response integrity, schema errors, integer limits, date semantics, and inconsistent spatial references |
| [test-bug-parsing.R](testthat/test-bug-parsing.R) | Big-integer rounding, display-option independence, and contextual alias validation |
| [test-bug-responses.R](testthat/test-bug-responses.R) | Nested duplicate keys, metadata object shapes, manifest flags, and page ID declarations |
| [test-bug-spatial.R](testthat/test-bug-spatial.R) | Mixed numeric polygon closure, coordinate array structure, conflicting WKIDs, aliases, and legacy/WKT fallback |
| [test-security.R](testthat/test-security.R) | Literal-only JSON, inline WKT, redirects, bounded retry waits, JSON depth, and response-size checks |
| [test-live.R](testthat/test-live.R) | Explicitly enabled checks against current City services |

Optional code coverage uses `covr`:

```r
install.packages("covr")
coverage <- covr::package_coverage()
covr::percent_coverage(coverage)
covr::zero_coverage(coverage)
```

The HTTP tests replace `httr2::req_perform()` while keeping real request
construction and response decoding. They check retry configuration without
network retries or delays. Other retrieval tests mock the shared transport.

## Fixtures and maintenance

[helper-fixtures.R](testthat/helper-fixtures.R) creates synthetic features and
controlled paginated responses. The
[source schema fixtures](testthat/fixtures/README.md) contain trimmed, verified
City metadata with exact source URLs; all feature values are synthetic.

Add a regression that demonstrates the failure before changing client behavior.
For new source schemas, preserve field names, types, date reference metadata,
and CRS differences. Keep fixture values small and reproducible. Do not add
bulk government records or make ordinary tests depend on service availability.

[setup-offline.R](testthat/setup-offline.R) blocks accidental live dispatch.
Tests that exercise the HTTP boundary must supply deterministic responses at
`httr2::req_perform()`; other tests can mock `arcgis_http()`.

## Live integration and package checks

Run live checks explicitly, then restore the ordinary offline setting:

```r
Sys.setenv(TAMPA_OPEN_DATA_LIVE = "true")
testthat::test_local(filter = "live", stop_on_failure = TRUE)
Sys.unsetenv("TAMPA_OPEN_DATA_LIVE")
```

Live results reflect current upstream data and availability. The separate
manual [live-check workflow](../.github/workflows/live-check.yaml) runs these
checks. The [R-CMD-check workflow](../.github/workflows/R-CMD-check.yaml) runs
the offline suite as part of package checks across the configured platforms.

To build and check a source archive locally:

```sh
R CMD build .
R CMD check --no-manual tampaBayOpenData_0.1.0.tar.gz
```

Building the vignette also requires `knitr`, `rmarkdown`, and Pandoc. See
[CONTRIBUTING.md](../CONTRIBUTING.md) for the development workflow.

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
testthat::test_local(filter = "portal-registry", stop_on_failure = TRUE)
testthat::test_local(filter = "catalog-filters", stop_on_failure = TRUE)
testthat::test_local(filter = "catalog-quality", stop_on_failure = TRUE)
testthat::test_local(filter = "generic-retrieval", stop_on_failure = TRUE)
testthat::test_local(filter = "other-cities", stop_on_failure = TRUE)
testthat::test_local(filter = "download", stop_on_failure = TRUE)
testthat::test_local(filter = "namespaced-api", stop_on_failure = TRUE)
testthat::test_local(filter = "custom-portal", stop_on_failure = TRUE)
testthat::test_local(filter = "schema-drift", stop_on_failure = TRUE)
```

The suite covers the 52 checked source schemas across six publishers, live portal
paging and searching, checked versus discovered overlays, item/layer resolution, direct
URL retrieval, the canonical `tbod_` API, schema drift, HTTP requests and retries,
record pagination, parsing, spatial
conversion, provenance, convenience functions, and error and security
regressions. Discovery uses synthetic portal items and service metadata, so
ordinary tests do not depend on the live ArcGIS index. The
[portal registry cases](testthat/test-portal-registry.R) validate publisher
identities and evidence and prove that a configured synthetic publisher works
through discovery and retrieval. The
[catalog quality cases](testthat/test-catalog-quality.R) enforce editorial
registry invariants offline, including configured jurisdictions, unique checked
IDs and endpoints, valid source URLs, scope and terms documentation, and
matching schema snapshots. The
[catalog filter cases](testthat/test-catalog-filters.R) cover publisher and
jurisdiction selection, status and geometry, literal topics, category labels,
UTC date bounds, live metadata on checked matches, and retained scan attributes. The
[request cases](testthat/test-request-cases.R) exercise malformed manifests,
transport statuses, and page limits; the
[new source spatial cases](testthat/test-new-source-spatial.R) exercise point,
line, and polygon results with missing geometry.
[live discovery cases](testthat/test-live-discovery.R) exercise multiple layers,
tables, stale items, duplicates, and portal pagination; the
[catalog overlay cases](testthat/test-catalog-overlay.R) check selected checked
entries alongside discovered results. The
[generic retrieval cases](testthat/test-generic-retrieval.R) verify that checked,
discovered, and direct URL paths use the same query engine.
[schema drift cases](testthat/test-schema-drift.R) simulate added, removed,
renamed, and changed-type fields, geometry and CRS changes, disappeared layers,
invalid expected schemas, and checked retrieval warnings or errors.
[Custom portal cases](testthat/test-custom-portal.R) cover another ArcGIS
organization, malformed service layers, and public Enterprise HTTPS ports.
[Canonical API cases](testthat/test-namespaced-api.R)
check all `tbod_` entry points and the namespace export surface.
[test-http.R](testthat/test-http.R) checks real `httr2` request construction
with `req_perform()` mocked. The retry tests in
[test-http-integrity.R](testthat/test-http-integrity.R) and
[test-security.R](testthat/test-security.R) exercise retry handling with network
calls and waits mocked.

[Other-city tests](testthat/test-other-cities.R) use verified St. Petersburg
recreation-center and Clearwater park-buffer schemas with synthetic records.
They cover MapServer object-ID inference, typed attributes and dates, complete
and ordered pagination, zero limits, empty filters, native EPSG:2882 geometry,
missing geometry, and direct-URL provenance. Direct URL retrieval retains
`not_checked` provenance, even when a separate checked catalog entry uses the
same endpoint. Regional catalog tests cover checked layers beyond Tampa
and the configured discovery organizations.

[Download tests](testthat/test-download.R) use temporary directories and
synthetic responses to check typed chunks, interrupted and expired-deadline
resumes, validation of saved data and provenance, changes to queries and
manifests, atomic-write boundaries, exclusive locks, and preservation of unrelated
files. They also verify that validated completed chunks are not requested again.

## Fixtures

[helper-fixtures.R](testthat/helper-fixtures.R) generates synthetic responses;
the [source schema fixtures](testthat/fixtures/README.md) contain trimmed publisher
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

Use `filter = "live-other-cities"` to run only the municipal checks, or
`filter = "live-county-discovery"` for the county checks. The
[county live cases](testthat/test-live-county-discovery.R) discover public
libraries and fire stations, then retrieve at most two rows by descriptor and
stable ID and check projected point geometry. A matching checked registry entry
retains its checked ID; other live results remain `discovered`.

For the small recurring smoke suites, use
`filter = "live-monitoring|live-county-discovery"` with
`TAMPA_OPEN_DATA_LIVE=true`. They sample every checked layer across all six
publishers, a regional discovery result, and county facilities, checking source
identity, selected field types, row counts, provenance, and geometry. County
checks exercise descriptor and stable-ID retrieval and projection to EPSG:4326.
Each retrieval requests at most two feature rows with a 15-second per-attempt
timeout; portal discovery
uses at most one service item per organization returned by `tbod_list_portals()`,
including Hillsborough and Pinellas counties. Count and applicable object-ID
manifest requests still run, with a 45-second overall deadline per operation.

The manual [live-check workflow](../.github/workflows/live-check.yaml) runs
opt-in checks against current Tampa, regional, St. Petersburg, Clearwater, and
county ArcGIS services. It covers all 52 checked layers, live portal discovery,
and a complete multi-page permit download. The
[other-city live tests](testthat/test-live-other-cities.R) retrieve at most two
features per call, check a complete filter using IDs from the current run, and
compare native geometry with server projection to EPSG:4326. The client still
fetches matching counts and applicable full or subset object-ID manifests. Those tests use no
fixed upstream counts or record IDs; an upstream failure fails the opted-in run.
The same workflow schedules the bounded `live-monitoring` and
`live-county-discovery` suites on Tuesdays and Fridays at 06:17 UTC once the
workflow is on the repository's default branch,
as described in the [GitHub schedule documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule).
Manual runs retain the full `live` suite, including
the complete permit download. Runs have a 20-minute job timeout, and a newer
run cancels an older run on the same branch. Scheduled results provide dated
availability and schema evidence as runs complete; they do not guarantee
future uptime, source freshness, or support for every public layer.
The [R-CMD-check workflow](../.github/workflows/R-CMD-check.yaml) runs offline
package checks. To build and check a source archive locally:

```sh
R CMD build .
R CMD check --no-manual tampaBayOpenData_0.1.0.tar.gz
```

Before a release, check the final fresh archive with `R CMD check --as-cran`
and confirm the configured cross-platform jobs on that source revision.

Building the vignette requires `knitr`, `rmarkdown`, and Pandoc. See
[CONTRIBUTING.md](../CONTRIBUTING.md) for the development workflow.

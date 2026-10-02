# Source audit: nycOpenData

This 2026-09-29 audit inspected [rOpenSci/nycOpenData commit
`39e9fd47`](https://github.com/ropensci/nycOpenData/commit/39e9fd47f386b469c11f3949b47bfcafc30c1ebb),
version 0.2.3. It describes that checkout; upstream tests and CI were not run.

## API and retrieval

The [namespace](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/NAMESPACE)
exports three functions:

| Function | Behavior |
| --- | --- |
| `nyc_list_datasets()` | Downloads and tidies a live NYC Socrata catalog. |
| `nyc_pull_dataset()` | Resolves a catalog key or UID, then fetches with filters, date/range, raw SoQL, and a row limit. |
| `nyc_any_dataset()` | Fetches a supplied `.json` endpoint without catalog lookup. |

Each returns a tibble. Retrieval defaults to a 10,000-row limit. The catalog
uses Socrata dataset `5tqd-u88y`, generates keys from titles, and deduplicates
by UID. Even a UID pull first downloads the live catalog. Keys can change with
titles, and there is no curated supported-dataset registry or separate search
function. See [catalog code](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/nyc_list_datasets.R)
and [lookup code](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/nyc_pull_dataset.R).

The shared [request helper](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/utils_request.R)
uses `httr::GET()`, a timeout, and JSON decoding. It reports transport and
HTTP failures but has no retry, response-completeness, or pagination loop:
`$limit` controls one request. Filters are SoQL specific, including `TRIM()`
for text matching and inclusive-start/exclusive-end date ranges. Callers
must provide a date field; the client does not infer one from the catalog.

Default postprocessing cleans column names and heuristically coerces character
values. Numeric coercion can remove leading zeros from identifiers. Datetime
parsing strips offsets before UTC interpretation and can alter instants. The
package has no schema-driven ArcGIS types, `sf` conversion, CRS handling,
runtime cache, or attached retrieval provenance. These findings support the
Tampa client's explicit schema, spatial, integrity, and provenance design;
SoQL behavior is not transferable to ArcGIS.

## Tests, documentation, and attribution

The inspected [test suite](https://github.com/ropensci/nycOpenData/tree/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/tests/testthat)
uses four test files and five recorded request cassettes, alongside mocked
catalog bindings. Some tests still fetch the live catalog outside a cassette.
The README, function help, and
[vignette](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/vignettes/getting-started.Rmd)
show a useful discovery-to-retrieval workflow, although vignette chunks make
live calls and some prose labels unordered limited results as the most recent.
The configured [R CMD check](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/.github/workflows/R-CMD-check.yaml),
[coverage](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/.github/workflows/test-coverage.yaml),
and [pkgcheck](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/.github/workflows/pkgcheck.yaml)
workflows were inspected, not executed.

The source declares `MIT + file LICENSE`; its
[full notice](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/LICENSE.md)
applies if code or documentation is copied or adapted. The Tampa client is an
independent ArcGIS implementation that credits this package as design
inspiration. That software license does not determine City of Tampa data terms.

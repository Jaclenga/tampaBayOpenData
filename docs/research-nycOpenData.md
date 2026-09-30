# Source audit: nycOpenData

Audited on 2026-09-29. The public [rOpenSci repository](https://github.com/ropensci/nycOpenData) exists. This report examines a shallow checkout of `main` at [39e9fd47f386b469c11f3949b47bfcafc30c1ebb](https://github.com/ropensci/nycOpenData/commit/39e9fd47f386b469c11f3949b47bfcafc30c1ebb), committed 2026-09-25; package version 0.2.3. Findings below describe the actual checked-out source, rather than relying on the README. Upstream tests and CI runs were not executed during this architectural audit.

## Structure and public API

The package is a conventional R package: `DESCRIPTION`, generated `NAMESPACE`, four files under `R/`, roxygen-generated `man/` files, `tests/testthat/`, a getting-started vignette, `inst/CITATION`, README source/rendered output, pkgdown configuration, and three GitHub Actions workflows. There is no provider framework or separate registry file. [Package metadata](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/DESCRIPTION), [exports](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/NAMESPACE).

There are three exports:

| Function | Actual behavior |
| --- | --- |
| `nyc_list_datasets()` | Downloads and tidies the live NYC Socrata catalog. |
| `nyc_pull_dataset(dataset, ...)` | Resolves a current catalog key or UID; accepts equality filters, a date/range and field, raw SoQL `where`/`order`, row limit, timeout, and parsing/name-cleaning switches. |
| `nyc_any_dataset(json_link, ...)` | Bypasses discovery and fetches a supplied `.json` endpoint with a row limit, timeout, and parsing switches. |

Each returns a tibble. Retrieval defaults to 10,000 rows. The documented, compact discovery-to-retrieval workflow is the useful design precedent. [Catalog implementation](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/nyc_list_datasets.R), [catalog retrieval](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/nyc_pull_dataset.R), [direct retrieval](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/nyc_any_dataset.R).

## Discovery and internal abstractions

`.nyc_catalog_tbl()` fetches NYC catalog dataset `5tqd-u88y` with `$limit=50000`, retains records with `type == "dataset"`, generates keys with `janitor::make_clean_names(name)`, removes missing UIDs, deduplicates by UID, and moves key/UID/title to the front. Discovery is live and depends on the catalog schema and availability. Keys depend on current titles; official UIDs are the stronger identifiers. There is no independent search function or curated supported-dataset registry. [Catalog source](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/nyc_list_datasets.R).

Both UID and key retrieval actually fetch the live catalog before resolving a match; direct UID use does not skip that request. Missing required key/UID columns, unknown identifiers, and ambiguous matches produce explicit errors. The current implementation requires callers to provide `date_field`; it does not apply catalog-derived ordering or date defaults. These details matter because prose documentation makes broader claims in places. [Lookup and query assembly](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/nyc_pull_dataset.R).

`utils_request.R` contains small validation, endpoint, filter, date-query, HTTP, and postprocessing helpers. Catalog retrieval and ordinary pulls share `.nyc_dataset_request()`; direct retrieval shares `.nyc_get_json()` and postprocessing. This separation avoids duplicated HTTP mechanics without a complex abstraction hierarchy. [Internal helpers](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/utils_request.R).

## HTTP, query semantics, parsing, and failures

The common helper checks `curl::has_internet()`, performs `httr::GET()` with encoded query parameters and a timeout, reports transport failures with timeout advice, reports HTTP status plus up to 500 characters of response text, and parses text using `jsonlite::fromJSON(flatten = TRUE)`. It does not implement retries, response-shape validation, contextual malformed-JSON errors, or completeness checks. Critically, there is **no pagination loop**: `$limit` controls a single request. No `$offset`, continuation, or count verification is present. [Request source](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/utils_request.R).

Filters form Socrata `$where` expressions, use `IN` for vectors, escape apostrophes, trim supplied text, and apply `TRIM(field)` to text matching. Raw `where` is combined with generated filters using parenthesized `AND`; date ranges use inclusive starts and exclusive ends. These query semantics are specific to SoQL and must not be transferred directly to ArcGIS SQL. Date-string validation checks shape, not all calendar validity. [Query helpers](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/utils_request.R).

Names are cleaned by default. Character columns can become logical or numeric; numeric parsing removes commas and can remove leading zeros from identifiers. ISO-like datetime parsing uses a 95% threshold and strips timezone offsets before parsing as UTC, so it can alter instants and replace a minority of unparseable values with missing values. Both coercion and name cleaning can be disabled. There is no schema-driven ArcGIS typing, `sf` conversion, or CRS handling. The Tampa client should retain government field names and use declared field types instead of these heuristics. [Postprocessing source](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/utils_request.R).

## Dependencies, tests, documentation, and CI

Imports are `httr`, `jsonlite`, `tibble`, `janitor`, `curl`, `dplyr`, and `rlang`. Suggested packages include testthat edition 3, `vcr`, `webmockr`, knitr/rmarkdown, and plotting/data-analysis helpers. Keep HTTP/JSON/tabular dependencies where they serve the new client; neither janitor nor a full analysis stack is required merely to follow this precedent. [DESCRIPTION](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/DESCRIPTION).

Four test files cover argument validation, query composition, empty/coerced data, catalog columns, UID/key lookup, and retrieval switches. Five recorded YAML cassettes support request replay through vcr/webmockr; mocked catalog bindings cover corrupted schemas and ambiguity. Some public validation tests still fetch the catalog outside a cassette, and the global internet precheck can impede fully offline replay. There are no pagination, geometry, CRS, provenance, HTTP-error, or malformed-response test cases. Adopt the fixture idea while making Tampa tests independently runnable without live network access. [Tests](https://github.com/ropensci/nycOpenData/tree/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/tests/testthat), [test helper](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/tests/testthat/helper-vcr.R).

The README, function help, pkgdown configuration, citation, and [getting-started vignette](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/vignettes/getting-started.Rmd) give a discovery/filter/analysis narrative. Function examples guard live calls with `interactive()` and internet checks, but vignette data chunks make live calls. Some vignette prose calls limited, unordered pulls the most recent records even though those examples specify no `order`. The new vignette should use verified IDs, explicit ordering when claiming recency, and offline-safe build behavior.

CI defines R CMD check on macOS/Windows release and Ubuntu release/devel/oldrel-1, covr/Codecov coverage, and rOpenSci pkgcheck. The audit confirms workflow configuration, not successful execution or a coverage percentage. [R CMD check](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/.github/workflows/R-CMD-check.yaml), [coverage](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/.github/workflows/test-coverage.yaml), [pkgcheck](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/.github/workflows/pkgcheck.yaml).

## Caching and provenance

There is no runtime cache: each catalog-based call fetches metadata again. Test cassettes are fixtures, not a user data cache. Catalog metadata includes source information, but returned dataset tibbles attach no source endpoint, government publisher, dataset ID, retrieval time, query, or completeness attribute. Tampa provenance needs a deliberate implementation beyond this precedent. [Catalog source](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/nyc_list_datasets.R), [retrieval helpers](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/R/utils_request.R).

## What to preserve, and what to replace

| Preserve as a design idea | Replace for Tampa |
| --- | --- |
| A small discovery/inspection/retrieval API | NYC-specific names and Socrata URLs/UID assumptions |
| Catalog-driven lookup with readable identifiers | Live title-derived keys with a verified, stable registry |
| One request layer reused by public functions | `$limit`-only pulls with verified ArcGIS pagination |
| Standard R tabular outputs and documented switches | Heuristic parsing with ArcGIS schema/date/geometry parsing |
| Fixtures, help, introductory examples, and CI | Network-dependent tests/builds with deterministic offline verification |
| An advanced query escape hatch | SoQL and `TRIM` rules with supported ArcGIS `where`/field/order parameters |

Provenance, typed empty results, spatial references, incomplete-result detection, and informative upstream-service errors are additional first-class requirements. No provider/plugin framework is justified by this source or by the City-of-Tampa-only v0.1 scope.

## License and attribution decision

`DESCRIPTION` declares `MIT + file LICENSE`; `LICENSE` names year 2025 and Christian A. Martinez, and `LICENSE.md` supplies the full MIT notice. If substantial code or documentation is copied/adapted, retain that copyright and full permission notice in distributed attribution/license materials and identify the adapted files. The inspected source should be used as architectural inspiration; an independently implemented ArcGIS client avoids copying Socrata-specific code. State inspiration in the README and link the original project, while accurately stating independence from rOpenSci and both governments. This source-code license does not determine Tampa government data terms. [License metadata](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/LICENSE), [full MIT notice](https://github.com/ropensci/nycOpenData/blob/39e9fd47f386b469c11f3949b47bfcafc30c1ebb/LICENSE.md).

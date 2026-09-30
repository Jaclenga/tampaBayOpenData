# Contributing

Use an issue or pull request to describe a reproducible problem or a proposed
change. Include the package version, dataset ID, query, and exact error for
retrieval problems. Keep changes focused on data access, source discovery,
parsing, provenance, and reliability.

## Local development

From the package root, install development dependencies and load the package:

```r
install.packages(c("devtools", "roxygen2", "testthat", "rmarkdown", "knitr", "sf"))
devtools::load_all()
devtools::test()
```

`sf` enables spatial tests. Pandoc is required to render the introductory
vignette. Tests use representative responses and mocked transport; ordinary
testing and R CMD check must not depend on a live government service. The
suite blocks accidental live HTTP dispatch. See the [test suite guide](tests/README.md)
for focused tests, coverage commands, and fixture maintenance.

Before submitting code:

```r
roxygen2::roxygenise()
devtools::test()
devtools::check(args = "--no-manual")
```

Generated `man/` files and `NAMESPACE` should be updated from roxygen comments,
with meaningful tests for changed behavior. Keep examples and vignette builds
offline; show network retrieval examples with `eval = FALSE`.

Opt-in live integration checks are useful after an endpoint or query change:

```r
Sys.setenv(TAMPA_OPEN_DATA_LIVE = "true")
testthat::test_local(filter = "live", stop_on_failure = TRUE)
```

They also run through the manually triggered `live-check` GitHub Actions
workflow. Live availability failures should not weaken deterministic tests.

## Registry changes

Verify official City of Tampa landing pages, service/layer metadata, and a small
query before adding or changing a record in `inst/extdata/datasets.json`.
Record the source, publisher, stable package ID, geometry, useful date fields,
available terms, and verification date. Do not infer a dataset from a promising
service name alone. Add registry validation and representative parsing or
retrieval fixtures when the new schema exercises behavior not already covered.

The v0.1 registry supports City of Tampa only. Discuss additional jurisdictions
as a future change; do not add speculative providers or a plugin framework.
Convenience functions should remain few and delegate to `get_dataset()`.

## Retrieval and source fidelity

Preserve government field names and source strings. Parse types from declared
ArcGIS field metadata, account for nulls and empty results, and report ambiguous
date/CRS semantics. Keep all HTTP requests in the shared client. Changes must
retain pagination integrity checks and provenance for tabular and spatial
results. Returning an unnoticed partial dataset is a bug.

Use small synthetic or carefully selected public response fixtures; do not
commit bulk downloads or a government data warehouse. Document any intentional
normalization and its effect on values.

## Attribution

The project credits `nycOpenData` as architectural inspiration. If a future
contribution copies or adapts substantial third-party code or documentation,
identify its origin and preserve required copyright and license notices.
Government data terms and the package's software license are separate.

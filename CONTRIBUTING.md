# Contributing

For bugs, include the package version, dataset ID, query, and exact error. Keep
changes focused on discovery, retrieval, parsing, provenance, or reliability.

## Develop and check

From the package root:

```r
install.packages(c("devtools", "roxygen2", "testthat", "sf", "knitr", "rmarkdown"))
devtools::load_all()
devtools::test()
roxygen2::roxygenise()
devtools::check(args = "--no-manual")
```

`sf` is optional for spatial tests; rendering the vignette also needs Pandoc.
Commit generated `man/` and `NAMESPACE` changes when updating roxygen comments.
Add tests for changed behavior. Ordinary tests and package checks use mocked
responses and block live HTTP. Keep examples and vignettes offline; set network
retrieval chunks to `eval = FALSE`. See the [test guide](tests/README.md) for
focused and opt-in live checks.

## Registry and retrieval changes

Before editing `inst/extdata/datasets.json`, verify the City of Tampa source
page, layer metadata, and a small query. Record source and service URLs, layer
ID, publisher, stable ID, geometry, useful date fields, data terms, and
verification date. Add a fixture or test when a new schema exercises different
behavior. Version 0.1 supports City of Tampa sources only; convenience
functions should delegate to `get_dataset()`.

Preserve source field names and values. Parse types from ArcGIS metadata,
handle nulls and empty results, and report uncertain date or CRS semantics.
Route HTTP through the shared client and retain pagination completeness checks
and result provenance. Use small synthetic or selected public fixtures, not
bulk downloads. Document any intentional value normalization.

## Attribution

The project credits `nycOpenData` as inspiration. Identify the origin of any
adapted third-party code or documentation and retain required notices. Data
terms and the package's software license are separate.

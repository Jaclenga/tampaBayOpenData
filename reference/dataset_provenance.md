# Read the source and retrieval provenance of a result

Provenance is attached to both tabular and spatial retrieval results. It
describes the government publisher, source URL, query endpoint,
retrieval time, original query, expected and returned row counts, and
completeness. `validation_status` is `checked` for bundled,
maintainer-validated entries, `discovered` for live portal results, and
`not_checked` for direct layer URLs. Item ID, portal, and original
metadata are included when available. A successful full retrieval checks
membership against an object-ID manifest; upstream attributes are not
guaranteed to be a transactionally frozen snapshot. Attributes can be
lost in subsequent R transformations; save provenance before exporting
data or transforming objects with tools that discard attributes.

## Usage

``` r
dataset_provenance(x)
```

## Arguments

- x:

  A retrieval result or a chunk read from
  [`download_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/download_dataset.md)
  or
  [`download_arcgis_layer()`](https://jaclenga.github.io/tampaBayOpenData/reference/download_arcgis_layer.md).

## Value

A named list with `dataset_id`, `publisher`, `jurisdiction`,
`source_url`, the query `endpoint`, `validation_status`, UTC
`started_at` and `retrieved_at` times, the submitted `query`,
`matched_rows`, `returned_rows`, `complete`, and `integrity`. Download
chunks also include a `download` entry with the chunk number and object
IDs. The list is the result's attached `source` attribute.

## Examples

``` r
dataset_info("construction-permits")$publisher
#> [1] "City of Tampa"
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  permits <- get_permits(limit = 10)
  dataset_provenance(permits)
  attr(permits, "retrieved_at")
}
```

# Read retrieval provenance

Reads the source, query, completeness, and schema information attached
to a tabular or spatial result from
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md),
or a chunk saved by
[`tbod_download_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_download_dataset.md).
The record includes publisher, source and query URLs, UTC retrieval
time, returned and matching row counts, and integrity status.
`validation_status` is `checked` for bundled entries, `discovered` for
live portal results, and `not_checked` for direct layer URLs. Item ID,
portal, and original metadata are included when available. A successful
full retrieval checks object-ID membership, but upstream attributes are
not a transactionally frozen snapshot. R transformations can discard
attributes; save provenance before transforming or exporting the result.

## Usage

``` r
tbod_provenance(x)
```

## Arguments

- x:

  A retrieval result or a chunk read from
  [`tbod_download_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_download_dataset.md)
  or
  [`tbod_download_arcgis_layer()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_download_arcgis_layer.md).

## Value

The attached `source` list, including `dataset_id`, `publisher`,
`jurisdiction`, `source_url`, query `endpoint`, `validation_status`, UTC
`started_at` and `retrieved_at`, submitted `query`, `matched_rows`,
`returned_rows`, `complete`, and `integrity`. Download chunks also
include `download` with the chunk number and object IDs.

## Examples

``` r
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  permits <- tbod_get_permits(limit = 10)
  tbod_provenance(permits)$source_url
}
```

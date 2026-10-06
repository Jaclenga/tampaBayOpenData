# Read retrieval provenance

Reads the source, query, completeness, and schema information attached
to a retrieval result.

## Usage

``` r
tbod_provenance(x)
```

## Arguments

- x:

  A result from
  [`tbod_get_dataset`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
  or a downloaded chunk.

## Value

The result's attached source and retrieval provenance record.

# Retrieve City of Tampa active development case locations

A thin wrapper for `get_dataset("development-cases", ...)`. The upstream
layer covers active entitlement locations, not all historical
development.

## Usage

``` r
get_development_cases(...)
```

## Arguments

- ...:

  Arguments passed unchanged to
  [`get_dataset()`](https://Jaclenga.github.io/tampaBayOpenData/reference/get_dataset.md),
  excluding `id`.

## Value

A tibble, or an sf object when spatial retrieval is requested. Source
metadata are attached as `source`, `dataset_id`, `jurisdiction`, and
`retrieved_at` attributes;
[`dataset_provenance()`](https://Jaclenga.github.io/tampaBayOpenData/reference/dataset_provenance.md)
returns the full record.

## Examples

``` r
if (FALSE) get_development_cases(spatial = TRUE, limit = 10) # \dontrun{}
```

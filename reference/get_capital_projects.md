# Retrieve City of Tampa public capital project locations

A thin wrapper for `get_dataset("capital-projects", ...)`. The City
service publishes only records marked PUBLIC; this client preserves that
source scope.

## Usage

``` r
get_capital_projects(...)
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
if (FALSE) get_capital_projects(limit = 10) # \dontrun{}
```

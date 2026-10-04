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
  [`get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/get_dataset.md),
  excluding `id`.

## Value

A tibble, or an sf object when spatial retrieval is requested. Source
metadata are attached as `source`, `dataset_id`, `jurisdiction`, and
`retrieved_at` attributes;
[`dataset_provenance()`](https://jaclenga.github.io/tampaBayOpenData/reference/dataset_provenance.md)
returns the full record.

## Examples

``` r
dataset_info("development-cases")$title
#> [1] "Active development coordination cases"
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  cases <- get_development_cases(limit = 10)
  nrow(cases)
}
```

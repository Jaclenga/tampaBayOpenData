# Retrieve checked City of Tampa capital projects

Calls
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
with the checked City of Tampa `capital-projects` catalog ID to retrieve
current publisher records. The City service publishes records marked
PUBLIC; the package preserves that source scope.

## Usage

``` r
tbod_get_capital_projects(...)
```

## Arguments

- ...:

  Arguments passed to
  [`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
  except `id`.

## Value

A tibble or sf object with retrieval provenance attached.

## Examples

``` r
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  tbod_get_capital_projects(limit = 10)
}
```

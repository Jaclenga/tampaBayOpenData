# Retrieve checked City of Tampa development cases

Calls
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
with the checked City of Tampa `development-cases` catalog ID to
retrieve current publisher records. It covers active entitlement
locations, not all historical development cases.

## Usage

``` r
tbod_get_development_cases(...)
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
  tbod_get_development_cases(limit = 10)
}
```

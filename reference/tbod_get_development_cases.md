# Retrieve bundled Tampa development cases

Calls
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
for the bundled `development-cases` layer. It covers active entitlement
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

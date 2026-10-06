# Retrieve bundled Tampa capital projects

Calls
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
for the bundled `capital-projects` layer. The City service publishes
records marked PUBLIC; the package preserves that source scope.

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

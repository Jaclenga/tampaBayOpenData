# Retrieve selected bundled Tampa datasets

Convenience entry points for the bundled construction permits, active
development cases, and public capital projects layers, respectively.

## Usage

``` r
tbod_get_permits(...)

tbod_get_development_cases(...)

tbod_get_capital_projects(...)
```

## Arguments

- ...:

  Arguments passed to
  [`tbod_get_dataset`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
  except `id`.

## Value

A tibble or sf object with retrieval provenance attached.

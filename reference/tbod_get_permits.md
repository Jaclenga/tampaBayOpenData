# Retrieve bundled Tampa permit locations

Calls
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
for the bundled `construction-permits` layer. It reflects the City's
active permit viewer; the source is not a complete historical archive of
every permit.

## Usage

``` r
tbod_get_permits(...)
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
  tbod_get_permits(limit = 10)
}
```

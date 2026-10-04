# Retrieve City of Tampa permit locations

A thin wrapper for `get_dataset("construction-permits", ...)`. The
source is the City's PermitsAll layer used by its active-permits viewer,
not a guaranteed historical archive of every permit. Source values and
scope are preserved.

## Usage

``` r
get_permits(...)
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
if (FALSE) get_permits(limit = 10) # \dontrun{}
```

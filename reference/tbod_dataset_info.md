# Inspect a dataset and its source

Accepts a bundled ID, one-row discovery result, stable ArcGIS ID, or
direct public HTTPS layer URL. A checked ID reads its bundled record
offline; a stable ArcGIS ID resolves the current portal item.
`refresh = TRUE` retrieves current fields, aliases, types, geometry,
CRS, query capabilities, and editing metadata. The registry's `verified`
date records an endpoint check, not record freshness. Use
[`tbod_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_schema.md)
to inspect the schema or
[`tbod_check_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_check_schema.md)
to compare it with the checked snapshot.

## Usage

``` r
tbod_dataset_info(
  id,
  jurisdiction = NULL,
  refresh = FALSE,
  timeout = 30,
  total_timeout = 60,
  portal = NULL
)
```

## Arguments

- id:

  Bundled ID, one-row discovery result, stable ArcGIS ID, or public
  HTTPS ArcGIS layer URL.

- jurisdiction:

  Optional bundled catalog jurisdiction. `NULL` resolves a unique
  bundled ID and preserves a discovery result's jurisdiction. Direct
  URLs do not accept a jurisdiction override.

- refresh:

  Whether to request current ArcGIS layer metadata.

- timeout:

  Per-request timeout in seconds.

- total_timeout:

  Maximum elapsed seconds for inspection, including metadata requests
  and retries. Defaults to 60; `Inf` disables it.

- portal:

  Optional ArcGIS sharing REST portal URL when `id` is a stable
  `arcgis:<item-id>:<layer-id>` identifier.

## Value

A named list with the dataset ID, title, publisher, jurisdiction, source
and service URLs, scope, and terms. With `refresh = TRUE`, it also
contains `fields` (a tibble of source names, types, and aliases),
`metadata` (raw ArcGIS layer metadata), and UTC `inspected_at`.

## Examples

``` r
info <- tbod_dataset_info("construction-permits")
info[c("id", "title", "publisher", "source_url")]
#> $id
#> [1] "construction-permits"
#> 
#> $title
#> [1] "Permits (active GIS view)"
#> 
#> $publisher
#> [1] "City of Tampa"
#> 
#> $source_url
#> [1] "https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer/0"
#> 
```

# Retrieve a direct ArcGIS layer URL

Convenience entry point for
[`tbod_get_dataset`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
with a direct ArcGIS layer URL. Provenance is `not_checked`.

## Usage

``` r
tbod_get_arcgis_layer(
  url, where = "1=1", fields = NULL, spatial = FALSE, out_sr = NULL,
  order_by = NULL, limit = Inf, page_size = NULL, query = list(),
  timeout = 30, total_timeout = 120, integrity = "auto"
)
```

## Arguments

- url:

  Public HTTPS ArcGIS FeatureServer or MapServer layer URL.

- where:

  ArcGIS SQL WHERE clause; defaults to all records.

- fields:

  Exact source field names, or `NULL` or `"*"` for all nongeometry
  attributes.

- spatial:

  Return an `sf` object. Requires the optional sf package.

- out_sr:

  Optional output spatial reference ID; requires `spatial = TRUE`.

- order_by:

  Optional source fields with ASC or DESC.

- limit:

  Maximum number of records; `Inf` retrieves all.

- page_size:

  Optional positive batch size.

- query:

  Named list of advanced ArcGIS filter parameters.

- timeout:

  Per-request timeout in seconds.

- total_timeout:

  Overall operation budget in seconds.

- integrity:

  `"auto"` or `"full"` record membership validation.

## Value

A tibble or sf object with retrieval provenance attached.

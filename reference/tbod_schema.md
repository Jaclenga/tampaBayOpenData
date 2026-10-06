# Inspect a dataset schema

For a checked dataset, the default returns the bundled schema snapshot
without a network request. `refresh = TRUE` requests current ArcGIS
layer metadata. A direct ArcGIS layer URL or discovered descriptor has
no bundled expected schema and requires `refresh = TRUE`. Call
[`tbod_check_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_check_schema.md)
to compare a current service against its expected schema. A stable
ArcGIS item ID from an Enterprise portal can be resolved with `portal`.

## Usage

``` r
tbod_schema(
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

  Checked dataset ID, discovered descriptor, stable ArcGIS item ID, or
  public HTTPS ArcGIS layer URL.

- jurisdiction:

  Optional checked-catalog jurisdiction. `NULL` resolves a unique
  bundled ID and preserves a discovery row's source. Direct URLs do not
  accept a jurisdiction override.

- refresh:

  Request current layer metadata when TRUE.

- timeout:

  Per-request timeout in seconds.

- total_timeout:

  Overall operation budget in seconds; `Inf` disables it.

- portal:

  Optional public ArcGIS sharing REST portal URL for a stable
  `arcgis:<item-id>:<layer-id>` identifier. It does not apply to other
  IDs.

## Value

A list with endpoint, a tibble of field names, types and aliases,
geometry type, spatial reference, object-ID field, and dataset ID.

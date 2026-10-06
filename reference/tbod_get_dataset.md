# Retrieve a bundled, discovered, or direct ArcGIS dataset

Retrieves a checked catalog entry, a discovered layer, or a direct
ArcGIS FeatureServer or MapServer layer. Direct URL provenance is
`not_checked`. The unprefixed entry points remain available for existing
code.

## Usage

``` r
tbod_get_dataset(
  id, jurisdiction = NULL, where = "1=1", fields = NULL, spatial = FALSE,
  out_sr = NULL, order_by = NULL, limit = Inf, page_size = NULL,
  query = list(), timeout = 30, total_timeout = 120,
  integrity = "auto", portal = NULL
)
```

## Arguments

- id:

  Bundled ID, one-row discovery result, stable
  `arcgis:<item-id>:<layer-id>` identifier, or public HTTPS ArcGIS layer
  URL ending in `/FeatureServer/<id>` or `/MapServer/<id>`.

- jurisdiction:

  Optional bundled catalog jurisdiction. `NULL` resolves a unique
  checked ID and preserves a discovery row's jurisdiction. Direct URLs
  use `"unspecified"` and do not accept a jurisdiction override.

- where:

  ArcGIS SQL WHERE clause; defaults to all records.

- fields:

  Exact source field names, or `NULL` or `"*"` for all nongeometry
  attributes.

- spatial:

  Return an `sf` object. Requires the optional sf package.

- out_sr:

  Optional positive output spatial reference ID for server projection;
  requires `spatial = TRUE`.

- order_by:

  Optional source fields with ASC or DESC, such as `"LASTUPDATE DESC"`.

- limit:

  Maximum number of records. `Inf` retrieves all; zero returns a typed
  empty result.

- page_size:

  Optional positive batch size, bounded by service limits.

- query:

  Named list of advanced ArcGIS filter parameters, such as `geometry`,
  `time`, and `spatialRel`.

- timeout:

  Per-request timeout in seconds.

- total_timeout:

  Overall operation budget in seconds; `Inf` disables it.

- integrity:

  `"auto"` uses bounded preview validation when possible; `"full"`
  always requires the complete object-ID manifest.

- portal:

  Optional public HTTPS ArcGIS sharing REST portal root for a stable
  ArcGIS ID from a custom Enterprise portal. Not used with other input
  types.

## Value

A tibble or sf object with source, completeness, retrieval, and schema
metadata attached. Read the full record with
[`tbod_provenance`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_provenance.md).

## Details

Retrieval requests live layer metadata and validates pagination and
record membership. A bundled layer's metadata is compared with its
expected schema; compatible changes warn and incompatible changes fail
before querying. Use
[`tbod_check_schema`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_check_schema.md)
to inspect the differences.

## Examples

``` r
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  permits <- tbod_get_dataset("construction-permits", limit = 5)
  tbod_provenance(permits)$source_url
}
```

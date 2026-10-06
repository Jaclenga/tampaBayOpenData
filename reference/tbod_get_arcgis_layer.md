# Retrieve a direct ArcGIS layer URL

Calls
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
with a public HTTPS ArcGIS FeatureServer or MapServer layer URL. Direct
layers have `not_checked` provenance and no inferred publisher or portal
item identity.

## Usage

``` r
tbod_get_arcgis_layer(
  url,
  where = "1=1",
  fields = NULL,
  spatial = FALSE,
  out_sr = NULL,
  order_by = NULL,
  limit = Inf,
  page_size = NULL,
  query = list(),
  timeout = 30,
  total_timeout = 120,
  integrity = "auto"
)
```

## Arguments

- url:

  Public HTTPS ArcGIS layer URL.

- where:

  ArcGIS SQL WHERE clause using source field names; defaults to `"1=1"`.
  Inspect names with `tbod_dataset_info(url, refresh = TRUE)`.

- fields:

  Character vector of exact source field names, or `NULL` or `"*"` for
  all nongeometry attributes. An object-ID field is requested internally
  for integrity checks and omitted from the result if unselected.

- spatial:

  Return an `sf` object. Requires the optional sf package and supported
  geometry with a reliably determined CRS.

- out_sr:

  Optional positive ArcGIS/EPSG spatial reference ID for server
  projection, such as 4326. Requires `spatial = TRUE`; `NULL` keeps the
  native CRS. The response must confirm a requested projection.

- order_by:

  Source fields with ASC or DESC, such as
  `c("LASTUPDATE DESC", "RECORD_ID ASC")`. Requires server ordering and
  offset pagination; an object-ID tie breaker is added automatically.

- limit:

  Maximum records. `Inf` retrieves all; zero returns a typed empty
  result. A deliberate subset is `complete = FALSE` in
  [`tbod_provenance()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_provenance.md)
  when more matching records exist.

- page_size:

  Optional positive integer batch size, capped at 1,000 and the service
  maximum.

- query:

  Named list of advanced ArcGIS filters: `geometry`, `geometryType`,
  `inSR`, `spatialRel`, `relationParam`, `time`, `distance`, `units`,
  `gdbVersion`, `historicMoment`, `sqlFormat`, and
  `datumTransformation`. Values can be scalars or JSON-style lists.
  Response format, field selection, aggregation, geometry
  simplification, and pagination parameters are protected.

- timeout:

  Per-request timeout in seconds. Transient transport and HTTP failures
  may receive three attempts; a generic ArcGIS query error may receive
  four.

- total_timeout:

  Overall operation budget in seconds. Defaults to 120; `Inf` disables
  it. Requests and retry waits use the remaining budget.

- integrity:

  `"auto"` (default) uses bounded preview validation when a finite limit
  is at most 1,000, more than 10,000 records match, and the layer
  supports ordering and pagination. The returned IDs are checked against
  the original filter. Full retrieval always uses the full object-ID
  manifest; `"full"` requires it even for a preview. A zero limit
  requests only the count. Provenance records the method used.

## Value

A tibble or sf object with source, completeness, and retrieval metadata
attached. Read it with
[`tbod_provenance()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_provenance.md).

## Examples

``` r
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  url <- tbod_dataset_info("construction-permits")$source_url
  data <- tbod_get_arcgis_layer(url, limit = 10)
  tbod_provenance(data)$validation_status
}
```

# Retrieve a compatible ArcGIS layer by URL

Reads a public HTTPS ArcGIS FeatureServer or MapServer layer through the
same checked pagination and parsing engine as
[`get_dataset()`](https://Jaclenga.github.io/tampaBayOpenData/reference/get_dataset.md).
Pass a layer URL ending in `/FeatureServer/<id>` or `/MapServer/<id>`.
This direct path is marked `not_checked` in
[`dataset_provenance()`](https://Jaclenga.github.io/tampaBayOpenData/reference/dataset_provenance.md);
it has no portal item ID. A table without geometry can be retrieved with
`spatial = FALSE`.

## Usage

``` r
get_arcgis_layer(
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

  ArcGIS SQL WHERE clause, using actual source field names. Defaults to
  `"1=1"` (all records). See
  [`dataset_info()`](https://Jaclenga.github.io/tampaBayOpenData/reference/dataset_info.md)
  with `refresh = TRUE`.

- fields:

  Character vector of exact source field names, or NULL/`"*"` for all
  nongeometry attributes. An object-ID field is requested internally for
  integrity checks and removed when it was not selected.

- spatial:

  Return an `sf` object. Requires the optional sf package and a layer
  with supported geometry and a reliably determined CRS.

- out_sr:

  Optional positive ArcGIS/EPSG spatial reference ID for server
  projection, such as 4326. Used only with `spatial = TRUE`; NULL keeps
  the native CRS. A projection response must confirm its spatial
  reference.

- order_by:

  Optional source fields with ASC/DESC, such as
  `c("LASTUPDATE DESC", "RECORD_ID ASC")`. Requires server ordering and
  offset pagination. An object-ID tie breaker is added automatically.

- limit:

  Maximum number of records; Inf retrieves all, and 0 returns a typed
  empty result. A deliberate subset is recorded as incomplete in
  [`dataset_provenance()`](https://Jaclenga.github.io/tampaBayOpenData/reference/dataset_provenance.md)
  when additional matching records exist.

- page_size:

  Optional positive integer batch size. Defaults to at most 1,000,
  bounded by the advertised service maximum; larger values are capped.

- query:

  Named list of advanced ArcGIS filter parameters: `geometry`,
  `geometryType`, `inSR`, `spatialRel`, `relationParam`, `time`,
  `distance`, `units`, `gdbVersion`, `historicMoment`, `sqlFormat`,
  `datumTransformation`. Values can be scalars or JSON-style lists.
  Response format, field selection, aggregation, geometry
  simplification, and pagination parameters are protected.

- timeout:

  Timeout in seconds for each HTTP attempt. Transient transport and HTTP
  failures may receive three attempts; one generic ArcGIS query error
  may receive four.

- total_timeout:

  Overall operation time budget in seconds. Defaults to 120; use Inf to
  disable it. Requests and retry waits use the remaining budget. Parsing
  is checked after it finishes rather than interrupted.

- integrity:

  `"auto"` (default) uses a bounded preview when a finite limit is at
  most 1,000, more than 10,000 records match, and the layer supports
  ordering and pagination. Returned IDs are verified against the
  original filter, without retrieving all matching IDs. Full retrieval
  always uses the full manifest. `"full"` requires that manifest even
  for a preview. A zero limit requests only the count. Provenance
  records the verification method and never labels a deliberate subset
  complete.

## Value

A tibble, or an sf object when `spatial = TRUE`, with source, retrieval,
and completeness details attached as attributes. Use
[`dataset_provenance()`](https://Jaclenga.github.io/tampaBayOpenData/reference/dataset_provenance.md)
to read the full provenance record; its `validation_status` is
`not_checked` for a direct URL.

## Examples

``` r
if (FALSE) { # \dontrun{
data <- get_arcgis_layer(
  "https://arcgis.tampagov.net/arcgis/rest/services/Parks/ParksPolygons/MapServer/0",
  limit = 10)
dataset_provenance(data)
} # }
```

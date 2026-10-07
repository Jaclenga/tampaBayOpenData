# Retrieve a checked, discovered, or direct ArcGIS dataset

Accepts a checked catalog ID, a one-row discovery result, a stable
`arcgis:<item-id>:<layer-id>` identifier, or a public HTTPS ArcGIS layer
URL ending in `/FeatureServer/<id>` or `/MapServer/<id>`. For a stable
ArcGIS ID from an Enterprise portal, supply that portal's sharing REST
URL in `portal`. Direct URLs use the same retrieval engine and carry
`not_checked` provenance. For a layer in the checked catalog, retrieval
compares current metadata with its expected schema, warns for compatible
drift, and errors before querying for incompatible drift. Use
[`tbod_check_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_check_schema.md)
to inspect the differences.

## Usage

``` r
tbod_get_dataset(
  id,
  jurisdiction = NULL,
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
  integrity = "auto",
  portal = NULL
)
```

## Arguments

- id:

  Bundled ID, one-row discovery result, stable
  `arcgis:<item-id>:<layer-id>` identifier, or public HTTPS ArcGIS layer
  URL ending in `/FeatureServer/<id>` or `/MapServer/<id>`.

- jurisdiction:

  Optional checked-catalog jurisdiction. `NULL` resolves a unique
  checked ID across the bundled catalog and preserves the source
  jurisdiction of a discovery result. Direct URLs use `"unspecified"`
  and do not accept a jurisdiction override.

- where:

  ArcGIS SQL WHERE clause using source field names; defaults to `"1=1"`
  for all records. Inspect names with
  `tbod_dataset_info(id, refresh = TRUE)`.

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

- portal:

  Optional public HTTPS ArcGIS sharing REST portal URL for a stable
  `arcgis:<item-id>:<layer-id>` identifier. Omit to use the global
  ArcGIS item lookup. This argument does not apply to other input types.

## Value

A tibble, or an sf object when `spatial = TRUE`. `source`, `dataset_id`,
`jurisdiction`, and `retrieved_at` attributes record the source and
retrieval. Read the complete record with
[`tbod_provenance()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_provenance.md).

## Details

Retrieval requests the current layer schema and matching count. Full
requests also retrieve and validate an object-ID manifest. A small
preview of a large queryable layer can validate only its returned IDs
against the original filter. Missing or duplicate records, truncated
manifests, unexpected responses, and upstream errors fail explicitly.
Full retrieval requires a complete manifest and must be narrowed by
filters if more than one million records match. Use
[`tbod_download_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_download_dataset.md)
to save validated chunks to disk.

Source field names, strings, coded values, and date-looking strings are
preserved. ArcGIS epoch-millisecond dates become UTC POSIXct and
date-only fields become Date. Dates declared to have an unknown timezone
remain raw milliseconds with a warning; UTC editor tracking dates can
still convert. Integer values remain integers when safe, larger numeric
values become doubles, and exact big integers can be represented as
character values. NULL or absent attributes become typed missing values.
Spatial results use two-dimensional XY coordinates and exclude Z and M
values.

The package does not cache live data. Record membership changes detected
during retrieval cause an error, but attribute changes cannot be frozen.
Accepted responses are limited to 50 MiB and 64 nested JSON containers;
requests do not follow redirects. Native curl, GDAL, and PROJ parsing
remains subject to the installed libraries' behavior.

## Examples

``` r
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  data <- tbod_get_dataset("construction-permits", limit = 5)
  tbod_provenance(data)$source_url
}
```

# Download a direct ArcGIS layer into resumable local chunks

Uses the same resumable, bounded-memory path as
[`download_dataset()`](https://Jaclenga.github.io/tampaBayOpenData/reference/download_dataset.md).
A direct layer URL retains `not_checked` provenance and no inferred
publisher identity.

## Usage

``` r
download_arcgis_layer(
  url,
  path,
  where = "1=1",
  fields = NULL,
  spatial = FALSE,
  out_sr = NULL,
  page_size = 1000,
  query = list(),
  timeout = 30,
  total_timeout = Inf,
  resume = TRUE
)
```

## Arguments

- url:

  Public HTTPS ArcGIS FeatureServer or MapServer layer URL.

- path:

  Local directory for the manifest, checkpoints, and chunk files.

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

- page_size:

  Positive integer batch size, capped at 1,000 and the service maximum.
  The effective batch size must remain unchanged when resuming.

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

  Overall operation deadline in seconds. The default `Inf` permits a
  long download; a finite deadline leaves completed chunks available for
  a later resume.

- resume:

  Reuse a matching saved download and skip validated chunks.

## Value

A named list with `path`, ordered chunk `files`, `matched_rows`,
`returned_rows`, `complete`, and summary `source` provenance, as
described in
[`download_dataset()`](https://Jaclenga.github.io/tampaBayOpenData/reference/download_dataset.md).
Direct URLs have `not_checked` provenance.

## Examples

``` r
if (FALSE) { # \dontrun{
url <- paste0("https://gis.myclearwater.com/arcgis/rest/services/",
  "ArcGISMapServices/Clearwater_Park_Buffers/MapServer/0")
saved <- download_arcgis_layer(url, "park-buffer-download", page_size = 50)
} # }
```

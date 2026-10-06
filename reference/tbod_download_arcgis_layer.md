# Download a direct ArcGIS layer URL

Uses
[`tbod_download_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_download_dataset.md)
with a public HTTPS ArcGIS FeatureServer or MapServer layer URL. The
direct source has `not_checked` provenance and no inferred publisher
identity. A saved manifest fixes the endpoint, query, fields, schema,
CRS, IDs, and batch size; a resumed call rechecks them before reusing
validated chunks. See
[`tbod_download_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_download_dataset.md)
for the directory, lock, and record-change rules.

## Usage

``` r
tbod_download_arcgis_layer(
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

  Public HTTPS ArcGIS layer URL.

- path:

  Local directory for the manifest, checkpoints, and chunk files.

- where:

  ArcGIS SQL WHERE clause using source field names; defaults to `"1=1"`.
  Inspect names with `tbod_dataset_info(url, refresh = TRUE)`.

- fields:

  Character vector of exact source field names, or `NULL` or `"*"` for
  all nongeometry attributes. Object IDs remain in chunk provenance even
  if the column was not selected.

- spatial:

  Write `sf` chunks; requires the optional sf package and a layer with
  supported geometry and a known CRS.

- out_sr:

  Optional positive ArcGIS/EPSG output reference for server projection;
  requires `spatial = TRUE`. `NULL` keeps the native CRS.

- page_size:

  Positive integer batch size capped at 1,000 and the service maximum.
  The effective size must stay fixed when resuming.

- query:

  Named list of advanced ArcGIS filters such as `geometry`,
  `spatialRel`, and `time`. Response format, field selection,
  aggregation, geometry simplification, and pagination parameters are
  protected.

- timeout:

  Per-request timeout in seconds.

- total_timeout:

  Overall operation deadline in seconds. The default `Inf` allows a long
  download; completed chunks remain for a later resume if a finite
  deadline expires.

- resume:

  Reuse a matching saved download and skip validated chunks.

## Value

A named list with the download path, ordered chunk files, matched and
returned row counts, completeness, and summary provenance.

## Examples

``` r
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  url <- tbod_dataset_info("construction-permits")$source_url
  tbod_download_arcgis_layer(url, tempfile("permit-url-download-"),
    where = "OBJECTID <= 10", page_size = 5)
}
```

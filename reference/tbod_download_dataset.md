# Download an ArcGIS dataset into resumable chunks

Downloads a bundled, discovered, or direct ArcGIS layer in bounded
chunks. The `tbod_download_arcgis_layer` entry point accepts only direct
URLs. Bundled checked layers are compared with expected schemas before
downloading; compatible drift warns and incompatible drift stops the
download.

## Usage

``` r
tbod_download_dataset(
  id, path, jurisdiction = NULL, where = "1=1", fields = NULL,
  spatial = FALSE, out_sr = NULL, page_size = 1000, query = list(),
  timeout = 30, total_timeout = Inf, resume = TRUE, portal = NULL
)

tbod_download_arcgis_layer(
  url, path, where = "1=1", fields = NULL, spatial = FALSE,
  out_sr = NULL, page_size = 1000, query = list(), timeout = 30,
  total_timeout = Inf, resume = TRUE
)
```

## Arguments

- id:

  Bundled ID, one-row discovery result, stable ArcGIS ID, or direct
  public HTTPS layer URL.

- url:

  Public HTTPS ArcGIS FeatureServer or MapServer layer URL.

- path:

  Local directory for manifest, checkpoints, and chunk files.

- jurisdiction:

  Optional bundled catalog jurisdiction. `NULL` resolves a unique ID or
  preserves the discovery source. Direct URLs do not accept a
  jurisdiction override.

- where:

  ArcGIS SQL WHERE clause.

- fields:

  Exact source field names, or `NULL` or `"*"` for all nongeometry
  attributes.

- spatial:

  Write `sf` chunks. Requires the optional sf package.

- out_sr:

  Optional output spatial reference ID; requires `spatial = TRUE`.

- page_size:

  Positive batch size, capped at 1,000 and the service maximum.

- query:

  Named list of advanced ArcGIS filter parameters.

- timeout:

  Per-request timeout in seconds.

- total_timeout:

  Overall operation budget in seconds; `Inf` permits a long download.

- resume:

  Reuse a matching saved download and skip validated chunks.

- portal:

  Optional sharing REST portal root for a stable ArcGIS ID from a custom
  Enterprise portal.

## Value

A summary with the download path, ordered chunk files, matched and
returned row counts, completeness, and provenance.

# Retrieving and downloading data

Use
[`get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/get_dataset.md)
for a checked package ID, a one-row discovery result, or a stable
discovered ID. Use
[`get_arcgis_layer()`](https://jaclenga.github.io/tampaBayOpenData/reference/get_arcgis_layer.md)
when you already have a compatible public HTTPS ArcGIS layer URL. Both
paths use the same retrieval, type conversion, integrity checks, and
provenance. These examples contact live publishers when run in an R
session; none run during the site build.

## Retrieve and filter records

``` r

library(tampaBayOpenData)

permits <- get_dataset(
  "construction-permits",
  where = "PROJECTSTATUS IS NOT NULL",
  fields = c("RECORD_ID", "PROJECTSTATUS", "LASTUPDATE"),
  limit = 100
)
head(permits)
dataset_provenance(permits)[c("matched_rows", "returned_rows", "complete", "integrity")]
```

`where` uses ArcGIS SQL, not Socrata SoQL, and `fields` requires exact
source field names. Inspect current fields with
`dataset_info("construction-permits", refresh = TRUE)$fields`; its
metadata also reports query capabilities. `query` accepts supported
advanced ArcGIS spatial, time, and version filters. It does not allow
overriding parameters that control the response format, field selection,
aggregation, geometry simplification, or pagination; see
[`?get_dataset`](https://jaclenga.github.io/tampaBayOpenData/reference/get_dataset.md)
for the accepted names.

The default `limit = Inf` retrieves all matches. A finite limit
deliberately returns a subset and
[`dataset_provenance()`](https://jaclenga.github.io/tampaBayOpenData/reference/dataset_provenance.md)
records `complete = FALSE` when additional records match. Use `order_by`
for a reproducible ordered subset only when the service supports
ordering and offset pagination; an object-ID tie breaker is added.
`limit = 0` returns a typed empty result after obtaining the matching
count.
[`get_permits()`](https://jaclenga.github.io/tampaBayOpenData/reference/get_permits.md),
[`get_development_cases()`](https://jaclenga.github.io/tampaBayOpenData/reference/get_development_cases.md),
and
[`get_capital_projects()`](https://jaclenga.github.io/tampaBayOpenData/reference/get_capital_projects.md)
are short calls to
[`get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/get_dataset.md)
for three checked Tampa layers.

For a one-row discovery result, pass the row itself so its source and
publisher travel with the request:

``` r

found <- search_datasets("housing", source = "live", portals = "city")
housing <- get_dataset(found[1, ], limit = 100)
dataset_provenance(housing)[c("publisher", "item_id", "validation_status")]
```

For a compatible direct layer, pass a URL ending in
`/FeatureServer/<id>` or `/MapServer/<id>`:

``` r

yard_waste <- get_arcgis_layer(
  "https://arcgis.tampagov.net/arcgis/rest/services/OpenData/SolidWaste/MapServer/4",
  limit = 10
)
dataset_provenance(yard_waste)$validation_status # "not_checked"
```

Direct URL access does not infer a publisher or ArcGIS portal item and
has `not_checked` validation status. Inspect the service’s source and
reuse terms yourself.

## Integrity and time budgets

Retrieval obtains a matching count and compares downloaded object IDs
with the applicable full or subset manifest. Missing, duplicate, or
unexpected records cause an error. For services with more than 10,000
matches and reliable ordering and pagination, an incomplete finite
preview of at most 1,000 rows can use an ordered sample and verify its
returned IDs with a subset manifest. Other requests use the full
matching ID manifest; `integrity = "full"` requests that path
explicitly. Provenance reports `subset-manifest`, `full-manifest`, or
`count-only` for `limit = 0` and never marks a deliberate subset
complete when more rows match. A full manifest of more than one million
matching records is rejected; narrow `where` or use an eligible bounded
preview.

These checks detect record-membership problems during a request, but a
live service can change record attributes between pages. A successful
download is not a frozen snapshot. The client does not keep a runtime
cache of the data.

`timeout` limits each HTTP attempt. `total_timeout` sets an operation
budget: 120 seconds for retrieval, 90 for catalog discovery, and 60 for
metadata inspection by default. Set `total_timeout = Inf` explicitly for
an operation without an overall deadline. Requests and retry waits use
the remaining budget. Parsing is checked after it finishes, so
computation can exceed the budget before a timeout is reported.

## Types and spatial results

Results preserve source column names and text values. ArcGIS
epoch-millisecond date fields become UTC `POSIXct` unless the source
declares an unknown time zone. In that case they remain raw milliseconds
with a warning; UTC editor-tracking creation and edit dates identified
by layer metadata are still converted. Date-only fields become `Date`;
time-only and timestamp-offset fields remain strings. Integer fields are
converted where safe, and large values retain an exact representation
when possible.

Install the optional `sf` package for spatial retrieval.
`spatial = TRUE` returns an `sf` object; `out_sr = 4326` requests server
projection to WGS 84. Omit `out_sr` to keep the source’s native CRS.
Point, line, and polygon layers are supported, including records with
missing geometry. A nonspatial table can be retrieved with
`spatial = FALSE`.

``` r

projects <- get_dataset(
  "development-cases", spatial = TRUE, out_sr = 4326
)
boundary <- get_dataset(
  "city-boundary", fields = "OBJECTID", spatial = TRUE, out_sr = 4326
)
sf::st_crs(projects)$epsg
```

Both layers use one CRS so they can share a map. Keep only nonempty case
geometries for the display; the full `projects` object remains available
for analysis:

``` r

mapped_projects <- projects[!sf::st_is_empty(projects), ]

plot(
  sf::st_geometry(boundary),
  col = "#EDF4F6", border = "#7898A5", lwd = 1.2,
  axes = TRUE, graticule = TRUE, col_graticule = "#DCE7EB",
  xlab = "Longitude", ylab = "Latitude",
  main = "Active development cases in Tampa"
)
if (nrow(mapped_projects) > 0L) {
  case_fill <- grDevices::adjustcolor("#E76F51", alpha.f = 0.7)
  plot(sf::st_geometry(mapped_projects), add = TRUE, pch = 21,
       bg = case_fill, col = "#9B4934", cex = 0.85)
  graphics::legend(
    "bottomleft", legend = "Development case location", pch = 21,
    pt.bg = case_fill, col = "#9B4934", bg = "white",
    box.col = "#DCE7EB", cex = 0.85
  )
}
```

The checked `city-boundary` layer follows a shoreline representation and
is map context, not a legal survey boundary. See [coverage and source
limits](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.md)
before interpreting a map or its record counts.

## Resume a large download

[`download_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/download_dataset.md)
writes bounded RDS chunks to a local directory outside the package
source. This avoids collecting all feature pages in memory; the full
matching ID manifest still uses memory and retains the one-million-match
limit. Each chunk is a tibble or, with `spatial = TRUE`, an `sf` object.
[`download_arcgis_layer()`](https://jaclenga.github.io/tampaBayOpenData/reference/download_arcgis_layer.md)
offers the same path for a compatible direct layer URL.

``` r

saved <- download_dataset(
  "construction-permits",
  path = "~/tampaBayOpenData-downloads/permits",
  fields = c("OBJECTID", "RECORD_ID", "LASTUPDATE"),
  page_size = 500,
  total_timeout = 600
)
saved$complete
first_chunk <- readRDS(saved$files[[1]])
dataset_provenance(first_chunk)
```

Repeat the same call to resume. The client rechecks the live schema and
complete matching ID manifest, verifies saved chunks against
checkpoints, and downloads missing chunks. Changed query options,
schema, CRS, endpoint, or ID membership require a new directory.
Temporary files from interrupted writes are ignored. The directory must
be empty on the first call, and `resume = FALSE` does not overwrite an
existing download. Chunk provenance describes each chunk;
`saved$complete` describes the whole matching download. Record
attributes may still change between requests or resumes, so the files
are not a frozen snapshot.

Downloads default to `total_timeout = Inf`; a finite deadline leaves
completed chunks available for a later resume. An exclusive directory
lock prevents concurrent writers. If an R process is terminated, confirm
it has stopped, then remove its empty `.lock` directory before resuming.
Normal completion and handled errors release the lock.

For source attribution and limitations, continue to [coverage and
provenance](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.md).
For the catalog’s scan behavior, see [discovering
data](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.md).

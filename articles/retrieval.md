# Retrieving and downloading data

[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
accepts a checked package ID, a discovery row, or a stable discovered
ID. For a public HTTPS ArcGIS layer URL, use
[`tbod_get_arcgis_layer()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_arcgis_layer.md).
Both use the same type conversion, integrity checks, and provenance. The
examples contact live publishers when run in R; none run during the site
build.

## Retrieve and filter records

``` r

library(tampaBayOpenData)

permits <- tbod_get_dataset(
  "construction-permits",
  where = "PROJECTSTATUS IS NOT NULL",
  fields = c("RECORD_ID", "PROJECTSTATUS", "LASTUPDATE"),
  limit = 100
)
head(permits)
tbod_provenance(permits)[c("matched_rows", "returned_rows", "complete", "integrity")]
```

`where` uses ArcGIS SQL; `fields` requires exact source field names.
Inspect current fields with
`tbod_dataset_info("construction-permits", refresh = TRUE)$fields`; its
metadata also reports query capabilities. `query` accepts supported
advanced ArcGIS spatial, time, and version filters. It does not allow
overriding parameters that control the response format, field selection,
aggregation, geometry simplification, or pagination; see
[`?tbod_get_dataset`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
for the accepted names.

The default `limit = Inf` retrieves all matches. A finite limit returns
a subset;
[`tbod_provenance()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_provenance.md)
sets `complete = FALSE` if more records match. For a reproducible
subset, use `order_by` when the service supports ordering and offset
pagination. The client adds an object-ID tie breaker. `limit = 0`
returns a typed empty result after counting matches.
[`tbod_get_permits()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_permits.md),
[`tbod_get_development_cases()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_development_cases.md),
and
[`tbod_get_capital_projects()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_capital_projects.md)
are shortcuts for three selected City of Tampa layers in the checked
catalog.

Pass a discovery row to carry its source and publisher into retrieval:

``` r

found <- tbod_search_datasets("housing", source = "live", portals = "city")
if (nrow(found)) {
  housing <- tbod_get_dataset(found[1, ], limit = 100)
  tbod_provenance(housing)[c("publisher", "item_id", "validation_status")]
}
```

For a compatible direct layer, pass a URL ending in
`/FeatureServer/<id>` or `/MapServer/<id>`:

``` r

yard_waste <- tbod_get_arcgis_layer(
  "https://arcgis.tampagov.net/arcgis/rest/services/OpenData/SolidWaste/MapServer/4",
  limit = 10
)
tbod_provenance(yard_waste)$validation_status # "not_checked"
```

Direct URL access has `not_checked` validation status and does not infer
a publisher or ArcGIS portal item. It does not accept a `jurisdiction`
override. Check the service’s source and reuse terms.

## Check the live schema

Checked layers have bundled field, geometry, CRS, object-ID, and
endpoint metadata. `tbod_schema(id)` reads it offline;
`tbod_schema(id, refresh = TRUE)` reads the current service.
`tbod_check_schema(id)` compares them:

``` r

expected <- tbod_schema("construction-permits")
report <- tbod_check_schema("construction-permits")
report$status
report$issues[, c("category", "severity", "field", "expected", "actual")]
```

The status is `"unchanged"`, `"compatible"`, or `"incompatible"`. Added
fields and changed aliases warn but allow retrieval. Removed or renamed
fields, type changes, and object-ID, geometry, CRS, or endpoint changes
stop retrieval before record queries. A vanished endpoint appears as
`endpoint_disappeared` in `report$issues`.

A direct URL or newly discovered layer has no bundled schema. Save its
current metadata as `expected` for a later check. Without it, an
untracked check returns `status = "untracked"`. For a stable ID from a
custom Enterprise portal, pass `portal` to
[`tbod_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_schema.md)
or
[`tbod_check_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_check_schema.md).

``` r

# Replace this example address with a public ArcGIS layer URL.
url <- "https://example.org/arcgis/rest/services/Example/FeatureServer/0"
baseline <- tbod_schema(url, refresh = TRUE)
later <- tbod_check_schema(url, expected = baseline)
```

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

These checks detect record-membership problems during a request. A live
service can still change record attributes between pages. The client
does not keep a runtime data cache.

`timeout` limits each HTTP attempt. `total_timeout` sets an operation
budget: 120 seconds for retrieval, 90 for catalog discovery, and 60 for
metadata inspection by default. Set `total_timeout = Inf` explicitly for
an operation without an overall deadline. Requests and retry waits use
the remaining budget. Parsing is checked after it finishes, so
computation can exceed the budget before a timeout is reported.

Requests use `tampaBayOpenData/0.1.0` as the default user agent.
Applications can identify themselves with
`options(tampaBayOpenData.user_agent = "my-project/1.0 (contact: me@example.org)")`;
set the option to `NULL` to restore the default.

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

projects <- tbod_get_dataset(
  "development-cases", spatial = TRUE, out_sr = 4326
)
boundary <- tbod_get_dataset(
  "city-boundary", fields = "OBJECTID", spatial = TRUE, out_sr = 4326
)
sf::st_crs(projects)$epsg
```

The layers use one CRS for the map. Exclude empty case geometries from
the display:

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

[`tbod_download_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_download_dataset.md)
writes RDS chunks to a local directory without collecting all feature
pages in memory. The full matching ID manifest still uses memory and has
the one-million-match limit. Chunks are tibbles or `sf` objects.
[`tbod_download_arcgis_layer()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_download_arcgis_layer.md)
handles direct URLs. For a stable ID from another ArcGIS Enterprise
portal, pass its sharing REST root as `portal`.

``` r

saved <- tbod_download_dataset(
  "construction-permits",
  path = "~/tampaBayOpenData-downloads/permits",
  fields = c("OBJECTID", "RECORD_ID", "LASTUPDATE"),
  page_size = 500,
  total_timeout = 600
)
saved$complete
first_chunk <- readRDS(saved$files[[1]])
tbod_provenance(first_chunk)
```

Repeat the same call to resume. The client rechecks the schema and full
ID manifest, verifies saved chunks against checkpoints, and downloads
missing chunks. Changed query options, schema, CRS, endpoint, or ID
membership require a new directory. The first call needs an empty
directory; `resume = FALSE` never overwrites an existing download.
Interrupted temporary files are ignored. Chunk provenance describes each
file; `saved$complete` describes the whole download. Records may change
between sessions, so the files are not a frozen snapshot.

Downloads default to `total_timeout = Inf`; a finite deadline leaves
completed chunks available for a later resume. An exclusive directory
lock prevents concurrent writers. If an R process is terminated, confirm
it has stopped, then remove its empty `.lock` directory before resuming.
Normal completion and handled errors release the lock.

For source attribution and limitations, continue to [coverage and
provenance](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.md).
For the catalog’s scan behavior, see [discovering
data](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.md).

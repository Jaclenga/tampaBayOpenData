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

Expect a tibble (a data frame) with up to 100 active permit-viewer
feature rows and the three requested columns. `RECORD_ID` identifies the
source record, `PROJECTSTATUS` is its label, and `LASTUPDATE` is an
update time, not an issue date. The filter excludes missing statuses but
does not select a particular status.

The provenance output is a named list: `matched_rows` counts matches at
the source, `returned_rows` counts downloaded rows, and `complete` says
whether all matches were returned. `integrity` names the membership
check used; it does not assess whether the publisher’s attributes are
correct.

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

In the issues table, `field` identifies an affected column, `expected`
is the saved definition, and `actual` is the current one; `category` and
`severity` describe the difference and its effect on retrieval. An empty
issues table means no reported differences, not that individual records
have been validated.

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
preview. If an automatic preview finds that the service ignores or
rejects result offsets despite advertising them, it can restart with a
full ID manifest and object-ID batches. This fallback is subject to the
same one-million-record manifest limit. An explicit `order_by` request
still fails when offsets cannot be used, because object-ID batches
cannot preserve that requested order.

These checks detect record-membership problems during a request. A live
service can still change record attributes between pages. The client
does not keep a runtime data cache.

The client caps each feature request at the layer’s advertised record
limit and uses object-ID batches when result offsets are unavailable. It
splits a batch if the service marks it as truncated or returns fewer IDs
than requested, even without a truncation flag. Explicit `order_by`
needs both server ordering and result-offset support; otherwise the
request fails. Persistently missing singleton records, duplicate or
unexpected IDs, and empty or repeated ordered pages stop retrieval
instead of producing a result marked complete.

`timeout` limits each HTTP attempt. `total_timeout` sets an operation
budget: 120 seconds for retrieval, 90 for catalog discovery, and 60 for
metadata inspection by default. Set `total_timeout = Inf` explicitly for
an operation without an overall deadline. Requests and retry waits use
the remaining budget. Parsing is checked after it finishes, so
computation can exceed the budget before a timeout is reported.

The default per-attempt `timeout` is 30 seconds. Connection
establishment has a separate 10-second limit, capped by the attempt
timeout and remaining budget. For a slow connection or a publisher
requiring a lower request rate, configure:

``` r

options(tampaBayOpenData.connect_timeout = 15,
        tampaBayOpenData.request_delay = 0.2)
# Restore defaults:
options(tampaBayOpenData.connect_timeout = NULL,
        tampaBayOpenData.request_delay = NULL)
```

Connection timeout accepts 0.001 to 3600 seconds; request delay accepts
0 to 3600 seconds. Pacing defaults to zero and adds a wait before every
HTTP attempt, including retries and metadata requests. It consumes
`total_timeout` and supplements retry backoff. It does not coordinate
separate R processes.

Temporary connection failures and timeouts, HTTP 429 and selected server
errors (500, 502, 503, 504), ArcGIS error objects with those codes
inside HTTP 200 responses, and a generic transient ArcGIS query error
are retried. Invalid queries, unavailable layers, authentication
failures, and other permanent errors fail immediately. The default is
three additional retries per retryable failure sequence. HTTP transport
failures and ArcGIS errors in successful HTTP responses have separate
bounded sequences, so a mix of failures can involve more than four HTTP
attempts overall. To change the limit for this R session, set an integer
from 0 to 10:

``` r

options(tampaBayOpenData.max_retries = 2L)
# Restore the default later with:
options(tampaBayOpenData.max_retries = NULL)
```

Retry delays use exponential backoff with jitter. A valid `Retry-After`
delay or HTTP date takes precedence, with a maximum wait of 30 seconds.
An invalid header falls back to backoff. `total_timeout` applies across
both sequences and can stop retries sooner. Once a retry limit is
reached, the error reports the operation, endpoint, and failed recovery
attempts.

If the server requests more than 30 seconds, retrieval stops and reports
the delay rather than retrying early. Retryable POST requests are
read-only ArcGIS queries, not edits. Malformed JSON and incompatible
response schemas fail without retrying. Diagnostics omit URL credentials
and query parameters.

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

Both results are `sf` tables: their geometry columns hold case points
and a boundary outline respectively. The printed `4326` confirms the
requested longitude-latitude coordinate reference system (CRS), the rule
for interpreting coordinates; it does not establish location accuracy.

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

The dots show where active case features are recorded relative to the
outline; nearby or overlapping dots do not by themselves establish a
count of distinct developments or completed buildings. Rows without
geometry remain in `projects` but cannot appear on this map.

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

`saved` is a download summary, not a table of permits. Its `files`
component lists local chunk paths; `first_chunk` contains only the first
file’s records, so that file alone should not be treated as the whole
download. A query with no matches may have no chunk to read; check
`length(saved$files)` first when adapting this example to a filtered
request.

Repeat the same call to resume. The client rechecks the schema and full
ID manifest, verifies saved chunks against checkpoints, and downloads
missing chunks. Changed query options, schema, CRS, endpoint, or ID
membership require a new directory. The first call needs an empty
directory; `resume = FALSE` never overwrites an existing download.
Interrupted temporary files are ignored. After all chunks have been
validated, an atomic `complete.rds` marker appears in `path`; an
interrupted first call leaves no marker. Once a resumed call confirms
the saved manifest still matches, it removes the old marker before
revalidating chunks and writes a new one only on success. A failure
before the manifest check leaves the marker from the previous successful
call. Chunk provenance describes each file; `saved$complete` describes
the whole download. Records may change between sessions, so the files
are not a frozen snapshot.

Downloads default to `total_timeout = Inf`; a finite deadline leaves
completed chunks available for a later resume. An exclusive directory
lock prevents concurrent writers. If an R process is terminated, confirm
it has stopped, then remove its empty `.lock` directory before resuming.
Normal completion and handled errors release the lock.

## Troubleshooting common errors

- **Dataset ID not found:** Search the checked catalog with
  `tbod_search_datasets("parks", source = "checked")` and use an ID from
  its results. A close suggestion in an error message is only a search
  aid.
- **Connection timeout or rate limit:** The publisher may be slow or
  busy. Try again later. If requests consistently time out while the
  service responds, consider increasing `timeout` or `total_timeout` for
  that call.
- **Unknown field or changed schema:** Check current field names with
  `tbod_dataset_info("construction-permits", refresh = TRUE)$fields`.
  For a checked ID, `tbod_check_schema("construction-permits")` shows
  changes that stopped retrieval.
- **Missing or repeated records:** The package stops rather than
  returning a result that may be incomplete. Try again later or narrow
  the `where` filter.
- **Download cannot resume:** Saved settings or records may differ from
  the current request, or a saved file may be damaged. Keep the existing
  files and start a new download in a different empty directory if they
  cannot be restored.

For source attribution and limitations, continue to [coverage and
provenance](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.md).
For the catalog’s scan behavior, see [discovering
data](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.md).

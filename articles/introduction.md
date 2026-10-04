# Discover and retrieve Tampa Bay ArcGIS data

`tampaBayOpenData` searches public ArcGIS datasets from Tampa,
St. Petersburg, Clearwater, Hillsborough County, Pinellas County, and
the Tampa Bay Regional Planning Council. It also includes 26 layers
across the three cities that package maintainers have checked. The same
client retrieves checked or newly discovered layers as R tables or
optional `sf` objects, with provenance and completeness information.

The checked catalog examples run offline. Live discovery and retrieval
examples are displayed but not executed during vignette builds; run them
in an R session with internet access.

## Start with a dataset

``` r

library(tampaBayOpenData)

search_datasets("parks")

parks <- get_dataset("stpete-parks")
```

Search returns a table of matches. Each `id` can be passed to
[`get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/get_dataset.md);
`stpete-parks` is a checked ID. By default, retrieval returns all
records as a tibble. Search scans live portals, and retrieval contacts
the publisher, so run these calls with internet access.

## Browse the checked catalog offline

``` r

library(tampaBayOpenData)
list_portals()
#> # A tibble: 6 × 9
#>   id         root  org_id publisher jurisdiction website verified   metadata_url
#>   <chr>      <chr> <chr>  <chr>     <chr>        <chr>   <date>     <chr>       
#> 1 city       http… IbNXl… City of … tampa        https:… 2026-10-02 https://tam…
#> 2 tbrpc      http… RgIBb… Tampa Ba… tampa-bay    https:… 2026-10-02 https://www…
#> 3 stpete     http… 9qPLj… City of … stpete       https:… 2026-10-02 https://csp…
#> 4 clearwater http… 3GsNo… City of … clearwater   https:… 2026-10-02 https://cit…
#> 5 hillsboro… http… apTfC… Hillsbor… hillsborough https:… 2026-10-02 https://hil…
#> 6 pinellas   http… f5HgU… Pinellas… pinellas     https:… 2026-10-02 https://pin…
#> # ℹ 1 more variable: evidence_url <chr>
list_datasets(source = "checked")[,
  c("id", "title", "jurisdiction", "validation_status")]
#> # A tibble: 26 × 4
#>    id                   title                     jurisdiction validation_status
#>    <chr>                <chr>                     <chr>        <chr>            
#>  1 construction-permits Permits (active GIS view) tampa        checked          
#>  2 development-cases    Active development coord… tampa        checked          
#>  3 capital-projects     Capital improvement proj… tampa        checked          
#>  4 city-boundary        Tampa boundary (shorelin… tampa        checked          
#>  5 neighborhoods        Neighborhood association… tampa        checked          
#>  6 council-districts    City council districts    tampa        checked          
#>  7 riverwalk            Tampa Riverwalk segments  tampa        checked          
#>  8 parks                Park polygons             tampa        checked          
#>  9 fire-stations        City of Tampa fire stati… tampa        checked          
#> 10 bike-lanes           Bicycle network segments  tampa        checked          
#> # ℹ 16 more rows
search_datasets("park", source = "checked", spatial = TRUE,
                jurisdiction = c("stpete", "clearwater"))
#> # A tibble: 2 × 23
#>   id             title description jurisdiction publisher source_url service_url
#>   <chr>          <chr> <chr>       <chr>        <chr>     <chr>      <chr>      
#> 1 stpete-parks   St. … Public par… stpete       City of … https://c… https://se…
#> 2 clearwater-pa… Clea… City of Cl… clearwater   City of … https://g… https://gi…
#> # ℹ 16 more variables: geometry_type <chr>, category <chr>, verified <date>,
#> #   terms <chr>, layer_id <int>, date_fields <list>, tags <list>,
#> #   item_id <chr>, portal <chr>, validation_status <chr>, modified <dttm>,
#> #   modified_source <chr>, service_type <chr>, layer_type <chr>,
#> #   categories <list>, original_metadata <list>
```

`source = "checked"` reads the bundled registry without a network
request. Checked IDs are stable package names, separate from ArcGIS item
and layer IDs. For catalog functions, `jurisdiction = "all"` is the
default. A code or vector filters both checked and live results:
`"tampa"`, `"tampa-bay"`, `"stpete"`, `"clearwater"`, `"hillsborough"`,
or `"pinellas"`. The `portals` argument selects live organizations:
`"city"` (Tampa), `"tbrpc"`, `"stpete"`, `"clearwater"`,
`"hillsborough"`, `"pinellas"`, or `"all"` (default).
[`list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_portals.md)
lists the configured publishers and their portal locations offline. The
county portals extend live discovery; the checked catalog still contains
26 city layers. Selecting a county with `source = "checked"` returns an
empty catalog. Retrieval and download functions retain their default
`jurisdiction = "tampa"`; omitting it also resolves uniquely named
checked IDs across cities.

Search the live portals when you need more than the checked catalog:

``` r

# The default `source = "all", portals = "all"` also includes checked entries.
found <- search_datasets("housing", source = "live", portals = "city")
found[, c("id", "title", "publisher", "geometry_type", "validation_status")]

# Inspect one candidate's source before retrieving it.
selected <- found[1, ]
selected[, c("item_id", "service_url", "layer_id", "portal")]
```

`validation_status = "checked"` means maintainers specifically tested
that layer. `"discovered"` identifies a candidate from a public portal
index; maintainers have not validated its contents or reuse terms.
Retrieval validates query responses and requires `Query` when the layer
declares its capabilities. Unchecked live IDs have the form
`arcgis:<item-id>:<layer-id>` and remain usable if a title changes. A
portal item may still be deleted or its service changed.
[`list_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_datasets.md)
searches all six public organizations by default; `source = "checked"`
remains available if the network is unavailable.

``` r

# A one-row discovery result carries its source and item metadata.
housing <- get_dataset(selected, limit = 100)
dataset_provenance(housing)[c("item_id", "portal", "validation_status")]

# Its ID can also be passed to get_dataset() in a later online session:
# housing <- get_dataset(selected$id[[1]], limit = 100)
```

The discovery result includes the item’s `modified` date, tags, and
service location when available. That date is not necessarily the last
update to its records. `max_items` limits portal items scanned per
organization, not layers; it defaults to 25. Set `max_items = Inf` for a
full scan. Inspect the catalog’s `discovery_complete`,
`discovery_truncated_portals`, and `discovery_scanned_items` attributes
before treating a bounded listing as a complete catalog.

### Narrow a search

Both
[`list_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_datasets.md)
and
[`search_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/search_datasets.md)
accept optional filters:

``` r

county_transport <- search_datasets(
  "road", source = "live", jurisdiction = "pinellas", spatial = TRUE,
  topic = "transportation", modified_after = as.Date("2025-01-01"),
  max_items = 10
)
county_transport[, c("id", "title", "publisher", "modified", "modified_source")]
```

`publisher` matches exact names from
[`list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_portals.md),
ignoring case; `validation_status` selects `"checked"` or
`"discovered"`. Live-only results can still contain checked matches.
`spatial = TRUE` selects geometry layers, `FALSE` selects tables, and
either filter excludes unknown geometry. `topic` matches literal
substrings in tags and categories, ignoring case. `category` matches a
complete category path or its final label, ignoring case. Character
filters accept vectors; values in one filter are alternatives, while
different filters must all match.

`modified_after` and `modified_before` are inclusive bounds on
`modified`. Use `Date` values or strict `"YYYY-MM-DD"` strings to
include whole UTC days, or `POSIXct` values for exact instants. Rows
with unknown item dates are dropped when a date bound is supplied.
`modified_source = "portal_item"` identifies a live item timestamp;
`"checked_snapshot"` identifies an upstream timestamp saved in the
checked registry. Neither establishes record freshness, and the checked
`verified` date remains a separate endpoint check.

Jurisdiction and publisher filters reduce the organizations scanned.
Other filters run after discovery and the checked overlay, so a bounded
`max_items` scan can miss matching items beyond that limit. Inspect
discovery attributes and increase the item limit when a broader search
is needed. When a live layer matches a checked endpoint, the result
keeps its checked identity and terms alongside current live tags,
categories, and item modification date.

## Inspect dataset metadata

``` r

info <- dataset_info("construction-permits")
info[c("title", "source_url", "scope_note", "verified")]
#> $title
#> [1] "Permits (active GIS view)"
#> 
#> $source_url
#> [1] "https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer/0"
#> 
#> $scope_note
#> [1] "The upstream service is described as data for an internal active-permits viewer, although its public Query endpoint is accessible without a token. The date fields are LASTUPDATE and CREATEDDATE; no permit issue-date field is advertised. No explicit dataset license was found on this exact FeatureServer service or in the selected public ArcGIS organization catalog. Do not infer the license of a separate MapServer layer."
#> 
#> $verified
#> [1] "2026-09-29"
```

`source_url` links to the checked City source, and `scope_note`
describes limits on what the dataset represents. The `verified` date
records an endpoint check, not the freshness of individual records. To
inspect current field names, request the live schema:

``` r

dataset_info("construction-permits", refresh = TRUE)$fields
```

## Retrieve records

``` r

permits <- get_dataset(
  "construction-permits",
  where = "PROJECTSTATUS IS NOT NULL",
  fields = c("RECORD_ID", "PROJECTSTATUS", "LASTUPDATE"),
  limit = 100
)
head(permits)
```

`where` uses ArcGIS SQL rather than Socrata SoQL, and `fields` uses
exact source names. By default, `limit = Inf` retrieves every match. A
finite limit returns a subset, and provenance marks it incomplete if
more records match. `order_by` requests server ordering where supported;
[`get_permits()`](https://jaclenga.github.io/tampaBayOpenData/reference/get_permits.md)
is a shortcut for this dataset. See
[`?get_dataset`](https://jaclenga.github.io/tampaBayOpenData/reference/get_dataset.md)
for other filters and limits.

For sources with more than 10,000 matches and reliable ordering and
pagination, finite previews of at most 1,000 rows verify the returned
IDs with a subset manifest. Other retrievals use a full manifest; set
`integrity = "full"` to request that explicitly. Provenance identifies
`subset-manifest`, `full-manifest`, or `count-only` for a zero-row
limit. A finite preview is marked incomplete when more records match.

`timeout` limits each HTTP attempt. The overall `total_timeout` defaults
to 120 seconds for retrieval, 90 seconds for catalog discovery, and 60
seconds for metadata inspection. Set `total_timeout = Inf` explicitly
for a long operation. Requests and retry waits use the remaining budget;
parsing is checked after it finishes and can exceed the budget before
reporting a timeout.

Results retain source field names and text fields. ArcGIS
epoch-millisecond date fields become UTC `POSIXct` unless the source
declares an unknown time zone. In that case they remain raw milliseconds
with a warning; UTC editor-tracking creation and edit dates identified
by the layer metadata are still converted. Date-only fields become
`Date`; time-only and timestamp-offset fields remain strings.

You can also retrieve a compatible public ArcGIS layer directly by its
URL:

``` r

direct <- get_arcgis_layer(
  "https://arcgis.tampagov.net/arcgis/rest/services/OpenData/SolidWaste/MapServer/4",
  limit = 10
)
dataset_provenance(direct)$validation_status # "not_checked" for direct URL access
```

For larger retrievals, write resumable chunks to a persistent directory
outside the package source and read one chunk at a time:

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

Repeat the same download call to resume. The client rechecks current
metadata and the full matching ID manifest, validates saved chunk
checksums and provenance, and skips completed chunks. Changed query
options, schema, CRS, or ID membership require a new directory. Chunk
attributes can vary across requests or resumes, so the files do not form
a frozen snapshot. Each chunk has its own completeness record;
`saved$complete` describes the whole matching download. This path keeps
only bounded feature batches in memory and retains the one-million-ID
manifest limit. Download operations default to `total_timeout = Inf`; a
finite deadline leaves completed chunks available for the next call.

An exclusive directory lock prevents concurrent writers. A terminated R
process can leave an empty `.lock` directory: confirm that process has
stopped before removing the lock and resuming.
[`download_arcgis_layer()`](https://jaclenga.github.io/tampaBayOpenData/reference/download_arcgis_layer.md)
supports the same chunked path for direct URLs.

## Explore the results

``` r

sort(table(permits$PROJECTSTATUS), decreasing = TRUE)
```

These counts describe the retrieved subset, not every matching permit.

## Work with spatial data

The same interface returns `sf` objects with `spatial = TRUE`. Install
the optional `sf` package if needed. After loading `tampaBayOpenData` in
the first example, run the next three chunks in order in an
internet-connected R session.

``` r

# Request one CRS for both layers so their coordinates can share a map.
projects <- get_dataset(
  "development-cases",
  spatial = TRUE,
  out_sr = 4326
)

# Only the boundary ID is needed; spatial = TRUE still returns its geometry.
boundary <- get_dataset(
  "city-boundary",
  fields = "OBJECTID",
  spatial = TRUE,
  out_sr = 4326
)
# Check the CRS reported for the case locations.
sf::st_crs(projects)$epsg
```

Both results are `sf` objects in WGS 84 (EPSG:4326). The CRS line
confirms the value for `projects`. Omitting `out_sr` keeps each layer’s
native CRS; point, line, and polygon layers use the same API.

Records without geometry remain in `projects`. Make a subset of
locations to plot:

``` r

# Preserve projects; create a plotting subset with nonempty geometries.
mapped_projects <- projects[!sf::st_is_empty(projects), ]
```

Draw the city boundary for context, then add the case locations:

``` r

# Draw the polygon first so it forms a backdrop for the case locations.
plot(
  sf::st_geometry(boundary),
  col = "#EDF4F6",
  border = "#7898A5",
  lwd = 1.2,
  axes = TRUE,
  graticule = TRUE,
  col_graticule = "#DCE7EB",
  xlab = "Longitude",
  ylab = "Latitude",
  main = "Active development cases in Tampa"
)

# Filled circles have separate outlines and translucent fills.
if (nrow(mapped_projects) > 0L) {
  case_fill <- grDevices::adjustcolor("#E76F51", alpha.f = 0.7)
  plot(
    sf::st_geometry(mapped_projects),
    add = TRUE,
    pch = 21,
    bg = case_fill,
    col = "#9B4934",
    cex = 0.85
  )

  # Match the legend symbol to the plotted points.
  graphics::legend(
    "bottomleft",
    legend = "Development case location",
    pch = 21,
    pt.bg = case_fill,
    col = "#9B4934",
    bg = "white",
    box.col = "#DCE7EB",
    cex = 0.85
  )
}
```

The `city-boundary` layer is adjusted to follow the shoreline. It
provides map context, not a legal survey boundary.

## Keep track of where your data came from

``` r

source <- dataset_provenance(projects)
saveRDS(
  list(data = projects, provenance = source),
  "development-cases.rds"
)
```

Provenance includes the publisher, source URL, portal and item ID when
known, validation status, query endpoint, retrieval time, row counts,
and completeness. Save it separately with your data because later R
transformations may discard custom attributes.

## Important limitations

The permit and development-case layers are active views, not necessarily
complete historical ledgers. Read `dataset_info(id)$scope_note` and
`dataset_info(id)$terms` before interpreting their coverage or reuse
terms.

Live ArcGIS data can change during a multi-request retrieval. The client
checks fetched IDs against the matching count and object-ID manifest
where applicable; these checks cannot freeze every attribute at one
instant.

If a field is uncertain, inspect
`dataset_info(id, refresh = TRUE)$fields`. For a temporary service
failure, check the source URL and retry. Full-manifest queries matching
more than one million records are rejected; narrow `where` first.
Eligible finite previews can verify a bounded subset instead.

Discovered items may lack clear reuse terms or may be stale in the
portal index. Review each item’s source and terms before analysis; the
package does not verify those terms. The package’s MIT license applies
to its code, not to data from either source organization.

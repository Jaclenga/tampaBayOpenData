# List datasets in the bundled catalog

By default, scans the configured Tampa Bay ArcGIS portals and combines
their layers with the bundled checked catalog. Use `source = "checked"`
to list checked entries offline. Live scans may be incomplete; see
Details for the result attributes. Use
[`tbod_discover()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_discover.md)
to scan another portal.

## Usage

``` r
tbod_list_datasets(
  jurisdiction = "all",
  source = "all",
  portals = "all",
  max_items = 25,
  timeout = 30,
  total_timeout = 90,
  publisher = NULL,
  validation_status = NULL,
  spatial = NULL,
  topic = NULL,
  category = NULL,
  modified_after = NULL,
  modified_before = NULL
)
```

## Arguments

- jurisdiction:

  Jurisdiction code or vector of codes from
  [`tbod_list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_portals.md),
  or `"all"` (default). Filters checked and live results and narrows the
  portal scan.

- source:

  `"all"` (default) combines live discovery with checked entries;
  `"live"` returns portal layers with checked matches marked;
  `"checked"` reads only the offline registry.

- portals:

  Configured publisher IDs from
  [`tbod_list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_portals.md),
  or `"all"`. This selects live portals and does not filter checked
  entries.

- max_items:

  Maximum number of service items scanned per selected portal. Defaults
  to 25; `Inf` follows all search pages. An item can expand to multiple
  layers, so this does not bound the row count.

- timeout:

  Per-request timeout in seconds.

- total_timeout:

  Overall operation budget, including retries and live discovery.
  Defaults to 90 seconds; `Inf` disables the deadline.

- publisher:

  Publisher name or vector, matched exactly without regard to case.
  Narrows both checked results and the live portal scan.

- validation_status:

  `"checked"`, `"discovered"`, or a vector of both; `NULL` includes
  both. `source = "live"` can include checked matches.

- spatial:

  `TRUE` selects layers with declared geometry, `FALSE` selects
  nonspatial tables, and `NULL` includes both and unknown geometry.

- topic:

  Word or vector matched as case-insensitive literal substrings in tags
  and categories; `NULL` disables the filter.

- category:

  Category or vector matched, ignoring case, against full source paths
  or their final labels.

- modified_after, modified_before:

  Inclusive modification bounds. A Date or YYYY-MM-DD string includes
  its full UTC day; POSIXct specifies an instant. Unknown modification
  times are excluded when a bound is set. This is an item or checked
  snapshot time, not record freshness.

## Value

A tibble with stable IDs, service and layer locations, portal and item
IDs when available, and `validation_status` of `"checked"` or
`"discovered"`. Live results include scan-completeness and issue
attributes described in Details.

## Details

Values within a filter are combined with OR; different filters and a
search query are combined with AND. Status, geometry, topic, category,
and date filters apply after the bounded live scan and checked overlay.
A capped scan can miss older matching items. Use `max_items = Inf` with
an appropriate time budget to follow all available index pages, and
inspect `attr(result, "discovery_complete")`. This flag describes the
selected public portal index scan, not every publisher service. Live
results also carry `discovery_issues`, `discovery_failed_portals`,
`discovery_scanned_items`, and `discovery_truncated_portals` attributes.
If every selected portal fails, `source = "all"` returns the checked
entries with failure details in these attributes; unknown scan counts
are `NA`.

## Examples

``` r
tbod_list_datasets(source = "checked")
#> # A tibble: 52 × 23
#>    id            title description jurisdiction publisher source_url service_url
#>    <chr>         <chr> <chr>       <chr>        <chr>     <chr>      <chr>      
#>  1 construction… Perm… Permit loc… tampa        City of … https://a… https://ar…
#>  2 development-… Acti… Locations … tampa        City of … https://a… https://ar…
#>  3 capital-proj… Capi… Locations … tampa        City of … https://t… https://ar…
#>  4 city-boundary Tamp… A Tampa ci… tampa        City of … https://t… https://ar…
#>  5 neighborhoods Neig… City of Ta… tampa        City of … https://t… https://ar…
#>  6 council-dist… City… Tampa City… tampa        City of … https://t… https://ar…
#>  7 riverwalk     Tamp… Tampa Rive… tampa        City of … https://t… https://ar…
#>  8 parks         Park… Park polyg… tampa        City of … https://a… https://ar…
#>  9 fire-stations City… Mapped Cit… tampa        City of … https://a… https://ar…
#> 10 bike-lanes    Bicy… Mapped Tam… tampa        City of … https://t… https://ar…
#> # ℹ 42 more rows
#> # ℹ 16 more variables: geometry_type <chr>, category <chr>, verified <date>,
#> #   terms <chr>, layer_id <int>, date_fields <list>, tags <list>,
#> #   item_id <chr>, portal <chr>, validation_status <chr>, modified <dttm>,
#> #   modified_source <chr>, service_type <chr>, layer_type <chr>,
#> #   categories <list>, original_metadata <list>
```

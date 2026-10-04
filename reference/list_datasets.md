# List Tampa Bay ArcGIS datasets

Live discovery searches the organizations in
[`list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_portals.md)
and expands public services into candidate layers and tables. Retrieval
requires Query when a layer supplies a capabilities list and validates
its query responses. The bundled registry supplies a separate
`"checked"` validation layer and remains available without a network
request. A portal item can be stale or a layer can change after
discovery.

## Usage

``` r
list_datasets(
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
  [`list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_portals.md),
  or `"all"` (default). Filters checked and live results and narrows the
  portal scan. A supported jurisdiction may have no checked entries.

- source:

  `"all"` (default) combines live discovery with the checked registry;
  `"live"` returns layers found through the portal with checked matches
  marked; `"checked"` reads only the offline registry.

- portals:

  Live organization IDs from
  [`list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_portals.md),
  or `"all"` (default). A character vector of IDs is also accepted.
  Intersects with jurisdiction and publisher filters before any portal
  requests. This does not filter the bundled checked catalog.

- max_items:

  Maximum number of portal service items to scan per selected
  organization. The default, 25, bounds the service scan; `Inf` follows
  all available search pages. This limits items, not expanded layers.
  Inspect `attr(result, "discovery_complete")` before treating a live
  result as a complete portal listing.

- timeout:

  Timeout in seconds for each HTTP attempt.

- total_timeout:

  Maximum elapsed seconds for the complete operation, including
  discovery and retries. Defaults to 90; `Inf` disables this limit.

- publisher:

  Publisher name or vector of names, matched exactly without regard to
  case. See
  [`list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_portals.md)
  for names. Filters all results and narrows the portal scan; an
  unmatched name returns no rows.

- validation_status:

  `"checked"`, `"discovered"`, or a vector of both. NULL includes both.
  This filters the final classification; `source = "live"` can include
  checked matches. Use `source = "checked"` for offline browsing.

- spatial:

  TRUE selects layers with declared geometry; FALSE selects nonspatial
  tables. NULL includes both and unknown geometry types.

- topic:

  Word or vector of words matched as case-insensitive literal substrings
  in tags and categories. NULL disables this filter.

- category:

  Category or vector of categories, matched exactly without regard to
  case against full source paths or their final labels.

- modified_after, modified_before:

  Inclusive modification bounds: a Date or YYYY-MM-DD string includes
  its entire UTC calendar day; POSIXct supplies an exact instant. Rows
  with unknown modification times are excluded when either bound is
  supplied. Modification is an item or checked snapshot timestamp, not
  record freshness; `modified_source` identifies its origin.

## Value

A tibble with stable IDs, service and layer locations, portal and item
IDs when available, and `validation_status` of `"checked"` or
`"discovered"`. The latter means the package has not checked that layer.
Skipped item errors are attached as `attr(result, "discovery_issues")`;
failed portal names are in `attr(result, "discovery_failed_portals")`.
`discovery_scanned_items` records item counts by portal;
`discovery_truncated_portals` identifies scans stopped at `max_items`.
`discovery_complete` is FALSE if a scan was truncated or any item or
portal failed. These attributes describe live discovery, not checked
coverage.

## Details

Values within a filter are combined with OR; different filters and the
search query are combined with AND. Status, geometry, topic, category,
and date filters apply after the bounded scan and checked overlay. A
capped scan can miss matching older items; inspect `discovery_complete`
and use `max_items = Inf` with an appropriate time budget for an
exhaustive scan.

## Examples

``` r
checked <- list_datasets(source = "checked")
checked[, c("id", "title", "jurisdiction", "validation_status")]
#> # A tibble: 35 × 4
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
#> # ℹ 25 more rows
if (FALSE) list_datasets() # \dontrun{}
```

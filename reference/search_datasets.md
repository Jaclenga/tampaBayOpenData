# Search Tampa Bay ArcGIS datasets

Live searches use the selected public ArcGIS portal indexes. Checked
entries are also matched locally by literal, case-insensitive words in
their ID, title, description, category, and tags. Portal search can
include other indexed fields, so its results need not follow the checked
catalog's literal matching.

## Usage

``` r
search_datasets(
  query,
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

- query:

  A single search string. Checked matching treats punctuation literally;
  live matching uses the ArcGIS portal search index.

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

A tibble with the catalog columns and, for live searches, the discovery
attributes described in
[`list_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_datasets.md).
A checked-only search reads the bundled registry without network access.

## Examples

``` r
permits <- search_datasets("permit", source = "checked")
permits[, c("id", "title", "jurisdiction")]
#> # A tibble: 1 × 3
#>   id                   title                     jurisdiction
#>   <chr>                <chr>                     <chr>       
#> 1 construction-permits Permits (active GIS view) tampa       
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  search_datasets("housing", max_items = 1)
}
```

# Search datasets in the bundled catalog

Searches checked Tampa Bay entries and, when requested, configured live
ArcGIS portals. Checked entries match literal, case-insensitive words in
their IDs, titles, descriptions, categories, and tags. Live searches use
each portal's index, so matching can differ. Use
[`tbod_discover()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_discover.md)
to search another ArcGIS portal.

## Usage

``` r
tbod_search_datasets(
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
  live matching uses the ArcGIS portal index.

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

A tibble with the same columns and live discovery attributes as
[`tbod_list_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_datasets.md).
A checked-only search requires no network request.

## Details

Values within a filter are combined with OR; different filters and the
search query are combined with AND. Filters apply after the bounded
scan, so a capped scan can miss matching items. See
[`tbod_list_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_datasets.md)
for the discovery attributes.

## Examples

``` r
tbod_search_datasets("permit", source = "checked")
#> # A tibble: 1 × 23
#>   id             title description jurisdiction publisher source_url service_url
#>   <chr>          <chr> <chr>       <chr>        <chr>     <chr>      <chr>      
#> 1 construction-… Perm… Permit loc… tampa        City of … https://a… https://ar…
#> # ℹ 16 more variables: geometry_type <chr>, category <chr>, verified <date>,
#> #   terms <chr>, layer_id <int>, date_fields <list>, tags <list>,
#> #   item_id <chr>, portal <chr>, validation_status <chr>, modified <dttm>,
#> #   modified_source <chr>, service_type <chr>, layer_type <chr>,
#> #   categories <list>, original_metadata <list>
```

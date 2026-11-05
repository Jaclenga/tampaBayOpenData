# Search checked and live ArcGIS datasets

Searches checked Tampa Bay entries and, when requested, configured live
ArcGIS portals. The checked catalog is a selected, offline registry;
live discovery searches each publisher's public portal index. Use
[`tbod_discover()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_discover.md)
to search another ArcGIS portal or a service URL.

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
  modified_before = NULL,
  limit = Inf
)
```

## Arguments

- query:

  A single search string. Checked matching treats punctuation literally
  and ignores case; its separate words must all match. Live matching
  uses the ArcGIS portal index. An empty or whitespace-only query lists
  datasets.

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

- limit:

  Maximum result rows returned after filtering and ranking. Defaults to
  `Inf`; use a nonnegative whole number, including `0`, or `Inf`. This
  does not cap the number of live service items scanned; see
  `max_items`.

## Value

A tibble with the same columns and live discovery attributes as
[`tbod_list_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_datasets.md).
A checked-only search requires no network request.

## Details

Values within a filter are combined with OR; different filters and the
search query are combined with AND. Publisher names are exact,
case-insensitive filters; use
[`tbod_list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_portals.md)
to inspect them. A publisher with no match returns no rows.

Checked entries search ID, title, description, publisher, category, and
tags. Exact title or ID matches rank first, then title or ID prefixes,
substrings, and matches across title or ID words. Tags, categories, and
publisher matches follow; description-only matches rank after those.
Within a rank, each word scores title, ID, tags or categories,
publisher, and description in that order; title, ID, and source URL then
break ties consistently. If no checked entry matches the literal query,
a spelling fallback may return close checked entries. Query words must
be alphanumeric, and words shorter than four characters have no typo
tolerance. The fallback does not change live portal search terms.

Live items come from the portal index, which can search fields not
exposed in returned rows. Available row metadata helps rank them, but an
indexed hit is retained even without a local text match. Layers found
both live and in the checked catalog appear once with `"checked"`
status. With `source = "all"`, checked matches remain available even
when a portal does not return them. `limit` applies after discovery,
overlay, filtering, and ranking. Even `limit = 0` still performs the
selected live scan and preserves its diagnostics.

Portal searches include public Feature Service and Map Service items and
expand supported, queryable layers. A private, unindexed, stale, or
unavailable item may be absent. `max_items` caps service items per
portal; item errors and capped scans can leave returned results
incomplete, and a timeout can stop the operation. Check
`attr(result, "discovery_complete")` and the issue, failed-portal,
scanned-item, and truncated-portal attributes described in
[`tbod_list_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_datasets.md).
Even a complete scan covers the public portal index, not every publisher
service.

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

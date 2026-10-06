# Browse datasets in the bundled catalog

These functions list and search the bundled Tampa Bay catalog and its
configured live portals. Use
[`tbod_discover`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_discover.md)
to scan a different ArcGIS portal. The unprefixed entry points remain
available for existing code.

## Usage

``` r
tbod_list_datasets(
  jurisdiction = "all", source = "all", portals = "all", max_items = 25,
  timeout = 30, total_timeout = 90, publisher = NULL,
  validation_status = NULL, spatial = NULL, topic = NULL, category = NULL,
  modified_after = NULL, modified_before = NULL
)

tbod_search_datasets(
  query, jurisdiction = "all", source = "all", portals = "all",
  max_items = 25, timeout = 30, total_timeout = 90, publisher = NULL,
  validation_status = NULL, spatial = NULL, topic = NULL, category = NULL,
  modified_after = NULL, modified_before = NULL
)
```

## Arguments

- query:

  Search text. Checked entries use literal, case-insensitive words; live
  searches use the portal index.

- jurisdiction:

  Bundled jurisdiction code or vector of codes; `"all"` includes all.

- source:

  `"checked"` reads the offline catalog, `"live"` scans configured
  portals, and `"all"` combines them.

- portals:

  Configured publisher IDs from
  [`tbod_list_portals`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_portals.md),
  or `"all"`.

- max_items:

  Maximum service items scanned per portal; `Inf` follows all search
  pages.

- timeout:

  Per-request timeout in seconds.

- total_timeout:

  Overall operation time budget in seconds; `Inf` disables it.

- publisher:

  Optional publisher name or vector of names.

- validation_status:

  Optional `"checked"` or `"discovered"` status filter.

- spatial:

  `TRUE` selects spatial layers, `FALSE` selects tables, and `NULL`
  includes both.

- topic:

  Optional words matched against tags and categories.

- category:

  Optional categories matched against full paths or final labels.

- modified_after, modified_before:

  Inclusive Date, YYYY-MM-DD, or POSIXct modification bounds.

## Value

A tibble of checked and/or discovered dataset descriptors. Live results
carry discovery completeness and issue attributes.

## Examples

``` r
tbod_list_datasets(source = "checked")
#> # A tibble: 35 × 23
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
#> # ℹ 25 more rows
#> # ℹ 16 more variables: geometry_type <chr>, category <chr>, verified <date>,
#> #   terms <chr>, layer_id <int>, date_fields <list>, tags <list>,
#> #   item_id <chr>, portal <chr>, validation_status <chr>, modified <dttm>,
#> #   modified_source <chr>, service_type <chr>, layer_type <chr>,
#> #   categories <list>, original_metadata <list>
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

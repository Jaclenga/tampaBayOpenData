# Discovering Tampa Bay data

`tampaBayOpenData` can search two related sources: a bundled catalog of
35 maintainer-checked layers, and public ArcGIS portal indexes operated
by six regional publishers. A checked layer has been configured and
validated by the package maintainers. A discovered layer is a candidate
found in a live portal index; its contents and reuse terms have not
received the same validation. The package does not host or mirror either
source’s records.

Live examples below are displayed but not run while the site is built.
The checked-catalog example runs offline.

## Start offline

``` r

library(tampaBayOpenData)

tampaBayOpenData::list_portals()[, c("id", "publisher", "jurisdiction")]
#> # A tibble: 6 × 3
#>   id           publisher                           jurisdiction
#>   <chr>        <chr>                               <chr>       
#> 1 city         City of Tampa                       tampa       
#> 2 tbrpc        Tampa Bay Regional Planning Council tampa-bay   
#> 3 stpete       City of St. Petersburg              stpete      
#> 4 clearwater   City of Clearwater                  clearwater  
#> 5 hillsborough Hillsborough County                 hillsborough
#> 6 pinellas     Pinellas County                     pinellas
tampaBayOpenData::list_datasets(source = "checked")[,
  c("id", "title", "jurisdiction", "validation_status")]
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
tampaBayOpenData::search_datasets(
  "park", source = "checked", spatial = TRUE,
  jurisdiction = c("stpete", "clearwater")
)
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
tampaBayOpenData::dataset_info("construction-permits")[
  c("title", "scope_note", "verified")]
#> $title
#> [1] "Permits (active GIS view)"
#> 
#> $scope_note
#> [1] "The upstream service is described as data for an internal active-permits viewer, although its public Query endpoint is accessible without a token. The date fields are LASTUPDATE and CREATEDDATE; no permit issue-date field is advertised. No explicit dataset license was found on this exact FeatureServer service or in the selected public ArcGIS organization catalog. Do not infer the license of a separate MapServer layer."
#> 
#> $verified
#> [1] "2026-09-29"
```

`source = "checked"` reads the bundled registry without HTTP. Its IDs,
such as `construction-permits` and `stpete-parks`, are stable package
names rather than ArcGIS item IDs. `dataset_info(id)` reports each
checked entry’s scope, terms, source URL, and endpoint-verification
date. The latter is not a record-freshness date. There are 20 Tampa
checked layers and three each from St. Petersburg, Clearwater,
Hillsborough County, Pinellas County, and the Tampa Bay Regional
Planning Council. All six publishers also support live discovery.

## Discover live portal layers

``` r

found <- search_datasets("housing", source = "live", portals = "city")
found[, c("id", "title", "publisher", "validation_status", "modified")]

# A one-row result carries the source needed for inspection or retrieval.
selected <- found[1, ]
selected[, c("item_id", "service_url", "layer_id", "portal")]
dataset_info(selected)
```

By default,
[`list_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_datasets.md)
and
[`search_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/search_datasets.md)
use `source = "all"` and search all six configured organizations, then
overlay the checked registry. `source = "live"` returns only layers
found through portal indexes, including checked layers when a live
endpoint matches a checked entry. If a source is not indexed or an index
lags, it may not appear in live results; a compatible public ArcGIS
layer can still be retrieved by URL with
[`get_arcgis_layer()`](https://jaclenga.github.io/tampaBayOpenData/reference/get_arcgis_layer.md).

Use `portals = "city"` for Tampa, `"tbrpc"` for the regional planning
council, or `"stpete"`, `"clearwater"`, `"hillsborough"`, or
`"pinellas"` for the other publishers. A vector selects several.
[`list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_portals.md)
shows their publisher names and source locations offline. `jurisdiction`
defaults to `"all"` for catalog functions and can be a code or a vector
of codes. A jurisdiction or publisher filter narrows the organizations
scanned. Retrieval and download functions have a different default,
`jurisdiction = "tampa"`; omitting it still resolves a uniquely named
checked ID across publishers.

`validation_status = "checked"` means maintainers validated the
configured layer. `"discovered"` means the item was found in a public
portal index, not that its contents or reuse terms were checked.
Discovery keeps checked IDs, scope, and terms when the live endpoint
matches the registry, while using current live tags, categories, and
item modification time. Newly discovered IDs have the form
`arcgis:<item-id>:<layer-id>` and can be passed to
[`get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/get_dataset.md)
in a later online session. The item or its service can still change or
disappear. Retrieval validates query responses and requires `Query` when
a layer advertises a capabilities list.

## Filter results

Both catalog functions accept these optional filters:

| Filter | Match |
|----|----|
| `jurisdiction` | One or more codes from [`list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_portals.md); default `"all"`. |
| `publisher` | Exact publisher names from [`list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_portals.md), ignoring case. |
| `validation_status` | `"checked"` or `"discovered"`. |
| `spatial` | `TRUE` for geometry layers, `FALSE` for tables; unknown geometry is excluded when filtering. |
| `topic` | Literal substring in tags and categories, ignoring case. |
| `category` | Exact category path or final category label, ignoring case. |
| `modified_after`, `modified_before` | Inclusive bounds on the catalog’s `modified` timestamp. |

Character filters accept vectors: values within one filter are
alternatives; separate filters and the search text must all match. Date
bounds accept a `Date` or strict `"YYYY-MM-DD"` string for a whole UTC
day, or a `POSIXct` value for an exact instant. Rows with unknown
modification times are excluded only when a date bound is supplied.

``` r

county_transport <- search_datasets(
  "road", source = "live", jurisdiction = "pinellas", spatial = TRUE,
  topic = "transportation", modified_after = as.Date("2025-01-01"),
  max_items = 10
)
county_transport[, c("id", "title", "publisher", "modified", "modified_source")]
```

`modified_source = "portal_item"` identifies a live ArcGIS item
timestamp; `"checked_snapshot"` identifies an upstream timestamp saved
in the checked registry. Neither establishes when every record was last
updated. The separate checked `verified` date records an endpoint check,
not feature freshness.

## Understand scan limits and failures

`max_items` caps **portal service items per organization**, not the
number of expanded layers. The default scans at most 25 items per
organization. Use `max_items = Inf` explicitly for a full live listing,
with a suitable `total_timeout`. A capped listing can miss matching
items beyond the scan limit. `jurisdiction` and `publisher` narrow
organizations before scanning; other filters apply after discovery and
the checked overlay. Consequently, an item matching `topic` or
`modified_after` may be missed by a capped scan.

``` r

results <- list_datasets(source = "live", portals = "stpete", max_items = 10)
attr(results, "discovery_complete")
attr(results, "discovery_truncated_portals")
attr(results, "discovery_scanned_items")
attr(results, "discovery_issues")
attr(results, "discovery_failed_portals")
```

Inspect `discovery_complete` before treating a result as a complete
portal catalog. Truncation and scanned-item attributes describe how far
each scan went. Skipped items and failed portals are reported in the
issue and failure attributes. If one portal fails, a combined search can
still use other publishers. If every selected live portal fails,
`source = "live"` errors; the default combined search warns and returns
checked rows. The checked catalog remains available offline with
`source = "checked"`.

Continue with [retrieval and
downloads](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.md)
or read about [coverage and source
limits](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.md).

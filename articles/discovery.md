# Discovering Tampa Bay data

`tampaBayOpenData` searches a bundled catalog of 52 checked layers or
the live ArcGIS portals of six Tampa Bay publishers. Maintainers have
validated the configured endpoints for checked layers. A `discovered`
layer comes from a portal index and has not received those checks.

Live examples below are displayed but not run while the site is built.
The checked-catalog example runs offline.

## Start offline

``` r

library(tampaBayOpenData)

tampaBayOpenData::tbod_list_portals()[, c("id", "publisher", "jurisdiction")]
#> # A tibble: 6 × 3
#>   id           publisher                           jurisdiction
#>   <chr>        <chr>                               <chr>       
#> 1 city         City of Tampa                       tampa       
#> 2 tbrpc        Tampa Bay Regional Planning Council tampa-bay   
#> 3 stpete       City of St. Petersburg              stpete      
#> 4 clearwater   City of Clearwater                  clearwater  
#> 5 hillsborough Hillsborough County                 hillsborough
#> 6 pinellas     Pinellas County                     pinellas
tampaBayOpenData::tbod_list_datasets(source = "checked")[,
  c("id", "title", "jurisdiction", "validation_status")]
#> # A tibble: 52 × 4
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
#> # ℹ 42 more rows
tampaBayOpenData::tbod_search_datasets(
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
tampaBayOpenData::tbod_dataset_info("construction-permits")[
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

`source = "checked"` reads the registry without HTTP. IDs such as
`construction-permits` and `stpete-parks` are package names, not ArcGIS
item IDs. `tbod_dataset_info(id)` gives the scope, terms, source URL,
and endpoint verification date; that date says nothing about record
freshness. The [coverage
article](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.md)
has counts by publisher, and the [selection
policy](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/checked-catalog-policy.md)
explains which layers enter the catalog.

## Discover live portal layers

``` r

found <- tbod_search_datasets("housing", source = "live", portals = "city")
found[, c("id", "title", "publisher", "validation_status", "modified")]

# A one-row result carries the source needed for inspection or retrieval.
if (nrow(found)) {
  selected <- found[1, ]
  selected[, c("item_id", "service_url", "layer_id", "portal")]
  tbod_dataset_info(selected)
}
```

By default,
[`tbod_list_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_datasets.md)
and
[`tbod_search_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_search_datasets.md)
use `source = "all"`: they search all six portals and include the
checked catalog. `source = "live"` returns only layers found through
portal indexes, including checked layers when a live endpoint matches a
checked entry. If a source is not indexed or an index lags, it may not
appear in live results; a compatible public ArcGIS layer can still be
retrieved by URL with
[`tbod_get_arcgis_layer()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_arcgis_layer.md).

Use `portals = "city"` for Tampa, `"tbrpc"` for the regional planning
council, or `"stpete"`, `"clearwater"`, `"hillsborough"`, or
`"pinellas"` for the other publishers. A vector selects several.
[`tbod_list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_portals.md)
shows their publisher names and source locations offline. `jurisdiction`
defaults to `"all"` for catalog functions and can be a code or a vector
of codes. A jurisdiction or publisher filter narrows the organizations
scanned and filters checked entries. `portals` only selects live
organizations; it does not filter checked entries when `source = "all"`.
Retrieval and download functions default to `jurisdiction = NULL`: a
checked ID resolves across the bundled catalog when it is unique. If two
jurisdictions use the same ID, supply `jurisdiction` to select one.

When a live endpoint matches a checked entry, the result keeps its
package ID, scope, and terms, combines checked and portal tags and
categories, and uses the portal item’s modification time. New IDs have
the form `arcgis:<item-id>:<layer-id>` and can be passed to
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
later. The item or service can still change or disappear. Retrieval
checks query responses and requires `Query` when the layer advertises a
capabilities list.

## Search beyond the bundled publishers

[`tbod_discover()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_discover.md)
accepts a public ArcGIS sharing REST root, FeatureServer or MapServer
service root, or a layer URL. Portal queries search public service
items; service queries filter layer names. Both return rows accepted by
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md).
Portal results have `discovered` status and stable `arcgis:` IDs;
service results have `not_checked` status and use the layer URL as their
ID. Queryable MapServer layers are supported.

``` r

# Replace this example address with your portal's public sharing REST root.
portal <- "https://example.maps.arcgis.com/sharing/rest"
other <- tbod_discover(portal, query = "parks", max_items = 10)
if (nrow(other)) {
  data <- tbod_get_dataset(other[1, ], limit = 100)
  # A stable ArcGIS ID can also be resolved later through its own portal.
  same_layer <- tbod_get_dataset(other$id[[1]], portal = portal, limit = 100)
}
```

Custom sources default to an `"unspecified"` jurisdiction. Set
`publisher` and `jurisdiction` in
[`tbod_discover()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_discover.md)
when you know them; these labels then travel with the discovery row and
its retrieval provenance. The `portal` argument on retrieval applies
only to a stable `arcgis:<item-id>:<layer-id>` ID. When retrieving a
direct layer URL,
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
does not accept a `jurisdiction` override.

## Filter results

Both catalog functions accept these optional filters:

| Filter | Match |
|----|----|
| `jurisdiction` | One or more codes from [`tbod_list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_portals.md); default `"all"`. |
| `publisher` | Exact publisher names from [`tbod_list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_portals.md), ignoring case. |
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

county_transport <- tbod_search_datasets(
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

results <- tbod_list_datasets(source = "live", portals = "stpete", max_items = 10)
attr(results, "discovery_complete")
attr(results, "discovery_truncated_portals")
attr(results, "discovery_scanned_items")
attr(results, "discovery_issues")
attr(results, "discovery_failed_portals")
```

Check `discovery_complete` before treating results as a complete portal
catalog. The other attributes show scan progress, skipped items, and
failed portals. A combined search retains rows from working publishers
or from earlier pages of a failed scan. If all selected portals fail
before returning rows, `source = "live"` errors; `source = "all"` warns
and returns checked rows.

Continue with [retrieval and
downloads](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.md)
or read about [coverage and source
limits](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.md).

# Discovering Tampa Bay data

Search the checked catalog or the live portals of six Tampa Bay
publishers. Layers marked `discovered` have not had the catalog checks.

The checked example runs offline. Live examples need internet access.

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
  c("canonical_id", "publisher", "title", "jurisdiction", "validation_status")]
#> # A tibble: 52 × 5
#>    canonical_id               publisher     title jurisdiction validation_status
#>    <chr>                      <chr>         <chr> <chr>        <chr>            
#>  1 tampa-construction-permits City of Tampa Perm… tampa        checked          
#>  2 tampa-development-cases    City of Tampa Acti… tampa        checked          
#>  3 tampa-capital-projects     City of Tampa Capi… tampa        checked          
#>  4 tampa-city-boundary        City of Tampa Tamp… tampa        checked          
#>  5 tampa-neighborhoods        City of Tampa Neig… tampa        checked          
#>  6 tampa-council-districts    City of Tampa City… tampa        checked          
#>  7 tampa-riverwalk            City of Tampa Tamp… tampa        checked          
#>  8 tampa-parks                City of Tampa Park… tampa        checked          
#>  9 tampa-fire-stations        City of Tampa City… tampa        checked          
#> 10 tampa-bike-lanes           City of Tampa Bicy… tampa        checked          
#> # ℹ 42 more rows
tampaBayOpenData::tbod_search_datasets(
  "park", source = "checked", spatial = TRUE,
  jurisdiction = c("stpete", "clearwater")
)
#> # A tibble: 2 × 25
#>   id             title description jurisdiction publisher source_url service_url
#>   <chr>          <chr> <chr>       <chr>        <chr>     <chr>      <chr>      
#> 1 clearwater-pa… Clea… City of Cl… clearwater   City of … https://g… https://gi…
#> 2 stpete-parks   St. … Public par… stpete       City of … https://c… https://se…
#> # ℹ 18 more variables: geometry_type <chr>, category <chr>, verified <date>,
#> #   terms <chr>, canonical_id <chr>, aliases <list>, layer_id <int>,
#> #   date_fields <list>, tags <list>, item_id <chr>, portal <chr>,
#> #   validation_status <chr>, modified <dttm>, modified_source <chr>,
#> #   service_type <chr>, layer_type <chr>, categories <list>,
#> #   original_metadata <list>
tampaBayOpenData::tbod_dataset_info("tampa-construction-permits")[
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

Choose a layer by title and publisher, then use its `canonical_id`. The
historical `id` remains available, and `aliases` lists accepted legacy
names.

`tbod_dataset_info(id)` gives its scope, terms, source URL, and endpoint
check date. See
[coverage](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.md)
for catalog limits.

## Search terms

Search ignores case and looks across catalog fields. All query words
must match. A limited spelling fallback applies only to checked entries;
an empty query lists datasets.

Title and ID matches rank first. Ranking helps locate sources; check
whether each source fits your question.

``` r

tbod_search_datasets("permit", source = "checked", limit = 5)[,
  c("canonical_id", "publisher", "title")]
#> # A tibble: 1 × 3
#>   canonical_id               publisher     title                    
#>   <chr>                      <chr>         <chr>                    
#> 1 tampa-construction-permits City of Tampa Permits (active GIS view)
tbod_search_datasets("permti", source = "checked", limit = 5)[,
  c("canonical_id", "publisher", "title")]
#> # A tibble: 1 × 3
#>   canonical_id               publisher     title                    
#>   <chr>                      <chr>         <chr>                    
#> 1 tampa-construction-permits City of Tampa Permits (active GIS view)
tbod_search_datasets("", source = "checked", limit = 5)[,
  c("canonical_id", "publisher", "title")]
#> # A tibble: 5 × 3
#>   canonical_id               publisher     title                                
#>   <chr>                      <chr>         <chr>                                
#> 1 tampa-construction-permits City of Tampa Permits (active GIS view)            
#> 2 tampa-development-cases    City of Tampa Active development coordination cases
#> 3 tampa-capital-projects     City of Tampa Capital improvement projects         
#> 4 tampa-city-boundary        City of Tampa Tampa boundary (shoreline representa…
#> 5 tampa-neighborhoods        City of Tampa Neighborhood association boundaries
```

Compare `permit`, the typo `permti`, and an empty query.

`limit` caps returned rows after search and filtering. `max_items` caps
service items scanned per live portal. Neither guarantees a complete
search.

## Search live portals

``` r

found <- tbod_search_datasets("housing", source = "live", portals = "city")
found[, c("canonical_id", "publisher", "title", "validation_status", "modified")]

# A one-row result carries the source needed for inspection or retrieval.
if (nrow(found)) {
  selected <- found[1, ]
  selected[, c("item_id", "service_url", "layer_id", "portal")]
  tbod_dataset_info(selected)
}
```

Each row is a layer. Inspect its metadata before retrieval.

The default `source = "all"` combines live results with the checked
catalog. Use `"live"` for portal results or `"checked"` for the offline
catalog. Matching endpoints appear once with checked status.

[`tbod_list_portals()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_portals.md)
lists publisher codes. Use `portals` to select live publishers, or
`jurisdiction` to filter both live and checked results.

New IDs use `arcgis:<item-id>:<layer-id>` and work with
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md).

## Search another ArcGIS source

[`tbod_discover()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_discover.md)
accepts a public portal, service, or layer URL and returns rows you can
pass to
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md).
Portal results are `discovered`; direct service results are
`not_checked`.

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

Set `publisher` and `jurisdiction` during discovery when known. To
resolve an `arcgis:` ID from a custom portal later, pass that portal on
retrieval.

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

Values within one filter are alternatives; separate filters must all
match. Date bounds accept `Date`, `"YYYY-MM-DD"` (UTC days), or
`POSIXct` values. Rows with unknown dates are excluded when a date
filter is used.

``` r

county_transport <- tbod_search_datasets(
  "road", source = "live", jurisdiction = "pinellas", spatial = TRUE,
  topic = "transportation", modified_after = as.Date("2025-01-01"),
  max_items = 10
)
county_transport[, c("canonical_id", "publisher", "title", "modified", "modified_source")]
```

`modified` dates a portal item or saved catalog snapshot, not every
record. `verified` dates an endpoint check.

## Check scan completeness

Live scans default to 25 service items per publisher. Set
`max_items = Inf` with a suitable `total_timeout` to scan all available
pages. A capped scan can miss matches, including matches for filters
applied after discovery.

``` r

results <- tbod_list_datasets(source = "live", portals = "stpete", max_items = 10)
attr(results, "discovery_complete")
attr(results, "discovery_truncated_portals")
attr(results, "discovery_scanned_items")
attr(results, "discovery_issues")
attr(results, "discovery_failed_portals")
```

If `discovery_complete` is `FALSE`, inspect the other diagnostics for
truncated or failed portals.

Even a complete scan covers only indexed public services. If every
portal fails without returning rows, `source = "live"` errors;
`source = "all"` warns and returns checked rows.

Next: [retrieve
records](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.md).

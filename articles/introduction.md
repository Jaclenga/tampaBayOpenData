# Get started with Tampa Bay open data

`tampaBayOpenData` retrieves public ArcGIS data from six Tampa Bay
publishers as tables or spatial objects.

Catalog examples work offline. Live searches and downloads need internet
access.

## Install

Install from CRAN:

``` r

install.packages("tampaBayOpenData")
```

## Find data

Search the offline catalog:

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
tampaBayOpenData::tbod_search_datasets("park", source = "checked")[,
  c("canonical_id", "publisher", "title", "jurisdiction", "validation_status")]
#> # A tibble: 6 × 5
#>   canonical_id             publisher        title jurisdiction validation_status
#>   <chr>                    <chr>            <chr> <chr>        <chr>            
#> 1 tampa-parks              City of Tampa    Park… tampa        checked          
#> 2 clearwater-park-buffers  City of Clearwa… Clea… clearwater   checked          
#> 3 hillsborough-parks       Hillsborough Co… Hill… hillsborough checked          
#> 4 pinellas-park-boundaries Pinellas County  Pine… pinellas     checked          
#> 5 st-pete-parks            City of St. Pet… St. … stpete       checked          
#> 6 pinellas-trail           Pinellas County  Pine… pinellas     checked
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

Choose a dataset by title and jurisdiction. Read its `scope_note`.

To search live portals:

``` r

found <- tbod_search_datasets("housing", source = "live", portals = "city")
found[, c("canonical_id", "publisher", "title", "validation_status")]
```

`portals` narrows the live search; `jurisdiction` filters both live and
checked results. Inspect discovered layers before using them. See
[discovery](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.md)
for details.

## Retrieve records

Pass a dataset ID or one-row search result to
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md).
Prefer publisher-qualified canonical IDs. Historical aliases keep their
original targets; ambiguous new subjects list the qualified
alternatives.

``` r

permits <- tbod_get_dataset(
  "tampa-construction-permits",
  where = "PROJECTSTATUS IS NOT NULL",
  fields = c("RECORD_ID", "PROJECTSTATUS", "LASTUPDATE"),
  limit = 100
)
head(permits)
sort(table(permits$PROJECTSTATUS), decreasing = TRUE)
```

`permits` contains active permit-viewer features. The table counts
returned rows by status.

Omit `limit` to retrieve all matches. You can also retrieve a discovery
row:

``` r

if (nrow(found)) {
  housing <- tbod_get_dataset(found[1, ], limit = 100)
  tbod_provenance(housing)[c("publisher", "validation_status", "complete")]
}
```

Checked layers are compared with the saved schema before retrieval.
Incompatible changes stop the request; see
[retrieval](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.md).

## Work with spatial data

Install `sf` and use `spatial = TRUE`. `out_sr = 4326` requests WGS 84
longitude and latitude; omit it to keep the source CRS.

``` r

projects <- tbod_get_dataset("tampa-development-cases", spatial = TRUE,
                        out_sr = 4326)
sf::st_crs(projects)$epsg
```

The result has a geometry column. Its CRS check should print `4326`.

See
[retrieval](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.md)
for a map example.

## Trace the source

Save the download details before changing or exporting the data:

``` r

source <- tbod_provenance(projects)
saveRDS(list(data = projects, provenance = source),
        "development-cases.rds")
```

See
[coverage](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.md)
for source limits and citation guidance.

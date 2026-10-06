# Get started with Tampa Bay open data

`tampaBayOpenData` gives R users one interface for finding and
retrieving public ArcGIS data from Tampa, St. Petersburg, Clearwater,
Hillsborough County, Pinellas County, and the Tampa Bay Regional
Planning Council. It bundles 35 maintainer-checked layers and also
discovers public layers from the six live organizations. Results are R
tibbles or optional `sf` objects with source provenance and completeness
information.

The offline catalog examples below run during the vignette build. Live
discovery and retrieval examples are displayed but not run; try them in
an internet-connected R session.

## Find data

Start with the checked catalog when you want an offline, reproducible
list of package IDs:

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
  c("id", "title", "jurisdiction", "validation_status")]
#> # A tibble: 6 × 4
#>   id                       title                  jurisdiction validation_status
#>   <chr>                    <chr>                  <chr>        <chr>            
#> 1 parks                    Park polygons          tampa        checked          
#> 2 stpete-parks             St. Petersburg parks   stpete       checked          
#> 3 clearwater-park-buffers  Clearwater park buffe… clearwater   checked          
#> 4 hillsborough-parks       Hillsborough County p… hillsborough checked          
#> 5 pinellas-park-boundaries Pinellas County park … pinellas     checked          
#> 6 pinellas-trail           Pinellas Trail segmen… pinellas     checked
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

`source = "checked"` uses a bundled registry without making a network
request. Checked IDs, including `stpete-parks` and
`construction-permits`, remain stable package names.
[`tbod_dataset_info()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_dataset_info.md)
reports the source, terms, and scope of a checked entry. For more
choices, search live portal indexes:

``` r

found <- tbod_search_datasets("housing", source = "live", portals = "city")
found[, c("id", "title", "publisher", "validation_status")]
```

Catalog searches scan all six publishers by default. Set `portals` or
`jurisdiction` to narrow them. `checked` means the package maintainers
validated the configured layer; `discovered` means it appeared in a live
portal index but has not received the same validation. Inspect a
discovered source and its reuse terms before analysis. See [discovering
Tampa Bay
data](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.md)
for all filters, live scan limits, discovery status, and the
[`tbod_discover()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_discover.md)
path for ArcGIS sources outside the bundled region.

## Retrieve records

Pass a checked ID, a discovered stable ID, or a one-row search result to
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md).
This example requests a small subset of a checked Tampa layer as a
tibble. A checked ID that appears in multiple jurisdictions also needs a
`jurisdiction` argument:

``` r

permits <- tbod_get_dataset(
  "construction-permits",
  where = "PROJECTSTATUS IS NOT NULL",
  fields = c("RECORD_ID", "PROJECTSTATUS", "LASTUPDATE"),
  limit = 100
)
head(permits)
sort(table(permits$PROJECTSTATUS), decreasing = TRUE)
```

The counts describe the retrieved subset, not all matching permits. Omit
`limit` to retrieve all matching rows. A discovered result can travel to
retrieval with its source information:

``` r

housing <- tbod_get_dataset(found[1, ], limit = 100)
tbod_provenance(housing)[c("publisher", "validation_status", "complete")]
```

Checked retrieval compares current ArcGIS metadata with the bundled
schema snapshot before querying records. Use `tbod_schema(id)` to see
the saved schema and `tbod_check_schema(id)` to inspect drift.
Compatible changes warn; incompatible changes stop retrieval. The
[retrieval
article](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.md)
lists drift categories and shows how to check an external URL against a
saved schema.

## Work with spatial data

Install the optional `sf` package and request `spatial = TRUE` for an
`sf` result. `out_sr = 4326` asks the service for WGS 84 coordinates;
without `out_sr`, the client keeps the native CRS.

``` r

projects <- tbod_get_dataset("development-cases", spatial = TRUE,
                        out_sr = 4326)
sf::st_crs(projects)$epsg
```

The [retrieval
article](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.md)
shows a map with this layer and the Tampa boundary. It also explains
ArcGIS filters, pagination, integrity checks, time budgets, data types,
direct layer URLs, and resumable downloads.

## Trace the source

Provenance records where the result came from, the query, retrieval
time, row counts, validation status, integrity method, and whether the
result is complete. Save it separately before transforming the data,
because some R operations may discard attached attributes.

``` r

source <- tbod_provenance(projects)
saveRDS(list(data = projects, provenance = source),
        "development-cases.rds")
```

Read [coverage, provenance, and source
limits](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.md)
before treating a layer as a complete historical record or interpreting
a map as a legal boundary. That article also explains source
attribution, citation, government data reuse terms, and monitoring
evidence. The package is independent of the data publishers and
rOpenSci.

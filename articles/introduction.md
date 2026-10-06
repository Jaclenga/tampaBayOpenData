# Get started with Tampa Bay open data

`tampaBayOpenData` retrieves public ArcGIS data from six Tampa Bay
publishers. It includes 52 checked layers in an offline catalog and can
search the publishers’ live portals. Retrieval returns a tibble or, with
`sf` installed, a spatial object.

The offline catalog examples below run during the vignette build. Live
discovery and retrieval examples are displayed but not run; try them in
an internet-connected R session.

## Find data

The checked catalog has stable package IDs and works offline:

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

[`tbod_dataset_info()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_dataset_info.md)
reports a checked entry’s source, terms, and scope. To look beyond the
catalog, search the live portals:

``` r

found <- tbod_search_datasets("housing", source = "live", portals = "city")
found[, c("id", "title", "publisher", "validation_status")]
```

The default catalog search scans all six live publishers and includes
checked entries. Set `portals` to narrow the live scan; matching checked
entries still appear. Set `jurisdiction` to filter both live and checked
results. A `discovered` result has not received the catalog’s source
checks; inspect its metadata and reuse terms before analysis. The
[discovery
article](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.md)
covers filters, scan limits, and ArcGIS sources outside the bundled
region.

## Retrieve records

Pass a checked ID, a discovered ID, or a one-row search result to
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md).
If a checked ID is shared by multiple jurisdictions, supply
`jurisdiction` as well.

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

The counts describe the retrieved subset. Omit `limit` to retrieve all
matching rows. Passing a discovery row keeps its source information:

``` r

if (nrow(found)) {
  housing <- tbod_get_dataset(found[1, ], limit = 100)
  tbod_provenance(housing)[c("publisher", "validation_status", "complete")]
}
```

Before retrieving a checked layer, the package compares its current
fields, geometry, and CRS with the bundled schema. Added fields warn;
incompatible changes stop retrieval. See
[`tbod_check_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_check_schema.md)
and the [retrieval
article](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.md)
for the full drift report.

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
maps this layer and describes filters, integrity checks, data types, and
downloads.

## Trace the source

[`tbod_provenance()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_provenance.md)
records the source, query, retrieval time, row counts, and completeness.
Save it separately before transformations that may discard attributes.

``` r

source <- tbod_provenance(projects)
saveRDS(list(data = projects, provenance = source),
        "development-cases.rds")
```

The [coverage
article](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.md)
covers source limits, attribution, and citation. A retrieved layer is
not necessarily a complete historical record or a legal boundary.

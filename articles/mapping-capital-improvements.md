# Where Are Tampa's Public Infrastructure Projects?

## 1. Set up

Map Tampa’s public capital-project locations by type and count their
neighborhood labels.

Install the packages once, then load them in each R session. The map
uses `sf` and base R.

``` r

install.packages(c("tampaBayOpenData", "sf"))
```

``` r

library(tampaBayOpenData)
```

This page uses a snapshot saved October 24, 2026. Run the retrieval code
with internet access for current data; see the live-render command
below.

## 2. Find data

Search the offline catalog:

``` r

project_matches <- tbod_search_datasets(
  "capital", jurisdiction = "tampa", source = "checked"
)
project_matches[, c("canonical_id", "publisher", "title", "geometry_type")]
#> # A tibble: 1 × 4
#>   canonical_id           publisher     title                       geometry_type
#>   <chr>                  <chr>         <chr>                       <chr>        
#> 1 tampa-capital-projects City of Tampa Capital improvement projec… esriGeometry…
```

Use `tampa-capital-projects` for locations and `tampa-city-boundary` for
the backdrop.

Check the source and field names:

``` r

project_info <- tbod_dataset_info("tampa-capital-projects")
project_info[c("publisher", "source_url", "scope_note")]
#> $publisher
#> [1] "City of Tampa"
#> 
#> $source_url
#> [1] "https://tampa.maps.arcgis.com/home/item.html?id=2226a20de08641e38cedd1c2d7cac69e"
#> 
#> $scope_note
#> [1] "The service description says its definition query selects Show to Public = Yes, while the layer metadata does not expose that definition expression. Coordinates use ArcGIS WKID 103023 / latestWKID 6443, in feet, rather than the Web Mercator CRS used by the other selected layers."

tbod_dataset_info("tampa-city-boundary")[c("title", "geometry_type")]
#> $title
#> [1] "Tampa boundary (shoreline representation)"
#> 
#> $geometry_type
#> [1] "esriGeometryPolygon"
project_fields <- c("OBJECTID", "projid", "projname", "projtype", "Neighborhood")
project_schema <- tbod_schema("tampa-capital-projects")
project_schema$fields[
  match(project_fields, project_schema$fields$name),
  c("name", "alias", "type")
]
#> # A tibble: 5 × 3
#>   name         alias              type               
#>   <chr>        <chr>              <chr>              
#> 1 OBJECTID     OBJECTID           esriFieldTypeOID   
#> 2 projid       Project Identifier esriFieldTypeString
#> 3 projname     Project Name       esriFieldTypeString
#> 4 projtype     Project Type       esriFieldTypeString
#> 5 Neighborhood Neighborhood       esriFieldTypeString
```

`OBJECTID` identifies a feature. `projid` identifies a project and may
repeat across locations.

## 3. Retrieve data

Use `spatial = TRUE` for geometry and `out_sr = 4326` for both layers to
share WGS 84 longitude and latitude.

``` r

capital_projects <- tbod_get_dataset(
  "tampa-capital-projects", fields = project_fields,
  spatial = TRUE, out_sr = 4326, limit = 1000
)
tampa_boundary <- tbod_get_dataset(
  "tampa-city-boundary", fields = "OBJECTID",
  spatial = TRUE, out_sr = 4326, limit = 100
)
```

The snapshot has 201 project features and one boundary. Check
completeness in case current records exceed the requested limits.

``` r

project_source <- tbod_provenance(capital_projects)
boundary_source <- tbod_provenance(tampa_boundary)
if (!isTRUE(project_source$complete) || !isTRUE(boundary_source$complete)) {
  stop("Incomplete download: review the limits before mapping.")
}
if (nrow(capital_projects) == 0 || nrow(tampa_boundary) == 0) {
  stop("A source returned no features.")
}
stopifnot(isTRUE(sf::st_crs(capital_projects)$epsg == 4326),
          isTRUE(sf::st_crs(tampa_boundary)$epsg == 4326))
project_source[c("retrieved_at", "returned_rows", "complete")]
#> $retrieved_at
#> [1] "2026-10-25 02:35:57 UTC"
#> 
#> $returned_rows
#> [1] 201
#> 
#> $complete
#> [1] TRUE
```

`retrieved_at` dates the download; `complete` confirms all matches were
returned.

Save the data and provenance:

``` r

saveRDS(list(capital_projects = capital_projects, tampa_boundary = tampa_boundary),
        "tampa-infrastructure.rds")
```

## 4. Create the map

Exclude empty geometries from the map, keeping them in the original
table:

``` r

missing_geometry <- sf::st_is_empty(capital_projects)
sum(missing_geometry)
#> [1] 0
mapped_projects <- capital_projects[!missing_geometry, ]
tampa_boundary <- tampa_boundary[!sf::st_is_empty(tampa_boundary), ]
if (nrow(mapped_projects) == 0 || nrow(tampa_boundary) == 0) {
  stop("No usable geometry for the map.")
}
stopifnot(all(sf::st_geometry_type(mapped_projects) == "POINT"))
```

Assign colors by type. Keep blank types as “Not reported”.

``` r

project_types <- trimws(mapped_projects$projtype)
project_types[is.na(project_types) | project_types == ""] <- "Not reported"
type_labels <- sort(unique(project_types))
type_colors <- setNames(hcl.colors(length(type_labels), "Dark 3"), type_labels)
sort(table(project_types), decreasing = TRUE)
#> project_types
#>          Transportation              Wastewater                   Water 
#>                      63                      48                      46 
#>  Stormwater Engineering      Parks & Recreation Contract Administration 
#>                      19                      17                       4 
#>     Facility Management 
#>                       4
```

These counts include only records with coordinates.

Draw the boundary, then add the points:

``` r

map_extent <- sf::st_bbox(c(sf::st_geometry(tampa_boundary),
                           sf::st_geometry(mapped_projects)))
layout(matrix(c(1, 2), nrow = 1), widths = c(3, 1.4))
par(mar = c(4, 4, 3, 1))
plot(sf::st_geometry(tampa_boundary), col = "grey95", border = "grey60",
     xlim = map_extent[c("xmin", "xmax")],
     ylim = map_extent[c("ymin", "ymax")], axes = TRUE,
     xlab = "Longitude", ylab = "Latitude",
     main = "Tampa's public infrastructure project locations", cex.main = 0.9)
plot(sf::st_geometry(mapped_projects), add = TRUE, pch = 16, cex = 0.8,
     col = type_colors[project_types])
par(mar = c(1, 0, 3, 0))
plot.new()
legend("center", legend = c(type_labels, "City outline"),
       col = c(type_colors, "grey60"),
       pch = c(rep(16, length(type_labels)), NA),
       lty = c(rep(NA, length(type_labels)), 1),
       title = "Source project type", bty = "n", cex = 0.85)
```

![Tampa capital-project point locations colored by City project-type
labels, over a shoreline-adjusted city boundary, with a separate
legend.](mapping-capital-improvements_files/figure-html/capital-project-map-1.png)

``` r

layout(1)
```

Dots mark feature locations and may overlap. They do not show
construction footprints. The shoreline-adjusted boundary is map context,
not a legal survey.

## 5. Count neighborhoods

Count the source’s neighborhood labels across all rows, including those
without geometry:

``` r

neighborhood_labels <- trimws(capital_projects$Neighborhood)
neighborhood_labels[is.na(neighborhood_labels) | neighborhood_labels == ""] <-
  "Not reported"
neighborhood_counts <- sort(table(neighborhood_labels), decreasing = TRUE)
head(neighborhood_counts, 10)
#> neighborhood_labels
#>               Not reported       Old Seminole Heights 
#>                         14                         12 
#>              Tampa Heights        Downtown River Arts 
#>                         11                          9 
#> Tampa Downtown Partnership  Interbay - South of Gandy 
#>                          8                          6 
#>         Bayshore Beautiful                  Drew Park 
#>                          5                          5 
#>      Gandy / Sun Bay South Southeast Seminole Heights 
#>                          5                          5
```

In the snapshot, Old Seminole Heights has 12 rows and Tampa Heights has
11. Missing labels stay in their own group.

## Limits

The layer covers a public-facing selection. Several points may belong to
one project, and blank areas do not prove no work exists. These
locations alone cannot measure spending, construction status, or
investment equity.

Data: City of Tampa [capital-project
layer](https://tampa.maps.arcgis.com/home/item.html?id=2226a20de08641e38cedd1c2d7cac69e)
and [shoreline-adjusted
boundary](https://tampa.maps.arcgis.com/home/item.html?id=ed03de89b95340359431d13bd2bc38f2),
both recorded as CC0 in the checked catalog. Source details and
retrieval times are retained in `tbod_provenance(capital_projects)` and
`tbod_provenance(tampa_boundary)`.

### Render with current data

With the packages and Pandoc installed, run from the repository root
with internet access:

``` r

Sys.setenv(TAMPA_OPEN_DATA_LIVE = "true")
rmarkdown::render("vignettes/mapping-capital-improvements.Rmd")
Sys.unsetenv("TAMPA_OPEN_DATA_LIVE")
```

Ordinary builds use the saved snapshot. Without `sf`, the page shows its
saved map and skips spatial code. See
[infrastructure](https://jaclenga.github.io/tampaBayOpenData/articles/infrastructure-projects.md)
for project IDs, status, and costs.

# Your First Five Minutes with tampaBayOpenData

Find parks data and make a bar chart in base R.

Use 100 Hillsborough County property records saved on October 24, 2026,
or fetch current records in step 3. The saved example works offline
after installation.

## 1. Install and load

Install once:

``` r

install.packages("tampaBayOpenData")
```

Load in each R session:

``` r

library(tampaBayOpenData)
```

## 2. Find a dataset

Search the offline catalog:

``` r

matches <- tbod_search_datasets("parks", source = "checked")
matches[, c("id", "title")]
#> # A tibble: 6 × 2
#>   id                       title                                              
#>   <chr>                    <chr>                                              
#> 1 parks                    Park polygons                                      
#> 2 hillsborough-parks       Hillsborough County parks and recreation properties
#> 3 stpete-parks             St. Petersburg parks                               
#> 4 clearwater-park-buffers  Clearwater park buffers                            
#> 5 pinellas-park-boundaries Pinellas County park boundaries                    
#> 6 pinellas-trail           Pinellas Trail segments
```

Use the `hillsborough-parks` ID below.

## 3. Load data

Choose one option.

### Saved preview

Load the bundled data offline:

``` r

parks_file <- system.file("extdata", "parks-preview.rds",
                          package = "tampaBayOpenData", mustWork = TRUE)
parks <- readRDS(parks_file)
```

### Current records

With internet access, request up to 100 records:

``` r

parks <- tbod_get_dataset("hillsborough-parks", limit = 100)
```

These are the first records returned, not a random sample. One park may
have several property records.

Knitting this file uses the saved preview. Run the live request yourself
to use current data.

## 4. Summarize

Check the first rows, row count, and column names:

``` r

head(parks[, c("NAME", "TYPE", "USES")])
#> # A tibble: 6 × 3
#>   NAME                        TYPE  USES           
#>   <chr>                       <chr> <chr>          
#> 1 Alafia River Boat Ramp      L     Boat Ramp      
#> 2 Alexander                   L     Programmed     
#> 3 All People's Life Center    L     Community      
#> 4 Clayton                     L     Sports         
#> 5 Antioch                     L     Sports         
#> 6 Apollo Beach and Skate Park L     SportsRec_Skate
nrow(parks)
#> [1] 100
names(parks)
#>  [1] "OBJECTID_1"       "FOLIONUMB"        "NAME"             "ADDR"            
#>  [5] "TYPE"             "USES"             "PROPOWNER"        "PROPMNG"         
#>  [9] "GlobalID"         "created_user"     "created_date"     "last_edited_user"
#> [13] "last_edited_date" "Shape__Area"      "Shape__Length"
```

Count the `USES` labels:

``` r

uses <- trimws(parks$USES)
uses[is.na(uses) | uses == ""] <- "Not reported"
park_uses <- table(uses)
park_uses <- sort(park_uses, decreasing = TRUE)
park_uses
#> uses
#>            Sports            Nature        Playground        Recreation 
#>                24                16                14                14 
#>            Office   SportsRec_Skate         Boat Ramp         Community 
#>                 8                 7                 3                 3 
#>        Programmed               Dog Sports_Recreation            Trails 
#>                 3                 2                 2                 2 
#>        Equestrian       Maintenance 
#>                 1                 1
```

Blank or missing labels are grouped as “Not reported”.

## 5. Make a chart

Plot the five most common labels:

``` r

top_uses <- head(park_uses, 5)
par(mar = c(4, 10, 3, 1))
if (length(top_uses) > 0) {
  barplot(rev(top_uses), horiz = TRUE, las = 1, cex.names = 0.8,
        col = "steelblue", xlab = "Property records",
        main = "Most common uses in this preview")
} else {
  plot.new()
  text(0.5, 0.5, "No property records returned")
}
```

![Horizontal bars counting property records for up to five most common
use labels in the parks
preview.](first-five-minutes_files/figure-html/chart-uses-1.png)

Sports leads the saved preview, followed by Nature. Current results may
differ.

The bars count property records in this preview, not unique parks across
the county. Map outlines do not confirm boundaries, access, or opening
hours.

If a live request fails or reports changed column names, see the
[retrieval troubleshooting
guide](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.html#troubleshooting-common-errors).

Data: [Hillsborough County Parks and Recreation
properties](https://hillsborough.maps.arcgis.com/home/item.html?id=96d17f4369f14bc5b283d8863b016373),
used under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

## Next

Try another search term and inspect its columns with
[`names()`](https://rdrr.io/r/base/names.html). See
[discovery](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.md)
for searches or
[retrieval](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.md)
for filters.

For a map, try [capital
improvements](https://jaclenga.github.io/tampaBayOpenData/articles/mapping-capital-improvements.md).

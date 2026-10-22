# Your First Five Minutes with tampaBayOpenData

This tutorial searches for a public parks dataset, retrieves a small
preview, and charts one of its fields in base R. It assumes basic R
skills; no mapping software or knowledge of the publisher’s data service
is required. Run the commands in order. Searching the package’s catalog
works offline; retrieving records needs an internet connection. The
publisher can change its data, so your results may differ from another
person’s or from a later run.

## 1. Install the package

Install the package from CRAN once:

``` r

install.packages("tampaBayOpenData")
```

Load it each time you start a new R session:

``` r

library(tampaBayOpenData)
```

## 2. Find a dataset

Search for parks in the package’s checked catalog:

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

A **dataset** is a collection of related records published by an
organization. Each row in these search results points to one dataset,
with a title and an `id` that you can use to retrieve it.
`source = "checked"` searches the package’s built-in list of datasets
whose structures have been inspected. This search does not download park
records. Find the `hillsborough-parks` row; that is the ID we will use
for the rest of this tutorial. The list can grow when the package is
updated.

## 3. Download some records

Ask Hillsborough County’s public service for a small preview:

``` r

parks <- tbod_get_dataset("hillsborough-parks", limit = 100)
```

[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
retrieves public records and puts them in `parks`, a table you can
explore in R. No account or password is needed. `limit = 100` requests
up to 100 records; if more match, these are only some of them. They are
the first records returned by the service, not a random sample. In this
source, each row describes a mapped property area managed by the county;
several rows can describe the same park. Run this line in your R session
to see the publisher’s current records.

## 4. Explore what you found

Start with three familiar ways to inspect a table:

``` r

head(parks)
nrow(parks)
names(parks)
```

[`head()`](https://rdrr.io/r/utils/head.html) shows the first few rows,
[`nrow()`](https://rdrr.io/r/base/nrow.html) tells you how many rows
arrived, and [`names()`](https://rdrr.io/r/base/names.html) lists the
columns. The publisher supplies these columns. One of them, `USES`,
labels how each property is used. Which labels appear most often in the
records you received?

``` r

park_uses <- table(parks$USES, useNA = "ifany")
park_uses <- sort(park_uses, decreasing = TRUE)
park_uses
```

[`table()`](https://rdrr.io/r/base/table.html) counts records for each
use label, including a missing-value group if one appears.
[`sort()`](https://rdrr.io/r/base/sort.html) puts the largest counts
first. These counts describe only the returned preview; they do not tell
you how many parks of each type exist across the county.

## 5. Make your first chart

Show the five most common use labels in that same preview:

``` r

top_uses <- head(park_uses, 5)
barplot(top_uses, horiz = TRUE, las = 1, cex.names = 0.7,
        col = "steelblue", xlab = "Property records",
        main = "Most common uses in this preview")
```

Each bar counts property records with one of the publisher’s use labels.
The chart is a quick look at the rows you loaded, not an estimate for
all county parks. The first 100 records may change, and mapped property
outlines do not establish legal boundaries, public access, or opening
hours. If the service is temporarily unavailable, try the retrieval
again later; the [retrieval guide’s troubleshooting
section](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.html#troubleshooting-common-errors)
has more help.

## What to try next

To work with another dataset, change the search word, choose an `id`
from the results, and inspect
[`names()`](https://rdrr.io/r/base/names.html) before counting a column.
The [discovery
guide](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.md)
helps you find more datasets; the [retrieval
guide](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.md)
covers filters and larger downloads. When you are ready for maps, try
the [spatial
example](https://jaclenga.github.io/tampaBayOpenData/articles/mapping-capital-improvements.md).
For longer real-world walkthroughs, see
[housing](https://jaclenga.github.io/tampaBayOpenData/articles/housing-development.md),
[water
quality](https://jaclenga.github.io/tampaBayOpenData/articles/water-quality.md),
and
[infrastructure](https://jaclenga.github.io/tampaBayOpenData/articles/infrastructure-projects.md).

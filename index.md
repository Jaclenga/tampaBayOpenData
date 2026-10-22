# tampaBayOpenData

`tampaBayOpenData` provides R functions for searching public datasets
from six Tampa Bay publishers and retrieving their records. It includes
a selected list of datasets whose structure has been checked and can
also search publisher catalogs online. Results are returned as tables
or, with the optional `sf` package, spatial objects.

[Five-minute beginner
tutorial](https://jaclenga.github.io/tampaBayOpenData/articles/first-five-minutes.html)

## Install

Install the released package from CRAN:

``` r

install.packages("tampaBayOpenData")
```

For the development version, install `pak` with
`install.packages("pak")` if needed, then run
`pak::pak("Jaclenga/tampaBayOpenData")`.

## Quick start

Search the built-in catalog, retrieve a small preview of St. Petersburg
parks, and inspect the resulting table:

``` r

library(tampaBayOpenData)

matches <- tbod_search_datasets("parks", source = "checked")
matches[, c("id", "title")]

parks <- tbod_get_dataset("stpete-parks", limit = 100)
head(parks)
nrow(parks)
names(parks)
```

The search results include dataset IDs you can use to retrieve records.
[`head()`](https://rdrr.io/r/utils/head.html) shows the first few rows,
[`nrow()`](https://rdrr.io/r/base/nrow.html) counts the rows you
received, and [`names()`](https://rdrr.io/r/base/names.html) lists their
columns. Catalog search works offline; retrieval contacts the publisher.
`limit = 100` returns at most 100 records, so this preview may not
contain the whole dataset.

## What data can I find?

The package covers selected public data from the cities of Tampa,
St. Petersburg, and Clearwater; Hillsborough and Pinellas counties; and
the Tampa Bay Regional Planning Council.

A **checked** dataset has had its structure inspected by the package
maintainers. The checked catalog is a selection, not a complete
inventory of any publisher. Structure checks help detect changes, but do
not guarantee that a service is available or that its records are
accurate. See the [coverage
guide](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.html)
and [schema
checks](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.html#check-the-live-schema).

You can also search a publisher’s current online catalog. For example,
search the City of Tampa for housing data:

``` r

tbod_search_datasets("housing", source = "live", portals = "city")
```

Live results depend on publisher availability and search limits, so they
may miss datasets. The [discovery
guide](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.html)
explains more ways to search.

## Example map

With the optional `sf` package installed, you can retrieve spatial data
to make maps. This map combines checked City of Tampa capital-project
locations with a city boundary:

![Map of 394 City of Tampa capital project locations and the
shoreline-adjusted Tampa
boundary](reference/figures/tampa-capital-projects-map.png)

Map of 394 City of Tampa capital project locations and the
shoreline-adjusted Tampa boundary

*City of Tampa data retrieved October 3, 2026 (both source items marked
CC0). The shoreline-adjusted boundary is not a legal survey; the points
do not establish current project status or complete coverage. [Reproduce
the
map](https://github.com/Jaclenga/tampaBayOpenData/blob/main/tools/render-home-map.R)
or follow the [spatial
walkthrough](https://jaclenga.github.io/tampaBayOpenData/articles/introduction.html#work-with-spatial-data).*

## Learn more

- [Retrieval and
  downloads](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.html)
  explains filters, larger downloads, and common errors.
- [Function
  reference](https://jaclenga.github.io/tampaBayOpenData/reference/index.html)
  lists package functions.
- Practical tutorials: [housing and
  development](https://jaclenga.github.io/tampaBayOpenData/articles/housing-development.html),
  [water
  quality](https://jaclenga.github.io/tampaBayOpenData/articles/water-quality.html),
  and [infrastructure
  projects](https://jaclenga.github.io/tampaBayOpenData/articles/infrastructure-projects.html).

## Data sources and limitations

The publishers maintain the underlying datasets; the package does not
control their availability, completeness, or accuracy.
`tbod_dataset_info("stpete-parks")` shows catalog source details, and
`tbod_provenance(parks)` records where and when a result was retrieved.
These details help trace a result, but do not verify individual records.

The package’s MIT license covers its code; source data may have
different reuse terms. Check the [coverage and source
notes](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.html)
before using a dataset.

## Citation and contributing

Cite both the package and the original data publisher and dataset. Run
`citation("tampaBayOpenData")` for the package citation. See the
[contributing
guide](https://github.com/Jaclenga/tampaBayOpenData/blob/main/CONTRIBUTING.md)
for contribution instructions.

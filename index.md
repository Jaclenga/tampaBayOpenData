# tampaBayOpenData

Public ArcGIS data around Tampa Bay, from R.

52 checked layers across six publishers · live portal discovery

`tampaBayOpenData` searches public ArcGIS data from Tampa,
St. Petersburg, Clearwater, Hillsborough County, Pinellas County, and
the Tampa Bay Regional Planning Council. Its bundled catalog has checked
dataset IDs you can search offline. Live discovery searches publisher
portals, and retrieval reads their current services. You can also supply
another public ArcGIS portal or layer URL.

## Install

Install from GitHub:

``` r

install.packages("pak") # if needed
pak::pak("Jaclenga/tampaBayOpenData")
```

Install `sf` as well if you need spatial results.

## Find and retrieve a checked layer

``` r

library(tampaBayOpenData)

parks <- tbod_search_datasets("parks", source = "checked")
parks[, c("id", "title", "publisher")]

data <- tbod_get_dataset("stpete-parks", limit = 100)
tbod_provenance(data)[c("publisher", "source_url", "retrieved_at", "complete")]
```

The search reads the bundled catalog; retrieval contacts the publisher.
`limit = 100` returns a subset, recorded as incomplete in its provenance
when more records match. Omit `limit` to request all matching records,
subject to the service and package limits described in the retrieval
guide.

A **checked** layer has a catalog entry and a saved field, geometry, and
CRS snapshot. Before retrieval, its live metadata is compared with that
snapshot: compatible changes warn; incompatible changes stop the
request. Checked status does not verify individual records or guarantee
the service will remain available. See [schema checks and
retrieval](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.html#check-the-live-schema).

## Search beyond the catalog

Live discovery searches the six configured ArcGIS publishers. For
example,
`tbod_search_datasets("housing", source = "live", portals = "city")`
searches Tampa’s portal. To search another public ArcGIS portal, supply
its sharing REST root:

``` r

# Replace this address with the public sharing REST root of your portal.
other <- tbod_discover("https://example.maps.arcgis.com/sharing/rest",
                       query = "parks")
if (nrow(other)) tbod_get_dataset(other[1, ], limit = 100)
```

Portal results have `discovered` status; rows from a service or layer
URL have `not_checked` status. Both work with
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
and have no saved checked schema. Live searches can miss items when the
scan is bounded or a publisher service fails; inspect
`attr(other, "discovery_complete")` before treating a result as a
complete listing. A direct public `FeatureServer/<id>` or
`MapServer/<id>` URL also works with
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md).
The
[discovery](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.html)
and
[retrieval](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.html)
articles cover filters, scan limits, direct URLs, and downloads.

## See spatial data

The checked City of Tampa `city-boundary` and `capital-projects` layers
can be retrieved as `sf` objects with `spatial = TRUE`.

![Map of 394 City of Tampa capital project locations and the
shoreline-adjusted Tampa
boundary](reference/figures/tampa-capital-projects-map.png)

Map of 394 City of Tampa capital project locations and the
shoreline-adjusted Tampa boundary

*City of Tampa data retrieved October 3, 2026 (both ArcGIS items marked
CC0). The shoreline-adjusted boundary is not a legal survey; the points
do not establish current project status or complete coverage. [Reproduce
the
map](https://github.com/Jaclenga/tampaBayOpenData/blob/main/tools/render-home-map.R)
or follow the [spatial
walkthrough](https://jaclenga.github.io/tampaBayOpenData/articles/introduction.html#work-with-spatial-data).*

## Coverage and source limits

The 52 checked layers are selected references, not a complete inventory
or uniform coverage of each topic. Publisher services can change, and
some layers are active views or approximate boundaries. The TBRPC storm
surge layer is a historical planning model, not current emergency
guidance. See the [coverage
guide](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.html)
for publisher counts, layer caveats, and reuse terms, and the [catalog
policy](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/checked-catalog-policy.md)
for selection and maintenance decisions. The package’s MIT license
covers its code, not the source data. The package is independent of the
publishers and rOpenSci.

## Citation

Cite the package and the original data publisher and dataset. For the
package citation, run:

``` r

citation("tampaBayOpenData")
toBibtex(citation("tampaBayOpenData"))
```

`tbod_dataset_info(id)` gives catalog source details;
`tbod_provenance(result)` records the retrieval source and time.

## Learn more

- [Get
  started](https://jaclenga.github.io/tampaBayOpenData/articles/introduction.html)
  and [function
  reference](https://jaclenga.github.io/tampaBayOpenData/reference/index.html)
- [Discovery](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.html),
  [retrieval and
  downloads](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.html),
  and [coverage and
  provenance](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.html)
- [Architecture](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/architecture.md),
  [API
  migration](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/api-migration.md),
  [validation](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/validation.md),
  and
  [contributing](https://github.com/Jaclenga/tampaBayOpenData/blob/main/CONTRIBUTING.md)
- [Full-data bicycle network exploration (R
  Markdown)](https://github.com/Jaclenga/tampaBayOpenData/blob/main/explorations/tampa-bicycle-network-eda.Rmd)
- [Short R data exploration stories across six
  publishers](https://github.com/Jaclenga/tampaBayOpenData/tree/main/explorations/stories)

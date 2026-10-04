# Coverage, provenance, and source limits

The package provides access to public ArcGIS services; it does not
publish or archive the government data. Its geographic reach, the number
of checked layers, and the completeness of a government dataset are
three different things. This article concerns **data coverage**. The
project’s [test coverage
workflow](https://github.com/Jaclenga/tampaBayOpenData/actions/workflows/test-coverage.yaml)
measures a separate property of the package code.

## Which publishers are configured?

The registry contains six publishers or jurisdictions. The checked
column counts configured layers that package maintainers validated; live
discovery searches each listed publisher’s public ArcGIS organization.
These counts come from the bundled `inst/extdata/datasets.json` and
`portals.json` registries.

| Publisher or jurisdiction           | Checked layers | Live discovery |
|-------------------------------------|---------------:|:--------------:|
| Tampa                               |             20 |      Yes       |
| St. Petersburg                      |              3 |      Yes       |
| Clearwater                          |              3 |      Yes       |
| Hillsborough County                 |              3 |      Yes       |
| Pinellas County                     |              3 |      Yes       |
| Tampa Bay Regional Planning Council |              3 |      Yes       |

The checked catalog is a selected set of **35 layers**, not a complete
inventory of each publisher’s holdings. Live discovery may find other
layers, but it is subject to portal indexing, service availability, scan
limits, and the publishers’ metadata. Neither path establishes
comprehensive historical coverage of Tampa Bay. See [discovering
data](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.md)
for the meaning of `max_items`, scan completeness, and checked versus
discovered status.

## Interpret source scope before analysis

The Tampa checked layers include active permit and development-case
views, not complete historical ledgers. The `city-boundary` layer
follows a shoreline representation and is not a legal survey. The
catalog also includes parks, historic sites, police districts,
transportation, zoning, and utility service areas. St. Petersburg
checked layers cover parks, city boundaries, and streets; Clearwater
layers cover park buffers, zoning, and libraries. Hillsborough County
adds cooperative libraries, sidewalks, and parks. Pinellas County adds
fire stations, park boundaries, and a trail. The Tampa Bay Regional
Planning Council adds developments of regional impact, storm surge, and
data centers. Its storm surge layer is a historical planning model, not
current emergency guidance.

Park buffers are areas around parks, rather than exact park footprints.
These maps do not by themselves establish legal boundaries, current road
restrictions, service eligibility, or operating status. The
`water-service-area` extends beyond city limits. The current
`fire-stations` source uses unqualified field names such as `NAME` and
supports `order_by`; joined service-information fields from an older
source are unavailable.

``` r

library(tampaBayOpenData)

info <- dataset_info("construction-permits")
info[c("title", "source_url", "scope_note", "terms", "verified")]
```

Read `scope_note` and `terms` for a checked entry before analysis. The
`verified` date records a maintainer endpoint check, not the freshness
of every feature. A portal item’s `modified` date describes its item,
not necessarily the age of its records. `modified_source` distinguishes
a live portal-item timestamp from a saved checked snapshot; neither
substitutes for a feature update date.

Discovered items may change, become unavailable, or lack clear reuse
terms. The package does not validate their contents or verify their
reuse terms. Inspect their source metadata and publisher terms before
use. A live portal failure does not prevent offline browsing of the
checked catalog with `source = "checked"`.

## Keep provenance with results

[`dataset_provenance()`](https://jaclenga.github.io/tampaBayOpenData/reference/dataset_provenance.md)
returns a record attached to a retrieved tibble or `sf` object. It
includes the publisher, source layer or item URL, portal and item ID
when known, validation status, query endpoint and options, retrieval
time, row counts, integrity method, and completeness. Status is
`checked` for a bundled validated layer, `discovered` for an unvalidated
live result, or `not_checked` for direct URL retrieval.

``` r

projects <- get_dataset("development-cases", spatial = TRUE, out_sr = 4326)
source <- dataset_provenance(projects)
saveRDS(list(data = projects, provenance = source), "development-cases.rds")
```

Save provenance separately before transformations or exports that may
discard R attributes. A finite subset remains marked incomplete when
more matching rows exist. Full and subset object-ID checks can detect
missing, duplicate, or unexpected records; they cannot freeze live
attribute values across requests. See [retrieval and
downloads](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.md)
for integrity and resume behavior.

## Monitoring and evidence

The scheduled monitoring workflow runs twice weekly and samples the 35
checked layers across all six publishers, live discovery, and county
facility retrievals. County checks use both discovery descriptors and
stable IDs and verify server projection to EPSG:4326. Each retrieval
requests at most two rows with explicit timeouts; portal scans examine
at most one service item per publisher. The [test
guide](https://github.com/Jaclenga/tampaBayOpenData/blob/main/tests/README.md)
describes these bounded checks and the full manual live suite. Completed
runs provide dated evidence of source behavior, not a guarantee of
future service availability, complete publisher coverage, or record
freshness. The [dated validation
record](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/validation.md)
provides additional check history.

## Cite the package and its data sources

If you use `tampaBayOpenData` in published work, cite the package
version you used. After installation, obtain its citation text or a
BibTeX entry in R:

``` r

citation("tampaBayOpenData")
toBibtex(citation("tampaBayOpenData"))
```

Cite the original data publisher and dataset separately.
`dataset_info(id)` provides source details, and
`dataset_provenance(result)` records the source and retrieval time for a
downloaded result. The package’s MIT license applies to its software,
**not** to government datasets. The publishers remain responsible for
their data and reuse terms. `tampaBayOpenData` is independent of those
organizations and of rOpenSci.

For implementation details, see the [architecture and research
basis](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/architecture.md).

# Coverage, provenance, and source limits

The package retrieves public ArcGIS data; it does not host or archive
the records. This dashboard describes the **selective checked catalog**
bundled with this package. It never represents a complete inventory of
any publisher’s datasets.

The checked catalog lists layers curated for direct use by ID. A
successful health check means one layer’s endpoint and metadata passed a
recent check; it does not establish that its records are fresh or that a
full download will succeed. **Live discovery** searches publisher
portals for additional items when you call it. Portal indexing, service
availability, and search limits affect those results, so neither this
dashboard nor live discovery measures complete publisher coverage.

Checked entries

52

Selected layers in the bundled catalog

Publishers represented

6

Organizations in the checked catalog

Recently healthy

52

Successful checks within 30 days

Detected problems

0

Recent unavailable, changed, or unsupported layers

Missing schema baselines

0

Layers without a saved field and geometry comparison

Latest verification

2026-10-29 14:31 UTC

Latest matching health report

0 checked entries have no conclusive recent health result.

## By publisher

| Publisher | Checked entries | Last verification | Healthy | Problematic | Unverified |
|----|----|----|----|----|----|
| City of Clearwater | 6 | 2026-10-29health report | 6 | 0 | 0 |
| City of St. Petersburg | 7 | 2026-10-29health report | 7 | 0 | 0 |
| City of Tampa | 20 | 2026-10-29health report | 20 | 0 | 0 |
| Hillsborough County | 8 | 2026-10-29health report | 8 | 0 | 0 |
| Pinellas County | 7 | 2026-10-29health report | 7 | 0 | 0 |
| Tampa Bay Regional Planning Council | 4 | 2026-10-29health report | 4 | 0 | 0 |

Checked catalog entries and current verification by publisher {.table
.tb-coverage-table}

## By dataset

Search datasets Publisher All publishers City of Clearwater City of
St. Petersburg City of Tampa Hillsborough County Pinellas County Tampa
Bay Regional Planning CouncilStatus All statuses Healthy Problematic
Unverified

[TABLE]

Checked datasets, dated evidence, current status, and source limits
{#tb-coverage-datasets .table .tb-coverage-table}

## Methodology and known gaps

Counts and publisher names come directly from the bundled checked
catalog at site build time. This page uses the latest usable health
report when one is supplied to the build. A report row must match the
current catalog publisher, jurisdiction, dataset ID, and ArcGIS
endpoint. A result is **healthy** or **problematic** only when it is no
older than 30 days and no older than the catalog’s dated check. Recent
`unavailable`, `schema_changed`, and `unsupported` results count as
problematic. `unknown`, older, mismatched, and absent results are
**unverified**. A timeout alone remains inconclusive. The last
verification column labels catalog checks separately from health
reports; catalog dates never imply a recent successful health check.

Some publisher datasets have not been curated into the checked catalog.
Publisher portals and services may be only partly represented, and
discovery can miss unindexed or unavailable items. The dashboard counts
layers without a saved schema baseline; those layers cannot receive a
field and geometry comparison until a baseline is curated. Health checks
read layer metadata and do not run record count or object-ID queries.
Each dataset’s notes include its curated scope limits and relevant
recent failure diagnostics. The [catalog
policy](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/checked-catalog-policy.md)
records selection criteria; the [discovery
article](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.md)
explains live search limits.

## Interpret source scope before analysis

Tampa’s permits and development cases are active views, not complete
historical ledgers. Its `city-boundary` follows a shoreline
representation, not a legal survey, and `water-service-area` extends
beyond city limits. Clearwater’s park buffers are not park footprints;
its critical-assets layer locates assets, not hazards. The Pinellas
housing layer is a program inventory, not all housing. Hillsborough
transit routes are not a live schedule. The regional planning council’s
storm surge layer is a historical planning model, not current emergency
guidance.

These layers alone do not establish legal boundaries, road restrictions,
service eligibility, or facility status. Comparable demographic coverage
and current flood and environmental coverage across all six publishers
remain limited. Inspect each layer’s `scope_note` and source metadata
for its own limits. The current Tampa `fire-stations` source uses
unqualified fields such as `NAME`; older joined `GIS.GovServiceInfo.*`
fields are unavailable.

``` r

library(tampaBayOpenData)

info <- tbod_dataset_info("construction-permits")
info[c("title", "source_url", "scope_note", "terms", "verified")]
```

The output is a named list about one dataset, not a table of permit
records. `source_url` takes you to the publisher’s source page;
`scope_note` helps decide whether the records can answer your question,
and `terms` describes reuse conditions. These are reasons to inspect
metadata before downloading.

`verified` records an endpoint check, not feature freshness. A portal
item’s `modified` date can also differ from its records’ dates;
`modified_source` distinguishes live item timestamps from saved catalog
snapshots.

Discovered items may change, disappear, or lack clear reuse terms.
Inspect their source metadata and publisher terms. The checked catalog
remains available offline if a live portal fails.

## Keep provenance with results

[`tbod_provenance()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_provenance.md)
reads a record attached to a retrieved tibble or `sf` object. It
includes publisher and source URLs, portal and item ID when known,
validation status, query, retrieval time, row counts, integrity method,
and completeness. Direct URL retrieval has `not_checked` status.

``` r

projects <- tbod_get_dataset("development-cases", spatial = TRUE, out_sr = 4326)
source <- tbod_provenance(projects)
saveRDS(list(data = projects, provenance = source), "development-cases.rds")
```

The saved RDS file contains two named components: `data` is the spatial
table of active case features, and `provenance` describes the request
that produced it. This lets someone revisiting your map distinguish a
change in source data from a change in your analysis.

Save provenance separately before transformations or exports that may
discard attributes. A finite subset is marked incomplete when more rows
match. Object-ID checks detect missing, duplicate, or unexpected
records, but cannot freeze live attributes across requests. See
[retrieval and
downloads](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.md)
for the integrity methods.

## Monitoring and evidence

Use
[`tbod_check_catalog()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_check_catalog.md)
for a current metadata and schema check of the bundled catalog, or pass
`ids` to inspect selected layers:

``` r

health <- tbod_check_catalog(ids = c("construction-permits", "stpete-parks"))
health[, c("dataset_id", "status", "schema_status", "details")]
```

In the displayed columns, `dataset_id` identifies the entry, `status`
gives the overall check result, `schema_status` describes the structure
comparison, and `details` explains the result. Use these together to
decide which source needs inspection rather than treating every
unsuccessful check as the same problem.

This contacts the publishers and returns one row per checked entry.
Statuses include `healthy`, `unavailable`, `schema_changed`,
`unsupported`, and `unknown`; transient failures remain `unknown` after
bounded retries. Inspect `schema_issues` for field or geometry changes
and `failure_type` and the service and layer status columns for request
failures. The check reads layer metadata and does not run count or
object-ID queries. A healthy row describes that moment’s endpoint and
schema; it does not certify record freshness, full retrieval support, or
future availability.

Twice weekly monitoring checks the selected layers in the checked
catalog, bounded live discovery, and county facility retrieval by
descriptor and stable ID. It also checks server projection to EPSG:4326.
Retrievals request at most two rows; scans inspect at most one service
item per publisher. The [test
guide](https://github.com/Jaclenga/tampaBayOpenData/blob/main/tests/README.md)
describes these bounds and the manual live suite. The [validation
record](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/validation.md)
dates completed checks; they cannot guarantee future availability or
record freshness.

A separate weekly [catalog health
workflow](https://github.com/Jaclenga/tampaBayOpenData/blob/main/.github/workflows/catalog-health.yaml)
uses
[`tbod_check_catalog()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_check_catalog.md)
and uploads timestamped RDS, CSV, and Markdown reports. It does not
change the bundled catalog.

## Cite the package and its data sources

For published work, cite the package version you used. R provides
citation text and BibTeX after installation:

``` r

citation("tampaBayOpenData")
toBibtex(citation("tampaBayOpenData"))
```

Cite the original data publisher and dataset separately.
`tbod_dataset_info(id)` gives source details; `tbod_provenance(result)`
records source and retrieval time. The MIT license applies to the
package software, **not** government datasets. Publishers set their data
terms. The package is independent of them and of rOpenSci.

For implementation details, see the [architecture and research
basis](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/architecture.md).

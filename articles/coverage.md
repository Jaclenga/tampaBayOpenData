# Coverage, provenance, and source limits

This dashboard covers the package’s selected catalog, not every
publisher dataset. The package retrieves records without hosting or
archiving them.

Health checks test endpoints and metadata. They do not confirm record
freshness or guarantee a full download.

Checked entries

52

Selected layers in the bundled catalog

Publishers represented

6

Organizations in the checked catalog

Recently healthy

51

Successful checks within 30 days

Detected problems

1

Recent unavailable, changed, or unsupported layers

Missing schema baselines

0

Layers without a saved field and geometry comparison

Latest verification

2026-11-13 15:32 UTC

Latest matching health report

0 checked entries have no conclusive recent health result.

## By publisher

| Publisher | Checked entries | Last verification | Healthy | Problematic | Unverified |
|----|----|----|----|----|----|
| City of Clearwater | 6 | 2026-11-13health report | 5 | 1 | 0 |
| City of St. Petersburg | 7 | 2026-11-13health report | 7 | 0 | 0 |
| City of Tampa | 20 | 2026-11-13health report | 20 | 0 | 0 |
| Hillsborough County | 8 | 2026-11-13health report | 8 | 0 | 0 |
| Pinellas County | 7 | 2026-11-13health report | 7 | 0 | 0 |
| Tampa Bay Regional Planning Council | 4 | 2026-11-13health report | 4 | 0 | 0 |

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

## Read the dashboard

Counts come from the bundled catalog. Health reports must match the
current entry and endpoint, be no older than 30 days, and be at least as
recent as the catalog check. Recent failures are problematic; stale,
absent, mismatched, or inconclusive results are unverified.

Layers without saved schemas cannot receive field and geometry
comparisons. Health checks inspect metadata only. See the [catalog
policy](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/checked-catalog-policy.md)
and [discovery
guide](https://jaclenga.github.io/tampaBayOpenData/articles/discovery.md)
for selection and search limits.

## Check what each source covers

- Tampa permits and development cases cover active views, not full
  histories.
- City boundaries and park buffers need careful interpretation.
- Housing inventories, transit routes, and historical storm-surge models
  do not confirm eligibility, schedules, or current emergency
  conditions.

Read each layer’s `scope_note` and source metadata before analysis.

``` r

library(tampaBayOpenData)

info <- tbod_dataset_info("tampa-construction-permits")
info[c("title", "source_url", "scope_note", "terms", "verified")]
```

`source_url`, `scope_note`, and `terms` describe the source and reuse
conditions.

`verified` dates an endpoint check. Portal `modified` dates may also
differ from individual record dates.

## Keep provenance with results

Save the source, query, retrieval time, and completeness details with
the data:

``` r

projects <- tbod_get_dataset("tampa-development-cases", spatial = TRUE, out_sr = 4326)
source <- tbod_provenance(projects)
saveRDS(list(data = projects, provenance = source), "development-cases.rds")
```

Transformations may drop provenance attributes. Retrieval checks detect
missing or repeated IDs, but live attributes can change during a
download. See
[retrieval](https://jaclenga.github.io/tampaBayOpenData/articles/retrieval.md).

## Check catalog health

Check selected layers against current metadata:

``` r

health <- tbod_check_catalog(ids = c("tampa-construction-permits", "st-pete-parks"))
health[, c("dataset_id", "status", "schema_status", "details")]
```

Read `status`, `schema_status`, and `details` for each result.

Statuses include `healthy`, `unavailable`, `schema_changed`,
`unsupported`, and `unknown`. Inspect `schema_issues` or `failure_type`
for details. A healthy result applies to the endpoint and schema at
check time.

See the [test
guide](https://github.com/Jaclenga/tampaBayOpenData/blob/main/tests/README.md)
and [validation
record](https://github.com/Jaclenga/tampaBayOpenData/blob/main/docs/validation.md)
for monitoring details.

The weekly [health
workflow](https://github.com/Jaclenga/tampaBayOpenData/blob/main/.github/workflows/catalog-health.yaml)
saves reports without changing the catalog.

## Cite the package and its data sources

Get the package citation:

``` r

citation("tampaBayOpenData")
toBibtex(citation("tampaBayOpenData"))
```

Also cite the original publisher and dataset, including retrieval time.
The package’s MIT license covers its software; each publisher sets data
terms. The package is independent of the publishers and rOpenSci.

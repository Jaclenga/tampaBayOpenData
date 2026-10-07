# Short exploration stories

These eight R Markdown reports use live public ArcGIS layers through
`tampaBayOpenData`. Each asks one bounded question, checks retrieval
provenance, shows a small diagnostic table and chart, and explains what the
source cannot prove. Knit a report to refresh its results.

| Report | Question | API path and stress case |
| --- | --- | --- |
| [01 Tampa capital projects](01-tampa-capital-project-grain.Rmd) | Does one map feature equal one project? | Checked layer, full pagination and repeated business IDs |
| [02 St. Petersburg parks](02-stpete-parks.Rmd) | How concentrated is mapped park area? | Checked polygon layer, `sf` and projected area |
| [03 Clearwater park buffers](03-clearwater-park-buffers.Rmd) | How do buffer distances affect mapped area? | Checked polygon layer, source field interpretation |
| [04 Hillsborough water quality](04-hillsborough-water-quality.Rmd) | Which records support a paired surface and bottom reading? | Checked sample layer, missing values and paired observations |
| [05 Pinellas assisted housing](05-pinellas-assisted-housing.Rmd) | How do reported units vary by housing program? | Checked facility layer, numeric validation and group summaries |
| [06 TBRPC data centers](06-tbrpc-data-center-inventory.Rmd) | Which statuses and size units occur in the inventory? | Checked layer, small sample and mixed measurement units |
| [07 Library schemas](07-library-schema-harmonization.Rmd) | What mapping is needed for two library directories? | Two checked publishers, missing and differently named fields |
| [08 Tampa yard waste](08-direct-yard-waste-schedule.Rmd) | Do pickup-day polygon counts track mapped area? | Direct ArcGIS URL, `not_checked` provenance and `sf` |

## Run a report

Use R 4.1 or later. Install the package and rendering dependencies in the R
library used for knitting:

```r
install.packages(c("pak", "rmarkdown", "knitr", "sf"))
pak::pak("Jaclenga/tampaBayOpenData")
```

Open an `.Rmd` in RStudio and select **Knit**, or run:

```r
rmarkdown::render("explorations/stories/01-tampa-capital-project-grain.Rmd")
```

Rendering HTML also requires Pandoc, which RStudio normally provides.

Reports 02 and 08 require `sf`; all reports require network access to the
listed publisher services. To try local package changes, install this
repository's package into the R library used for knitting first.

Every full retrieval asserts `tbod_provenance(result)$complete`. A failed
assertion, schema error, or unreachable service should be investigated before
interpreting a chart. The package checks object-ID membership for a full
download, but a publisher can still edit attributes during a request. The
reports show only short previews and aggregates; no bulk source data is
committed. Each report includes its source link and scope notes.

The separate [full bicycle-network exploration](../tampa-bicycle-network-eda.Rmd)
asks a deeper question using the same R package.

## Run notes from October 6, 2026

The eight analyses ran end to end against the live services with the installed
0.1.0 package. Their full retrievals passed `complete` checks and generated
charts. The source records exposed several analysis choices:

- Tampa's capital-project map repeats project IDs and includes apparent
  placeholder IDs, so feature rows cannot be used as project counts or summed
  project costs without a publisher-supported rule.
- Hillsborough's `Name_Full` library field was empty in this run; the combined
  directory uses `Name_Label` as an explicit fallback.
- TBRPC's `Estimated_Size` contains both square-foot and acre text, and its
  status field includes records beyond existing facilities.
- Clearwater's park-buffer areas describe buffers. They should not be summed
  as park acreage or unique service coverage.

These are dated observations about source records and field meanings, not
claims that the package verified the publishers' facts.

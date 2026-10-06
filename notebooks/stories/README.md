# Short exploration stories

These eight R notebooks use live public ArcGIS layers through `tampaBayOpenData`.
Each asks one bounded question, checks the package's retrieval provenance, shows
a small diagnostic table and chart, and explains what the source cannot prove.
They are examples for trying the API across publishers and data shapes. The
saved outputs record one run; run the cells again for current publisher data.

| Notebook | Question | API path and stress case |
| --- | --- | --- |
| [01 Tampa capital projects](01-tampa-capital-project-grain.ipynb) | Does one map feature equal one project? | Checked layer, full pagination and repeated business IDs |
| [02 St. Petersburg parks](02-stpete-parks.ipynb) | How concentrated is mapped park area? | Checked polygon layer, `sf` and projected area |
| [03 Clearwater park buffers](03-clearwater-park-buffers.ipynb) | How do buffer distances affect mapped area? | Checked polygon layer, source field interpretation |
| [04 Hillsborough water quality](04-hillsborough-water-quality.ipynb) | Which records support a paired surface and bottom reading? | Checked sample layer, missing values and paired observations |
| [05 Pinellas assisted housing](05-pinellas-assisted-housing.ipynb) | How do reported units vary by housing program? | Checked facility layer, numeric validation and group summaries |
| [06 TBRPC data centers](06-tbrpc-data-center-inventory.ipynb) | Which statuses and size units occur in the inventory? | Checked layer, small sample and mixed measurement units |
| [07 Library schemas](07-library-schema-harmonization.ipynb) | What mapping is needed for two library directories? | Two checked publishers, missing and differently named fields |
| [08 Tampa yard waste](08-direct-yard-waste-schedule.ipynb) | Do pickup-day polygon counts track mapped area? | Direct ArcGIS URL, `not_checked` provenance and `sf` |

## Run them

Use R 4.1 or later with a Jupyter R kernel. In R, install the package and
spatial dependency, then register the kernel if needed:

```r
install.packages(c("pak", "IRkernel", "sf"))
pak::pak("Jaclenga/tampaBayOpenData")
IRkernel::installspec(user = TRUE)
```

Open an individual `.ipynb` in Jupyter and run all cells. An installed copy of
`tampaBayOpenData`, `sf` for notebooks 02 and 08, and network access to the
listed publisher services are required. To try local package changes instead,
install the repository package into the R library used by the kernel before
running the stories.

Every full retrieval asserts `tbod_provenance(result)$complete`. A failed
assertion, schema error, or unreachable service should be investigated before
interpreting the chart. The package checks object-ID membership for a full
download, but a publisher can still edit attributes while a request is in
progress. The notebooks display only short previews and aggregates; they do
not commit bulk source data. Their source links and scope notes are part of
each story.

The separate [full bicycle-network exploration](../tampa-bicycle-network-eda.ipynb)
uses Python and queries Tampa's service directly. These stories exercise the R
package itself.

## Run notes from October 6, 2026

All eight notebooks ran end to end against the live services with the installed
0.1.0 package. Every full retrieval passed its `complete` check, every notebook
saved one chart, and none has an error output. The examples exposed several
analysis choices that a reader must make even after successful retrieval:

- Tampa's capital-project map repeats project IDs and includes apparent
  placeholder IDs, so feature rows cannot be used as project counts or summed
  project costs without a publisher-supported rule.
- Hillsborough's `Name_Full` library field was empty in this run; the combined
  directory uses `Name_Label` as an explicit fallback.
- TBRPC's `Estimated_Size` contains both square-foot and acre text, and its
  status field includes records beyond existing facilities.
- Clearwater's park-buffer areas describe buffers. They should not be summed
  as park acreage or unique service coverage.

These are observations about the dated source records and field meanings, not
claims that the package verified the publishers' facts.

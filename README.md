# tampaBayOpenData

[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](DESCRIPTION)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.md)
[![R CMD check](https://github.com/Jaclenga/tampaBayOpenData/actions/workflows/R-CMD-check.yaml/badge.svg?branch=main)](https://github.com/Jaclenga/tampaBayOpenData/actions/workflows/R-CMD-check.yaml)
[![pkgcheck](https://github.com/Jaclenga/tampaBayOpenData/actions/workflows/pkgcheck.yaml/badge.svg?branch=main)](https://github.com/Jaclenga/tampaBayOpenData/actions/workflows/pkgcheck.yaml)
[![Offline test coverage workflow](https://github.com/Jaclenga/tampaBayOpenData/actions/workflows/test-coverage.yaml/badge.svg?branch=main)](https://github.com/Jaclenga/tampaBayOpenData/actions/workflows/test-coverage.yaml)

Public data for the Tampa Bay region is spread across separate ArcGIS portals.
Finding a layer, retrieving all its records, and recording where they came from
can make regional analysis hard to repeat. `tampaBayOpenData` gives researchers,
planners, journalists, and civic technologists one R interface to discover and
retrieve public data from Tampa, St. Petersburg, Clearwater, Hillsborough
County, Pinellas County, and the Tampa Bay Regional Planning Council.

Search a bundled catalog of 26 maintainer-checked city layers offline, or
discover other layers on the live portals. Retrieve records as tibbles or
optional `sf` objects, with source provenance and validation status attached.
The package focuses on reproducible access to these regional sources; the
publishers remain responsible for their data and its reuse terms.

## Install

In an R console, install directly from GitHub:

```r
install.packages("pak") # Run once, if pak is not installed yet.
pak::pak("Jaclenga/tampaBayOpenData")
```

If you are working from a local source directory, install it with:

```r
install.packages(c("httr2", "jsonlite", "tibble"))
install.packages(".", repos = NULL, type = "source")
```

For a built archive, replace `"."` with its `.tar.gz` path.
For spatial results, also install `sf`. Installing from the local source
directory does not build the vignette. Building it with `R CMD build` requires
`knitr`, `rmarkdown`, and Pandoc.

## Find and retrieve a dataset

```r
library(tampaBayOpenData)

search_datasets("parks")

parks <- get_dataset("stpete-parks")
```

Search returns a table of matching datasets. Pass a result's `id` to
`get_dataset()` to retrieve its records as an R tibble; `stpete-parks` is one of
the checked IDs. Search scans live portals by default, so it may take time and
needs internet access. To browse only the checked catalog offline, use
`search_datasets("parks", source = "checked")`. Retrieving records still contacts
the publisher's service.

## Explore live sources

```r
found <- search_datasets("housing", source = "live", portals = "city")
found[, c("id", "title", "publisher", "validation_status")]

# A one-row search result also carries the source needed for retrieval.
housing <- get_dataset(found[1, ], limit = 100)
dataset_provenance(housing)
```

`list_datasets()` and `search_datasets()` search the six configured public ArcGIS
organizations by default. `list_portals()` lists their IDs, publishers, and
source locations offline. Choose live organizations with `portals = "city"`
(Tampa), `"tbrpc"`, `"stpete"`, `"clearwater"`, `"hillsborough"`, or `"pinellas"`,
or pass a vector of these names.
`source = "live"` returns only portal results, including checked matches found
there. Catalog functions default to `jurisdiction = "all"`; use a jurisdiction
code or vector to filter both checked and live results. `source = "checked"`
reads the bundled catalog **offline**:

```r
list_portals()[, c("id", "publisher", "jurisdiction")]
list_datasets(source = "checked")[,
  c("id", "title", "jurisdiction", "validation_status")]
search_datasets("park", source = "checked", spatial = TRUE,
                publisher = c("City of St. Petersburg", "City of Clearwater"))
dataset_info("construction-permits")
```

County jurisdictions have no checked entries yet: selecting them with
`source = "checked"` returns an empty catalog. Retrieval and download functions
retain their default `jurisdiction = "tampa"`; uniquely named checked IDs such
as `stpete-parks` also resolve when that argument is omitted.

### Filter discovery results

Both catalog functions accept these optional filters:

| Filter | Match |
| --- | --- |
| `jurisdiction` | Codes from `list_portals()`, such as `"pinellas"`, or a vector of codes. The default is `"all"`. |
| `publisher` | Exact publisher names from `list_portals()`, ignoring case. |
| `validation_status` | `"checked"` or `"discovered"`. |
| `spatial` | `TRUE` for geometry layers, `FALSE` for tables; unknown geometry is excluded when filtering. |
| `topic` | Literal substring in tags and categories, ignoring case. |
| `category` | Exact category path or final category label, ignoring case. |
| `modified_after`, `modified_before` | Inclusive bounds on the catalog's `modified` timestamp. |

Character filters accept vectors: values within one filter are alternatives,
and separate filters must all match. Date bounds accept `Date` or `"YYYY-MM-DD"`
for whole UTC days, or `POSIXct` for exact instants. Rows with no modification
time are excluded only when a date filter is supplied. `modified_source` is
`"portal_item"` for a live item's timestamp or `"checked_snapshot"` for an
upstream timestamp saved in the checked registry. These dates do not establish
record freshness; the separate `verified` date records an endpoint check.

```r
county_transport <- search_datasets(
  "road", source = "live", jurisdiction = "pinellas", spatial = TRUE,
  topic = "transportation", modified_after = as.Date("2025-01-01"),
  max_items = 10
)
county_transport[, c("id", "title", "publisher", "modified", "modified_source")]
```

Jurisdiction and publisher filters narrow the organizations scanned. Other
filters apply to the combined catalog after scanning, so `max_items` can stop a
scan before other matching items are reached. Inspect `discovery_complete` and
increase `max_items` when you need a broader search.

`validation_status = "checked"` means maintainers tested that layer;
`"discovered"` marks a candidate from a public portal index; maintainers have
not validated its contents or reuse terms. Retrieval validates query responses
and requires `Query` when the layer declares its capabilities. Checked IDs
such as `construction-permits` remain stable. Unchecked portal results use IDs
such as `arcgis:<item-id>:<layer-id>`; pass an ID or a one-row result to
`get_dataset()`.
A portal's `modified` date describes its item, not necessarily the age of every
record. `max_items` limits portal **items per organization**, not the number of
layers returned. The default scans at most 25 items per organization; set
`max_items = Inf` explicitly for a full live listing. Results expose
`discovery_complete`, `discovery_truncated_portals`, and `discovery_scanned_items`
attributes, so a bounded listing is not presented as a complete portal catalog.
Skipped-item and failed-portal details are attached as `discovery_issues` and
`discovery_failed_portals` attributes on the catalog result.

Prefixed checked IDs also retrieve municipal layers in an online R session:

```r
libraries <- get_dataset("clearwater-libraries", limit = 2)
stpete_parks <- get_dataset("stpete-parks", spatial = TRUE, out_sr = 4326, limit = 2)
```

For current source fields, use
`dataset_info("construction-permits", refresh = TRUE)$fields`; the same result's
`$metadata` contains query capabilities.

```r
permits <- get_dataset(
  "construction-permits",
  where = "PROJECTSTATUS IS NOT NULL",
  fields = c("RECORD_ID", "PROJECTSTATUS", "LASTUPDATE"),
  limit = 100
)
head(permits)
dataset_provenance(permits)
```

`where` uses ArcGIS SQL rather than Socrata SoQL, and `fields` uses exact source
field names. A finite `limit` returns a subset; provenance marks it incomplete
when more records match. The default `limit = Inf` retrieves all matches. Use
`order_by` for an ordered subset when the service supports ordering and
pagination. `query`
accepts supported advanced ArcGIS filters, such as spatial and time filters;
see `?get_dataset` for parameters and restrictions.

For services with more than 10,000 matches and reliable ordering and pagination,
a finite preview of at most 1,000 rows uses an ordered sample and verifies those
returned IDs with a subset manifest. Other requests use the full matching ID
manifest; `integrity = "full"` requests that path explicitly. Provenance identifies
the path as `subset-manifest`, `full-manifest`, or `count-only` for `limit = 0`.
A preview stays incomplete when additional records match.

`timeout` limits each HTTP attempt. `total_timeout` sets an overall time budget:
120 seconds for retrieval, 90 seconds for catalog discovery, and 60 seconds for
metadata inspection by default. Set `total_timeout = Inf` explicitly for a long
operation that should have no overall deadline.
Requests and retry waits use the remaining budget. Parsing is checked after
it finishes, so computation can exceed the budget before reporting a timeout.

The main functions are:

| Function | Purpose |
| --- | --- |
| `list_portals()` | List configured public ArcGIS organizations and their identities offline. |
| `list_datasets()`, `search_datasets()` | Search configured public ArcGIS organizations, with checked entries identified. Use `source = "checked"` offline. |
| `dataset_info()` | Inspect a checked or discovered layer; `refresh = TRUE` fetches the live schema. |
| `get_dataset()` | Retrieve a checked ID, discovered ID, or one-row discovery result. |
| `get_arcgis_layer()` | Retrieve a compatible public ArcGIS layer directly by URL. |
| `get_permits()`, `get_development_cases()`, `get_capital_projects()` | Shortcuts for three catalog entries. |
| `download_dataset()`, `download_arcgis_layer()` | Download matching records into resumable local RDS chunks. |
| `dataset_provenance()` | Read source, validation status, query, timing, row counts, integrity, and completeness. |

Source field names and text fields retain their spelling. ArcGIS epoch-millisecond
date fields become UTC `POSIXct` unless the source declares an unknown time zone.
In that case they remain raw milliseconds with a warning; UTC editor-tracking
creation and edit dates identified by the layer metadata are still converted.
Date-only fields become `Date`; time-only and timestamp-offset fields remain
strings.

## How this relates to other tools

| Tool | When to use it | What `tampaBayOpenData` adds |
| --- | --- | --- |
| [`nycOpenData`](https://docs.ropensci.org/nycOpenData/) | Access New York City's Socrata Open Data API. | A Tampa Bay focus and discovery and retrieval from multiple ArcGIS publishers, using ArcGIS queries rather than Socrata SoQL. |
| [ArcGIS REST API](https://developers.arcgis.com/rest/services-reference/enterprise/query-feature-service-layer/) | Work directly with a known ArcGIS service and its query parameters. | A regional publisher registry, checked dataset IDs, bounded discovery, typed R results, provenance, and resumable downloads. `get_arcgis_layer()` also accepts a direct layer URL. |
| [`arcgislayers`](https://r.esri.com/arcgislayers/) | Work broadly with ArcGIS data services, including feature layers, imagery, and portal items. | A focused Tampa Bay catalog and workflow for finding public regional layers, distinguishing checked from discovered results, and recording retrieval provenance. |

## Spatial results

```r
install.packages("sf") # once
projects <- get_dataset("development-cases", spatial = TRUE, out_sr = 4326)
sf::st_crs(projects)
```

`spatial = TRUE` returns an `sf` object. `out_sr = 4326` asks the service for
WGS 84 coordinates; omit `out_sr` to keep the native CRS. The client supports
point, line, and polygon layers, including records with missing geometry.
Nonspatial tables can be retrieved with `spatial = FALSE`.

To query a compatible public layer directly, use its ArcGIS layer URL:

```r
yard_waste <- get_arcgis_layer(
  "https://arcgis.tampagov.net/arcgis/rest/services/OpenData/SolidWaste/MapServer/4",
  limit = 10
)
dataset_provenance(yard_waste)$validation_status # "not_checked" for direct URL access
```

## Resumable downloads

Use `download_dataset()` for a larger retrieval that should write bounded chunks
instead of collecting all feature pages in memory. Choose a directory outside
the package source; repeating the same call resumes a matching download:

```r
saved <- download_dataset(
  "construction-permits",
  path = "~/tampaBayOpenData-downloads/permits",
  fields = c("OBJECTID", "RECORD_ID", "LASTUPDATE"),
  page_size = 500,
  total_timeout = 600
)
saved$complete
first_chunk <- readRDS(saved$files[[1]])
dataset_provenance(first_chunk)
```

Each chunk is a tibble or, with `spatial = TRUE`, an `sf` object. A resume rechecks
the live schema and complete ID manifest, verifies saved chunks against their
checkpoints, and downloads only missing chunks. Changed query options, schema,
CRS, or ID membership require a new directory. Chunk attributes can still change
between requests or resumes; the files are not a frozen snapshot. Downloads
always use full-manifest integrity and retain its one-million-match limit.
Their default `total_timeout = Inf` allows a long operation; a finite deadline
leaves completed chunks available for resumption. `download_arcgis_layer()`
provides the same path for a compatible direct layer URL.

An exclusive directory lock prevents concurrent writers. If an R process is
terminated, confirm it has stopped, then remove its empty `.lock` directory
before resuming. Normal completion and handled errors release the lock.

## Source scope and reliability

The checked catalog contains 26 layers: 20 Tampa, 3 St. Petersburg, and 3
Clearwater. The Tampa layers include active permit and development case views,
not complete historical ledgers. The `city-boundary` layer follows a shoreline
representation and is not a legal survey. The catalog also covers parks,
historic sites, police districts, transportation, zoning, and utility service
areas. The St. Petersburg layers cover parks, city boundaries, and streets;
Clearwater layers cover park buffers, zoning, and libraries.
Hillsborough and Pinellas county layers are available through live discovery;
the checked catalog remains the same 26 city layers.
The park buffers are areas around parks, rather than exact park footprints.
These maps do not by themselves establish legal boundaries, current road restrictions, service
eligibility, or operating status. The `water-service-area` extends beyond city
limits. The current `fire-stations` source uses unqualified field names such as
`NAME` and supports `order_by`; joined service-information fields from the old
source are unavailable. Check a checked entry's `scope_note` and `terms` with
`dataset_info(id)` before analysis. Its `verified` date records an endpoint
check, not the freshness of every feature. Discovered items may change, become
unavailable, or lack clear reuse terms; inspect their source metadata before
use. The package does not verify the reuse terms of discovered items. A live
discovery failure leaves `source = "checked"` available offline.

Twice-weekly monitoring samples the checked city layers, regional discovery,
and county facilities. County checks use both discovery descriptors and stable
IDs and verify server projection to EPSG:4326. Each retrieval requests at most
two rows with explicit timeouts; portal scans use at most one item per publisher.
The [test guide](tests/README.md) describes these bounded checks and the full
manual live suite. Completed runs provide dated evidence of source behavior.

Retrieval compares the matching count and the applicable full or subset
object-ID manifest with downloaded batches. It raises an error for detected
missing, duplicate, or unexpected records. Live records can change during a
request, so a successful result is
not a frozen snapshot of every attribute. Very large queries may need a
narrower `where` clause: full-manifest retrieval rejects more than one million
matches. Eligible finite previews can verify a bounded subset instead.

`dataset_provenance()` records the publisher, source layer or item URL, portal
and item ID when known, validation status, query endpoint, retrieval time,
options, row counts, and completeness. Save that record separately before
transformations that may discard R attributes:

```r
source <- dataset_provenance(projects)
saveRDS(list(data = projects, provenance = source), "development-cases.rds")
```

The source organizations publish the data; the package's MIT license applies
to the software, not to government datasets. `tampaBayOpenData` is independent
of those organizations and rOpenSci.

## Citation

If you use `tampaBayOpenData` in published work, cite the package version you
used. After installation, get the citation text or a BibTeX entry in R:

```r
citation("tampaBayOpenData")
toBibtex(citation("tampaBayOpenData"))
```

Cite the original data publisher and dataset separately. `dataset_info(id)`
provides source details, and `dataset_provenance(result)` records the source and
retrieval time for a downloaded result.

## More information

- [Coverage workflow](https://github.com/Jaclenga/tampaBayOpenData/actions/workflows/test-coverage.yaml):
  each run summary reports the current offline test coverage percentage; the
  badge above shows whether the workflow passed.
- [Bicycle network notebook](inst/examples/bike-network.Rmd): catalog discovery,
  an optional live subset, provenance, and a map.
- [Introduction vignette](vignettes/introduction.Rmd): a fuller walkthrough.
  After installing an archive built with `R CMD build`, use
  `vignette("introduction", package = "tampaBayOpenData")`.
- [Architecture](docs/architecture.md) and [Tampa source research](docs/research-tampa.md):
  client design and catalog verification.
- [Contributing](CONTRIBUTING.md) and [test suite guide](tests/README.md):
  development, offline tests, and opt-in live checks.
- [Dated validation record](docs/validation.md) and
  [security audit](docs/security-audit.md): checks and known limitations.

The design was inspired by rOpenSci's [`nycOpenData`](https://docs.ropensci.org/nycOpenData/)
([source code](https://github.com/ropensci/nycOpenData)); the ArcGIS client was
implemented independently.

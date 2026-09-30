# tampaBayOpenData

[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](DESCRIPTION)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.md)
[![R CMD check](https://img.shields.io/badge/R%20CMD%20check-OK-brightgreen.svg)](docs/validation.md)

`tampaBayOpenData` provides a lightweight R interface to public datasets
published by the City of Tampa through its
[GeoHub](https://city-tampa.opendata.arcgis.com/) and
[ArcGIS REST services](https://arcgis.tampagov.net/arcgis/rest/services).

The package allows users to discover, inspect, filter, and retrieve datasets
into R without manually constructing service URLs, handling pagination,
parsing JSON, or converting spatial geometry.

For students, educators, analysts, and researchers, `tampaBayOpenData` reduces
the technical overhead of working with local civic data while preserving the
source fields and government provenance needed for reproducible research.

Version **0.1.0** introduces a catalog-driven interface to **eight verified
City of Tampa datasets**. Only the City of Tampa is supported in this release;
the jurisdiction argument leaves room for future regional providers.

Users can explore the City's portals or begin with the package catalog, then
move from discovery to analysis using ordinary R tables and `sf` objects.

---

## How tampaBayOpenData Works

The package wraps the City's ArcGIS FeatureServer and queryable MapServer
services. Its supported catalog is a versioned registry bundled with the package.

Internally, `tampaBayOpenData`:

- reads verified dataset metadata from the bundled registry;
- retrieves the current field schema and query capabilities from the service;
- sends parameterized ArcGIS REST requests;
- downloads matching records in bounded batches and checks their object IDs;
- parses declared field types into tibble columns;
- converts requested geometry into `sf` objects with verified CRS;
- attaches source and retrieval provenance to the result.

Most workflows begin with `list_datasets()` or `search_datasets()`. These
functions work offline. Datasets use readable package IDs such as
`"construction-permits"`, separate from ArcGIS item IDs and service-layer numbers.

The package provides four core functions:

- `list_datasets()` — List supported datasets, including titles, descriptions,
  jurisdictions, source pages, service URLs, geometry, tags, and verification dates.
- `search_datasets()` — Search titles, descriptions, tags, categories, and
  package IDs using straightforward matching.
- `dataset_info()` — Inspect a dataset's metadata and provenance. Set
  `refresh = TRUE` to retrieve its live field schema and service capabilities.
- `get_dataset()` — Retrieve a registered dataset with automatic pagination,
  field selection, filtering, optional ordering, and spatial support.

Retrieval options include:

- `jurisdiction`;
- `where`;
- `fields`;
- `order_by`;
- `limit`;
- `spatial` / `out_sr`;
- `query`;
- `timeout`.

`get_dataset()` returns a **tibble** by default and an **sf object** when
`spatial = TRUE`. The convenience functions `get_permits()`,
`get_development_cases()`, and `get_capital_projects()` use the same client.

Government column names, strings, and coded values retain their source spelling.
Declared ArcGIS date fields become UTC `POSIXct` where their semantics are known.
Date-looking strings remain strings; dates with unknown time-zone semantics
remain raw epoch milliseconds with a warning.

Filtering uses ArcGIS SQL through `where`. Advanced spatial, time, and version
parameters can be supplied through `query = list(...)`; see `?get_dataset` for
supported parameters. `dataset_provenance()` exposes the source, retrieval time,
query, row counts, and completeness flag.

---

## Installation

### From local source

Run these commands from the package source directory:

```r
install.packages(c("httr2", "jsonlite", "tibble"))
install.packages(".", repos = NULL, type = "source")
```

### From a built source archive

With the release archive in your working directory:

```r
install.packages(c("httr2", "jsonlite", "tibble"))
install.packages(
  "tampaBayOpenData_0.1.0.tar.gz",
  repos = NULL,
  type = "source"
)
```

Install the optional spatial dependency:

```r
install.packages("sf")
```

Building the vignette from source also requires `knitr`, `rmarkdown`, and Pandoc.
Development setup is described in [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Example

```r
library(tampaBayOpenData)

# Browse supported datasets.
catalog <- list_datasets()
catalog[, c("id", "title")]

# Find permit-related datasets.
search_datasets("permit")

# Understand the government source.
dataset_info("construction-permits")

# Retrieve all matching permit records with automatic pagination.
permits <- get_dataset("construction-permits")
head(permits)
```

Use exact source field names to filter and select columns:

```r
selected <- get_dataset(
  "construction-permits",
  where = "PROJECTSTATUS IS NOT NULL",
  fields = c("RECORD_ID", "PROJECTSTATUS", "LASTUPDATE")
)
table(selected$PROJECTSTATUS, useNA = "ifany")
```

Inspect current fields when constructing a query:

```r
info <- dataset_info("construction-permits", refresh = TRUE)
info$fields
```

For a deliberate subset ordered by the source's update field:

```r
recent <- get_permits(order_by = "LASTUPDATE DESC", limit = 100)
dataset_provenance(recent)
```

The default `limit = Inf` retrieves every match. A limit below the matching
count deliberately returns a subset and records `complete = FALSE` in provenance.
Server ordering requires the service's ordering and pagination capabilities.

### Spatial data

```r
projects <- get_dataset(
  "development-cases",
  spatial = TRUE,
  out_sr = 4326
)
sf::st_crs(projects)
plot(sf::st_geometry(projects))

boundary <- get_dataset("city-boundary", spatial = TRUE)
```

Points, multipart lines, polygons, and missing geometries are supported. Spatial
results use XY coordinates; missing geometries remain as typed empty geometries
in their original rows. `out_sr = NULL` retains the native CRS, while
`out_sr = 4326` requests WGS 84 coordinates from the service. Each projected page
must identify its output CRS.

### Keep provenance

```r
source <- dataset_provenance(projects)
source$publisher
source$source_url
source$retrieved_at

saveRDS(list(data = projects, provenance = source), "development-cases.rds")
```

Results carry dataset ID, title, government publisher, jurisdiction, source
page, endpoint, retrieval time, query options, and row counts. Save provenance
separately when exporting results or using transformations that discard custom
attributes.

## Learn by example

- `vignette("introduction", package = "tampaBayOpenData")` — End-to-end discovery,
  filtering, spatial retrieval, and provenance. Available when built and installed.
- `?get_dataset` — Retrieval options, field parsing, pagination, and query details.
- `?dataset_info` — Supported datasets and live service metadata.

The vignette's catalog examples run offline. Its retrieval examples are shown
without contacting government services during builds.

## About

`tampaBayOpenData` makes City of Tampa public datasets accessible through a small
R data-access interface. Its workflow is **discover → inspect → query → retrieve
→ parse → analyze**, with analysis performed in the user's existing R tools.

The initial catalog covers permit locations, active development cases, public
capital projects, a shoreline-modified city boundary, neighborhood association
boundaries, council districts, Riverwalk segments, and park polygons. Each entry
records source scope and available terms. A layer title alone does not establish
a complete historical permit or inspection archive.

Design decisions and source verification are documented in
[the architecture report](docs/architecture.md),
[Tampa infrastructure research](docs/research-tampa.md), and
[the nycOpenData audit](docs/research-nycOpenData.md).

---

## Development

`tampaBayOpenData` uses `testthat` with representative responses and mocked HTTP
transport. Ordinary tests and package checks run without live City API calls.
Fixtures and helpers are under `tests/testthat/`. The
[test suite guide](tests/README.md) describes coverage, focused checks, and
fixture maintenance. Unmocked HTTP requests are blocked during ordinary tests.

After installing development dependencies, run tests locally:

```r
testthat::test_local()
```

Live integration tests are available explicitly:

```r
Sys.setenv(TAMPA_OPEN_DATA_LIVE = "true")
testthat::test_local(filter = "live", stop_on_failure = TRUE)
```

CI is configured for Linux, Windows, and macOS. Live checks use a separate manual
workflow. Recorded local validation includes **967 passing assertions**,
**98.69% deterministic code coverage**, and an **R CMD check with zero errors,
warnings, or notes**. See [validation details](docs/validation.md) and
[CONTRIBUTING.md](CONTRIBUTING.md) for reproduction commands.
The [security audit](docs/security-audit.md) documents corrected response-boundary
issues, CI hardening, and native dependency requirements for deployment.

---

## Comparison to Other Software

[`nycOpenData`](https://github.com/ropensci/nycOpenData) provides the design
inspiration: a small catalog-driven R interface to a city's civic datasets.
`tampaBayOpenData` applies that workflow to Tampa's ArcGIS services and verified
registry. The ArcGIS client was implemented independently.

The package provides:

- **Simple onboarding:** readable dataset IDs and offline catalog discovery.
- **Source-aware retrieval:** verified City sources, live schemas, and provenance.
- **Checked pagination:** matching counts and object-ID manifests are compared
  with results to detect truncation, missing records, and duplicate pages.
- **Standard R outputs:** tibbles for attributes and optional `sf` objects for
  spatial work.

`sf` supplies the spatial objects and geometry parsing used by this package;
users can continue with their existing mapping and analysis workflows.

---

## Contributing

Contributions to dataset verification, documentation, tests, and retrieval
reliability are welcome. Include the dataset ID, query, package version, and exact
error when reporting a retrieval problem. See [CONTRIBUTING.md](CONTRIBUTING.md).

New registry entries must be verified against official City sources. v0.1
remains focused on the City of Tampa; additional jurisdictions are future work.

---

## Authors & Contributors

### Maintainer

**Jaclenga** — <jack3lenga@gmail.com>

### Contributors

Contributions can improve source verification, endpoint maintenance, tests,
documentation, and the shared client. Contribution guidelines explain how to
prepare a focused change.

### Acknowledgements

The project was inspired by the API design and developer experience of
[rOpenSci's `nycOpenData`](https://github.com/ropensci/nycOpenData), maintained by
Christian A. Martinez. No source code was copied from that MIT-licensed project.

The City of Tampa is the authoritative publisher of the retrieved datasets.
Its [GIS page](https://www.tampa.gov/departments/geographic-information-systems)
links to the City's GeoHub and mapping resources.

---

## Academic Context

The discovery-to-retrieval workflow can support teaching data acquisition,
open-data literacy, and reproducible research using local government sources.
Examples keep analysis in ordinary R and `sf` workflows, with provenance
available for research documentation.

---

## Maintenance

The supported catalog is bundled with the package. Adding datasets requires
verified registry updates and a new package version. Retrieval and refreshed
metadata use live City services, whose availability and schemas can change.

Membership checks detect many upstream changes during retrieval and fail
explicitly for incomplete responses. They do not freeze government records
transactionally; attributes may change during a request. Registry verification
dates describe endpoint checks, rather than the freshness of every record.

### Troubleshooting

- **Unknown dataset or jurisdiction:** use IDs from `list_datasets()`.
  Only `jurisdiction = "tampa"` is supported in v0.1.
- **Unknown field or rejected filter:** inspect
  `dataset_info(id, refresh = TRUE)$fields` and use source field names.
- **Unavailable service:** errors include source and endpoint context.
  Check the official page, retry later, or increase `timeout`.
- **Retrieval-integrity failure:** retry or narrow the query when the source
  changes or truncates a response.
- **Very large query:** narrow the filter. ArcGIS limits object-ID manifests
  to one million matches, including deliberately limited queries.
- **Spatial dependency or CRS error:** install `sf`, inspect the source metadata,
  and request a supported `out_sr`.

---

## Disclaimer

`tampaBayOpenData` is an independent project and is not affiliated with, endorsed
by, or maintained by rOpenSci, NYC Open Data, the City of Tampa, or other Tampa
Bay governments.

The City remains the publisher of the retrieved data. Consult each dataset's
source, scope, and terms; the package's MIT software license does not change
government data terms.

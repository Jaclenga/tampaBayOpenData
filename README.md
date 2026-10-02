# tampaBayOpenData

[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](DESCRIPTION)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.md)

`tampaBayOpenData` is an R client for a curated catalog of 11 City of Tampa
ArcGIS layers. It discovers datasets offline, retrieves records in checked
batches, and returns tibbles or optional `sf` objects with source provenance.
Only `jurisdiction = "tampa"` is supported in version 0.1.0.

## Install

From the package source directory:

```r
install.packages(c("httr2", "jsonlite", "tibble"))
install.packages(".", repos = NULL, type = "source")
```

For a built archive, replace `"."` with its `.tar.gz` path.
For spatial results, also install `sf`. Building the vignette from source
requires `knitr`, `rmarkdown`, and Pandoc.

## Discover and retrieve

```r
library(tampaBayOpenData)

list_datasets()[, c("id", "title")]
search_datasets("permit")
dataset_info("construction-permits")
```

These calls read the bundled catalog without contacting the City. Its IDs are
package identifiers, separate from ArcGIS item and layer IDs. To inspect the
current source fields and capabilities, use
`dataset_info("construction-permits", refresh = TRUE)$fields`.

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

`where` uses ArcGIS SQL and `fields` uses exact source field names. A finite
`limit` returns a subset; provenance marks it incomplete when more records
match. The default `limit = Inf` retrieves all matches. Use `order_by` for an
ordered subset when the service supports ordering and pagination. `query`
accepts supported advanced ArcGIS filters, such as spatial and time filters;
see `?get_dataset` for parameters and restrictions.

The main functions are:

| Function | Purpose |
| --- | --- |
| `list_datasets()`, `search_datasets()` | Browse the supported catalog offline. |
| `dataset_info()` | Read registry metadata; `refresh = TRUE` fetches the live schema. |
| `get_dataset()` | Filter and retrieve attributes or geometry. |
| `get_permits()`, `get_development_cases()`, `get_capital_projects()` | Shortcuts for three catalog entries. |
| `dataset_provenance()` | Read source, query, timing, row counts, and completeness from a result. |

Source field names and strings retain their spelling. Declared ArcGIS date fields
are converted to UTC `POSIXct` when their time-zone meaning is known. Dates with
unknown time-zone semantics remain raw milliseconds with a warning.

## Spatial results

```r
install.packages("sf") # once
projects <- get_dataset("development-cases", spatial = TRUE, out_sr = 4326)
sf::st_crs(projects)
```

`spatial = TRUE` returns an `sf` object. `out_sr = 4326` asks the service for
WGS 84 coordinates; omit `out_sr` to keep the native CRS. The client supports
point, line, and polygon layers, including records with missing geometry.

## Source scope and reliability

The permit and development case layers are active views, not complete historical
ledgers. The `city-boundary` layer follows a shoreline representation and is
not a legal survey. The catalog also includes `fire-stations`, `bike-lanes`,
and `recycling-pickup`: station locations do not establish operating status;
bicycle segments include shared roads and trails; recycling polygons describe
service areas, not a guaranteed pickup day for an address. The fire-station
layer uses qualified field names and does not support `order_by`. Check each
entry's `scope_note` and `terms` with `dataset_info(id)` before analysis.
The catalog's `verified` date records an endpoint check, not the freshness
of every feature.

Retrieval compares the matching count and object-ID manifest with downloaded
batches. It raises an error for detected missing, duplicate, or unexpected
records. Live records can change during a request, so a successful result is
not a frozen snapshot of every attribute. Very large queries may need a
narrower `where` clause: the client rejects more than one million matches
because it requires a complete object-ID manifest.

`dataset_provenance()` records the publisher, source layer or item URL, query
endpoint, retrieval time, options, row counts, and completeness. Save that
record separately before transformations that may discard R attributes:

```r
source <- dataset_provenance(projects)
saveRDS(list(data = projects, provenance = source), "development-cases.rds")
```

The City publishes the data; the package's MIT license applies to the software,
not to government datasets. `tampaBayOpenData` is independent of the City of
Tampa and rOpenSci.

## More information

- [Bicycle network notebook](inst/examples/bike-network.Rmd): offline discovery,
  an optional live subset, provenance, and a map.
- [Introduction vignette](vignettes/introduction.Rmd): a fuller walkthrough.
  After installation, use `vignette("introduction", package = "tampaBayOpenData")`.
- [Architecture](docs/architecture.md) and [Tampa source research](docs/research-tampa.md):
  client design and catalog verification.
- [Contributing](CONTRIBUTING.md) and [test suite guide](tests/README.md):
  development, offline tests, and opt-in live checks.
- [Dated validation record](docs/validation.md) and
  [security audit](docs/security-audit.md): checks and known limitations.

The design was inspired by [rOpenSci's `nycOpenData`](https://github.com/ropensci/nycOpenData);
the ArcGIS client was implemented independently.

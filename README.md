# tampaBayOpenData

[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](DESCRIPTION)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.md)

`tampaBayOpenData` discovers public ArcGIS datasets from the City of Tampa and
Tampa Bay Regional Planning Council, then retrieves records as tibbles or
optional `sf` objects. A bundled catalog of 20 City layers identifies datasets
the package maintainers have checked. Live discovery can find other layers;
each result records its source and validation status.

## Install

From the package source directory, run these commands in an **R console**:

```r
install.packages(c("httr2", "jsonlite", "tibble"))
install.packages(".", repos = NULL, type = "source")
```

For a built archive, replace `"."` with its `.tar.gz` path.
For spatial results, also install `sf`. Installing directly from the source
directory does not build the vignette. Building it with `R CMD build` requires
`knitr`, `rmarkdown`, and Pandoc.

## Discover and retrieve

```r
library(tampaBayOpenData)

found <- search_datasets("housing", source = "live", portals = "city")
found[, c("id", "title", "publisher", "validation_status")]

# Choose one result to retrieve; the one-row descriptor carries its source.
housing <- get_dataset(found[1, ], limit = 100)
dataset_provenance(housing)
```

`list_datasets()` and `search_datasets()` search both public ArcGIS organizations
by default and include the checked catalog. Use `portals = "city"` or
`"tbrpc"` to choose live organizations; `source = "live"` returns only portal
results. `source = "checked"` reads the 20 bundled City entries **offline**:

```r
list_datasets(source = "checked")[, c("id", "title", "validation_status")]
search_datasets("permit", source = "checked")
dataset_info("construction-permits")
```

`validation_status = "checked"` means maintainers tested that layer;
`"discovered"` marks a candidate from a public portal index; maintainers have
not validated its contents or reuse terms. Retrieval validates query responses
and requires `Query` when the layer declares its capabilities. Checked IDs
such as `construction-permits` remain stable. Unchecked portal results use IDs
such as `arcgis:<item-id>:<layer-id>`; pass an ID or a one-row result to
`get_dataset()`.
A portal's `modified` date describes its item, not necessarily the age of every
record. `max_items` limits portal **items per organization**, not the number of
layers returned. A full live listing can take longer than a keyword search.
Skipped-item and failed-portal details are attached as `discovery_issues` and
`discovery_failed_portals` attributes on the catalog result.

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

The main functions are:

| Function | Purpose |
| --- | --- |
| `list_datasets()`, `search_datasets()` | Search live City and regional ArcGIS items, with checked entries identified. Use `source = "checked"` offline. |
| `dataset_info()` | Inspect a checked or discovered layer; `refresh = TRUE` fetches the live schema. |
| `get_dataset()` | Retrieve a checked ID, discovered ID, or one-row discovery result. |
| `get_arcgis_layer()` | Retrieve a compatible public ArcGIS layer directly by URL. |
| `get_permits()`, `get_development_cases()`, `get_capital_projects()` | Shortcuts for three catalog entries. |
| `dataset_provenance()` | Read source, validation status, query, timing, row counts, and completeness. |

Source field names and text fields retain their spelling. ArcGIS epoch-millisecond
date fields become UTC `POSIXct` unless the source declares an unknown time zone.
In that case they remain raw milliseconds with a warning; UTC editor-tracking
creation and edit dates are still converted. Date-only fields become
`Date`; time-only and timestamp-offset fields remain strings.

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

## Source scope and reliability

The 20 checked City layers include active permit and development case views,
not complete historical ledgers. The `city-boundary` layer follows a shoreline
representation and is not a legal survey. The catalog also covers parks,
historic sites, police districts, transportation, zoning, and utility service
areas. These maps do not
by themselves establish legal boundaries, current road restrictions, service
eligibility, or operating status. The `water-service-area` extends beyond city
limits. The current `fire-stations` source uses unqualified field names such as
`NAME` and supports `order_by`; joined service-information fields from the old
source are unavailable. Check a checked entry's `scope_note` and `terms` with
`dataset_info(id)` before analysis. Its `verified` date records an endpoint
check, not the freshness of every feature. Discovered items may change, become
unavailable, or lack clear reuse terms; inspect their source metadata before
use. The package does not verify the reuse terms of discovered items. A live
discovery failure leaves `source = "checked"` available offline.

Retrieval compares the matching count and object-ID manifest with downloaded
batches. It raises an error for detected missing, duplicate, or unexpected
records. Live records can change during a request, so a successful result is
not a frozen snapshot of every attribute. Very large queries may need a
narrower `where` clause: the client rejects more than one million matches
because it requires a complete object-ID manifest.

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

## More information

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

The design was inspired by [rOpenSci's `nycOpenData`](https://github.com/ropensci/nycOpenData);
the ArcGIS client was implemented independently.

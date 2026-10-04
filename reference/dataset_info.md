# Inspect a checked or discovered dataset and its source

A checked package ID reads the offline registry. A one-row discovery
result carries its portal metadata; a stable
`arcgis:<item-id>:<layer-id>` identifier looks up the current portal
item. Set `refresh = TRUE` to retrieve the current layer schema,
aliases, field types, CRS, query capabilities, and upstream editing
metadata when available. Registry verification dates are endpoint
checks, not dates when government records were updated.

## Usage

``` r
dataset_info(
  id,
  jurisdiction = "tampa",
  refresh = FALSE,
  timeout = 30,
  total_timeout = 60
)
```

## Arguments

- id:

  Checked package ID, one-row discovery descriptor, or stable ArcGIS
  item/layer identifier.

- jurisdiction:

  Checked-registry jurisdiction. Omit to resolve a unique checked
  package ID across all cities. For a discovery result or stable ArcGIS
  ID, omission uses its source jurisdiction.

- refresh:

  Whether to request live layer metadata.

- timeout:

  Per-request timeout in seconds.

- total_timeout:

  Maximum elapsed seconds for inspection, including metadata requests
  and retries. Defaults to 60; `Inf` disables this limit.

## Value

A named list of dataset metadata, including its ID, title, publisher,
jurisdiction, source URL, and service URL. With `refresh = TRUE`, the
list also contains `fields` (a tibble of source field names, types, and
aliases), `metadata` (raw ArcGIS layer metadata), and `inspected_at`
(UTC).

## Examples

``` r
info <- dataset_info("construction-permits")
info[c("id", "title", "publisher", "source_url")]
#> $id
#> [1] "construction-permits"
#> 
#> $title
#> [1] "Permits (active GIS view)"
#> 
#> $publisher
#> [1] "City of Tampa"
#> 
#> $source_url
#> [1] "https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer/0"
#> 
if (FALSE) { # \dontrun{
info <- dataset_info("construction-permits", refresh = TRUE)
info$fields
} # }
```

# Discover datasets from an ArcGIS portal

Searches public service items in an ArcGIS portal or enumerates layers
from a FeatureServer or MapServer service root or layer URL. A result
row can be passed to
[`tbod_get_dataset`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md).
Portal rows have `discovered` status; service URL rows have
`not_checked` status because no portal item identity is available.
Discovery does not guarantee that a layer will remain available.

## Usage

``` r
tbod_discover(
  portal, query = NULL, max_items = 25, timeout = 30,
  total_timeout = 90, org_id = NULL, publisher = NULL,
  jurisdiction = "unspecified"
)
```

## Arguments

- portal:

  Public HTTPS ArcGIS sharing REST root ending in `/sharing/rest`, or
  FeatureServer/MapServer service or layer URL.

- query:

  Optional portal search text. For a service URL, a literal
  case-insensitive layer-name filter.

- max_items:

  Maximum service items to scan in a portal or layers to inspect in a
  service; `Inf` scans all available entries. A capped portal search can
  omit matching layers from older items.

- timeout:

  Per-request timeout in seconds.

- total_timeout:

  Overall operation budget in seconds; `Inf` disables it.

- org_id:

  Optional ArcGIS organization ID used to restrict a portal search. This
  argument does not apply to service URLs.

- publisher:

  Optional publisher label for returned descriptors. If NULL, a portal
  organization name is used when available; service URLs use an
  unknown-publisher label.

- jurisdiction:

  Jurisdiction label for returned descriptors; defaults to
  `"unspecified"`.

## Value

A tibble of discovered ArcGIS layers. Discovery issue, scan count,
truncation, and completeness attributes describe the scan. Check
`attr(rows, "discovery_complete")` before assuming a complete search.

## Examples

``` r
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  tbod_discover("https://www.arcgis.com/sharing/rest", query = "parks", max_items = 5)
}
```

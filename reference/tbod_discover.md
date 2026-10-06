# Discover datasets from an ArcGIS portal

Searches a public ArcGIS portal or lists layers from a FeatureServer or
MapServer service or layer URL. Pass a result row to
[`tbod_get_dataset()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_get_dataset.md)
to retrieve it. Portal rows have `discovered` status; service URL rows
have `not_checked` status because they have no portal item identity.
Publisher services can change after discovery.

## Usage

``` r
tbod_discover(
  portal,
  query = NULL,
  max_items = 25,
  timeout = 30,
  total_timeout = 90,
  org_id = NULL,
  publisher = NULL,
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
  service. Defaults to 25; `Inf` scans all available entries. A capped
  portal search can omit matching layers from older items.

- timeout:

  Per-request timeout in seconds.

- total_timeout:

  Maximum elapsed seconds for the operation. Defaults to 90; `Inf`
  disables this limit.

- org_id:

  Optional ArcGIS organization ID to restrict a portal search. This
  argument does not apply to service URLs.

- publisher:

  Publisher label to attach to discovery rows. If NULL, a portal
  organization name is used when available; service URLs use an
  unknown-publisher label.

- jurisdiction:

  Jurisdiction label to attach to discovery rows. Defaults to
  `"unspecified"` for a custom portal.

## Value

A tibble of discovered ArcGIS layers. Discovery issues, scan counts,
truncation, and completeness are attached as attributes; check
`attr(rows, "discovery_complete")` before assuming a complete search.

## Details

A portal search scans at most `max_items` service items, then expands
queryable layers. For a FeatureServer or MapServer URL, discovery
enumerates the service's layers; `query` filters their names. The result
reports scan completeness and item errors as attributes.

## Examples

``` r
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  rows <- tbod_discover("https://www.arcgis.com/sharing/rest",
                        query = "parks", max_items = 5)
}
```

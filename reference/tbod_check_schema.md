# Check a current ArcGIS schema against an expected schema

The checked catalog supplies an expected snapshot automatically. For a
discovered descriptor or direct ArcGIS URL, pass `expected` explicitly
to compare it with a previously saved
[`tbod_schema()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_schema.md)
result. Otherwise the result is `untracked` and contains the current
schema. Added fields and changed aliases are compatible drift. Removed
or renamed fields, changed field types, object-ID fields, geometry or
CRS, and moved or missing endpoints are incompatible drift. This
inspection function returns a report, including missing endpoints;
checked retrieval warns for compatible drift and errors before querying
for incompatible drift.

## Usage

``` r
tbod_check_schema(
  id,
  jurisdiction = NULL,
  expected = NULL,
  timeout = 30,
  total_timeout = 60,
  portal = NULL
)
```

## Arguments

- id:

  Checked dataset ID, discovered descriptor, stable ArcGIS item ID, or
  public HTTPS ArcGIS layer URL.

- jurisdiction:

  Optional checked-catalog jurisdiction. `NULL` resolves a unique
  bundled ID and preserves a discovery row's source. Direct URLs do not
  accept a jurisdiction override.

- expected:

  Optional schema list with `endpoint`, `fields`, `geometry_type`,
  `spatial_reference`, and `object_id_field`. A saved
  [`tbod_schema`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_schema.md)
  result can be passed directly.

- timeout:

  Per-request timeout in seconds.

- total_timeout:

  Overall operation budget in seconds; `Inf` disables it.

- portal:

  Optional public ArcGIS sharing REST portal URL for a stable
  `arcgis:<item-id>:<layer-id>` identifier. It does not apply to other
  IDs.

## Value

A `tbod_schema_check` list with `status` (`unchanged`, `compatible`,
`incompatible`, or `untracked`), a tibble of issues with `category`,
`severity`, `field`, `expected`, and `actual` columns, and expected and
current schemas. An incompatible missing endpoint has no current schema.

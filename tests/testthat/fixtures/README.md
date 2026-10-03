The City of Tampa schema fixtures contain trimmed ArcGIS layer metadata for all
20 checked Tampa layers, verified on the `verified` date in each entry. Each
`metadata_url` identifies the source layer, and `original_file` names its
research snapshot. They retain source field names, types, aliases, query
capabilities, and spatial/date metadata, but no source feature records. Tests
use synthetic attribute values and geometry.

The fixtures preserve field capitalization and qualified names, geometry
fields, MapServer layers' omitted `objectIdField`, fire stations' unqualified
object ID and supported ordering/offset pagination, capital projects' WKID 103023 / latest WKID
6443, and the water service area's native WKID 102659 / latest WKID 2237. To
update a fixture, check its recorded endpoint and compare the current schema
before changing the snapshot.

## Other Tampa Bay city schemas

`tampa-bay-city-layer-schemas.json` contains selected source fields and query,
spatial, and date metadata verified on October 2, 2026:

- [St. Petersburg recreation centers](https://egis.stpete.org/arcgis/rest/services/ServicesDOTS/GoogleGen/MapServer/4):
  point geometry, integer ZIP codes, and creation dates.
- [Clearwater park buffers](https://gis.myclearwater.com/arcgis/rest/services/ArcGISMapServices/Clearwater_Park_Buffers/MapServer/0):
  polygon buffers, acreage, integer buffer distances, and creation dates. These
  polygons describe buffers around parks rather than exact park footprints.

Both MapServer layers omit `objectIdField` and `objectIdFieldName` in metadata,
declare an `OBJECTID` field of type `esriFieldTypeOID`, and use native
EPSG:2882. The fixture preserves those differences instead of substituting the
Tampa permit schema. All offline attribute values and coordinates are synthetic;
no source feature records are bundled. The live tests share these URLs and
selected fields but assert neither fixed counts nor fixed record IDs. These
exercise the direct-URL path and retain `not_checked` provenance, including
when the endpoint also appears as a separate checked registry entry.

## Checked regional schemas

`regional-layer-schemas.json` contains trimmed metadata for three checked
St. Petersburg layers (parks, city boundaries, and streets) and three checked
Clearwater layers (park buffers, zoning, and libraries). It preserves their
actual object-ID fields, source field types, geometry, query limits, and CRS
differences. In particular, Clearwater's zoning and library MapServer outputs
use EPSG:3857 even though their underlying source references differ. All test
features remain synthetic; raw research snapshots and retrieved records are
excluded from the package source.

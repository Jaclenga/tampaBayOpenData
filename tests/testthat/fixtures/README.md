These fixtures contain trimmed City of Tampa ArcGIS layer metadata for all 20
bundled datasets, verified on the `verified` date in each entry. Each
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

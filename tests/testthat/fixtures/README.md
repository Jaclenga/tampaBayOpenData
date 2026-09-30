These offline fixtures contain trimmed City of Tampa ArcGIS layer metadata
verified on 2026-09-29. The `metadata_url` for each entry records the exact
source, and `original_file` identifies the research snapshot used to produce
the fixture. Only schema names, types, aliases, query capabilities, and
spatial/date reference metadata are retained; no source feature records,
addresses, contact names, phone numbers, or email addresses are included.

The corresponding tests create entirely synthetic attribute values and
geometry. Metadata differences are preserved, including the omitted
MapServer `objectIdField`, source field capitalization, geometry attributes,
and capital projects' native WKID 103023 / latest WKID 6443.

Fixtures are deliberately offline. To update them, verify the exact recorded
endpoints and compare the schema changes before replacing the snapshot.

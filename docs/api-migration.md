# API name migration

The public API uses the `tbod_*` prefix. Earlier development versions exported
the unprefixed names below. Replace them in scripts and notebooks; the old
exports have been removed. Dataset IDs and existing arguments can stay the same.

| Earlier name | Use now |
| --- | --- |
| `list_portals()` | `tbod_list_portals()` |
| `list_datasets()` | `tbod_list_datasets()` |
| `search_datasets()` | `tbod_search_datasets()` |
| `dataset_info()` | `tbod_dataset_info()` |
| `dataset_provenance()` | `tbod_provenance()` |
| `get_dataset()` | `tbod_get_dataset()` |
| `get_arcgis_layer()` | `tbod_get_arcgis_layer()` |
| `download_dataset()` | `tbod_download_dataset()` |
| `download_arcgis_layer()` | `tbod_download_arcgis_layer()` |
| `get_permits()` | `tbod_get_permits()` |
| `get_capital_projects()` | `tbod_get_capital_projects()` |
| `get_development_cases()` | `tbod_get_development_cases()` |

The package also provides `tbod_discover()`, `tbod_schema()`, and
`tbod_check_schema()` for custom ArcGIS discovery and schema inspection.

This change was made before the first CRAN release. On 2026-10-06,
the repository had no release tags or visible GitHub dependents. Earlier
public development documentation did show the unprefixed names, so this table
records every replacement for anyone who installed from GitHub.

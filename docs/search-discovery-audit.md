# Dataset search audit

## Baseline before the search changes

On October 20, 2026, the existing checked search matcher was evaluated against
the bundled catalog before implementation, without network requests. These
counts correspond to `tbod_search_datasets(query, source = "checked")` with
default filters.

| Query | Checked rows before change |
| --- | ---: |
| `permits` | 1 |
| `zoning` | 4 |
| `water quality` | 1 |
| `parcels` | 0 |
| `transportation` | 11 |
| `permti` | 0 |
| empty string | 52 |

The checked catalog is a curated selection, so zero checked rows for
`parcels` did not establish that no publisher offers parcel data. The old
checked search looked for all literal, case-insensitive query words in IDs,
titles, descriptions, categories, and tags. It did not search publisher names,
rank matches, or recover a misspelling such as `permti`. It had no result-row
limit separate from `max_items`, which bounds a live service-item scan.

## Current search contract

Checked search also matches publisher names. Exact title and ID matches rank
before partial title and ID matches; metadata matches follow. A spelling
fallback runs only if the checked catalog has no literal match. Live discovery
still uses each ArcGIS portal's index; local ranking keeps its indexed hits,
including hits whose matching index field is absent from the returned row.
The `limit` argument applies to the final filtered and ranked rows, while
`max_items` continues to bound the service items scanned per portal. Matching
live and checked layers appear once with checked status.

For the public interface and examples, see the [discovery article](../vignettes/discovery.Rmd)
and the `tbod_search_datasets()` reference. A complete live scan is complete
only with respect to the selected public portal indexes. Index lag, private
items, unsupported services, nonqueryable layers, scan caps, item failures,
and timeouts can keep relevant publisher data out of results. Inspect the
`discovery_complete`, `discovery_issues`, `discovery_failed_portals`,
`discovery_scanned_items`, and `discovery_truncated_portals` attributes when
interpreting live results.

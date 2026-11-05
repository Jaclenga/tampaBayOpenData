# Check the current health of checked catalog layers

Checks current public ArcGIS endpoints and saved schemas for selected
entries in the bundled checked catalog. It contacts publisher services
and returns a report without changing the catalog or saving files. A
healthy result is a point-in-time metadata check, not a measure of
record freshness.

## Usage

``` r
tbod_check_catalog(
  jurisdiction = "all",
  ids = NULL,
  timeout = 10,
  total_timeout = 1800,
  pause = 0.25,
  probe_query = FALSE
)
```

## Arguments

- jurisdiction:

  One checked-catalog jurisdiction code or `"all"`.

- ids:

  Optional nonempty vector of unique checked dataset IDs within
  `jurisdiction`; `NULL` checks all selected entries.

- timeout:

  Per-HTTP-attempt timeout in seconds.

- total_timeout:

  Maximum elapsed seconds for the complete check, including requests,
  retries, and pauses. Defaults to 1,800; `Inf` disables the overall
  deadline. Entries not reached are reported as `unknown`.

- pause:

  Delay from 0 to 30 seconds between entries to limit request rate;
  defaults to 0.25. With `probe_query = TRUE`, also pauses between layer
  metadata and the count probe.

- probe_query:

  Run a zero-match count query after usable metadata to verify Query
  capability. Defaults to `FALSE` for the existing metadata-only
  behavior. Query probes do not retrieve features.

## Value

A tibble with one row per selected entry and `publisher`,
`jurisdiction`, `dataset_id`, `endpoint`, `checked_at` (UTC POSIXct),
`status` (`healthy`, `unavailable`, `schema_changed`, `unsupported`, or
`unknown`), `failure_type`, `http_status`, `service_status` and
`layer_status` (`available`, `unavailable`, or `unknown`),
`schema_status` (`unchanged`, `compatible`, `incompatible`, or
`unavailable`), `schema_issues` (a list of issue tibbles), and
`details`. `health_state` summarizes status as `healthy`, `degraded`,
`unavailable`, or `unknown`. `response_time_ms` is elapsed request time
including retries and a missing-layer service-root probe, excluding
deliberate pauses; it is missing if no request was made. `query_status`
is `not_checked`, `verified`, `failed`, or `unknown`;
`query_failure_type`, `query_http_status`, and `query_details` explain a
failed or uncertain probe. `http_status` is missing when no metadata
HTTP response was received.

## Details

Each entry starts one layer-metadata request. The client probes the
service root only after a missing-layer response (HTTP or ArcGIS
404/410, or an explicit layer-not-found error) to distinguish a missing
layer from a missing service. Transient failures remain `unknown` after
bounded retries; entries not reached before `total_timeout` are also
`unknown`. The default retry limit is three additional attempts per
retryable failure sequence. Set
`options(tampaBayOpenData.max_retries = 3L)` to change it (whole number
from 0 to 10).

`healthy` means the layer metadata is valid, Query is advertised, and
the schema matches the saved snapshot. `schema_changed` includes both
compatible and incompatible drift; inspect `schema_status` and
`schema_issues`. Confirmed schema drift remains `schema_changed` if
Query capability is unreported. With no saved baseline, `schema_status`
is `unavailable` and `status` is `unknown`. A missing object-ID field is
reported as schema drift when a baseline exists; the details also
identify unsupported record retrieval. `unsupported` includes layers
that cannot be queried and access failures. By default the check does
not retrieve features or run count and object-ID queries. A layer can
advertise Query yet fail those operations during retrieval. Set
`probe_query = TRUE` to run a zero-match count request after valid layer
metadata; it reads no features and records whether the actual Query
operation succeeds. A confirmed query failure is degraded, while a
transient probe failure is unknown unless independently confirmed schema
drift already makes the result degraded. The result cannot guarantee
future service availability.

## Examples

``` r
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  report <- tbod_check_catalog(ids = "construction-permits")
  report[, c("dataset_id", "status", "schema_status", "details")]
}
```

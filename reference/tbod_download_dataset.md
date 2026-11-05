# Download a dataset into resumable chunks

Accepts a bundled ID, discovery row, stable ArcGIS ID, or direct ArcGIS
layer URL. A custom Enterprise portal can be provided with stable IDs.
Layers in the checked catalog are compared with expected schemas before
downloading; compatible drift warns and incompatible drift stops the
download.

## Usage

``` r
tbod_download_dataset(
  id,
  path,
  jurisdiction = NULL,
  where = "1=1",
  fields = NULL,
  spatial = FALSE,
  out_sr = NULL,
  page_size = 1000,
  query = list(),
  timeout = 30,
  total_timeout = Inf,
  resume = TRUE,
  portal = NULL
)
```

## Arguments

- id:

  Bundled ID, one-row discovery result, stable ArcGIS ID, or direct
  public HTTPS ArcGIS layer URL.

- path:

  Local directory for the manifest, checkpoints, and chunk files.

- jurisdiction:

  Optional bundled catalog jurisdiction. `NULL` resolves a unique
  bundled ID and preserves a discovery result's jurisdiction. Direct
  URLs do not accept a jurisdiction override.

- where:

  ArcGIS SQL WHERE clause using source field names; defaults to `"1=1"`.
  Inspect names with `tbod_dataset_info(id, refresh = TRUE)`.

- fields:

  Character vector of exact source field names, or `NULL` or `"*"` for
  all nongeometry attributes. Object IDs remain in chunk provenance even
  if the column was not selected.

- spatial:

  Write `sf` chunks; requires the optional sf package and a layer with
  supported geometry and a known CRS.

- out_sr:

  Optional positive ArcGIS/EPSG output reference for server projection;
  requires `spatial = TRUE`. `NULL` keeps the native CRS.

- page_size:

  Positive integer batch size capped at 1,000 and the service maximum.
  The effective size must stay fixed when resuming.

- query:

  Named list of advanced ArcGIS filters such as `geometry`,
  `spatialRel`, and `time`. Response format, field selection,
  aggregation, geometry simplification, and pagination parameters are
  protected.

- timeout:

  Per-request timeout in seconds. Transient failures may be retried
  according to `options(tampaBayOpenData.max_retries = 3L)`.

- total_timeout:

  Overall operation deadline in seconds. The default `Inf` allows a long
  download; completed chunks remain for a later resume if a finite
  deadline expires.

- resume:

  Reuse a matching saved download and skip validated chunks.

- portal:

  Optional ArcGIS sharing REST portal URL when `id` is a stable
  `arcgis:<item-id>:<layer-id>` identifier.

## Value

A named list with `path`, ordered chunk `files`, `matched_rows`,
`returned_rows`, `complete`, and summary `source` provenance. Each RDS
chunk has its own provenance; `tbod_provenance(chunk)$download` includes
its chunk number and object IDs. With no matches, `files` is empty and
summary integrity is `count-only`.

## Details

The client retrieves the matching object-ID manifest when records exist,
then writes bounded RDS chunks to a caller-selected directory. Each
chunk is a tibble or `sf` object with its own provenance; read files one
at a time with [`readRDS()`](https://rdrr.io/r/base/readRDS.html).
Feature pages are not accumulated in memory, but the manifest itself is
subject to the one-million-record limit.

A saved manifest fixes the endpoint, query, fields, schema, CRS
metadata, matching IDs, and batch size. With `resume = TRUE`, current
metadata and IDs are rechecked before saved chunks are used. Changed
options, schema, CRS, or membership cause an error. Completed chunks
must match their checkpoint checksums, expected IDs, columns, and
provenance. Temporary files from interrupted writes are ignored. After
all chunks have been validated, the client atomically writes
`complete.rds` in `path`. No marker is written before a new download
finishes or after an interrupted call. After confirming the saved
manifest matches, a resumed call clears the marker before revalidating
saved chunks, then writes it again only after successful completion.

The directory must be empty on the first call. Unrelated files and
existing downloads with `resume = FALSE` are rejected. An exclusive lock
prevents concurrent writers. If a terminated process leaves `.lock`,
confirm no writer remains, remove that empty directory, and resume.
Record attributes can change between chunks or resumed calls even when
IDs and schema remain stable; this is not a frozen snapshot. The
returned summary records whether the complete matching manifest was
downloaded. Transient connection failures and timeouts, HTTP 429, 500,
502, 503, and 504 responses, ArcGIS error objects with those codes
inside HTTP 200 responses, and a generic transient ArcGIS query error
are retried. Set `options(tampaBayOpenData.max_retries = 3L)` to control
additional retries per failure sequence (integer 0 through 10). HTTP
failures and ArcGIS errors in successful HTTP responses use separate
bounded sequences; mixed failures can make more than four HTTP attempts
overall. A valid `Retry-After` delay or HTTP date is honored if at most
30 seconds; a longer delay stops retrying rather than causing an early
retry. Otherwise retries use exponential backoff with jitter. Permanent
HTTP and ArcGIS errors fail without retrying. An interrupted call does
not return a complete download summary; resume with the same `path` to
validate and continue saved chunks.

## Examples

``` r
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  saved <- tbod_download_dataset("construction-permits",
    tempfile("permit-download-"), where = "OBJECTID <= 10", page_size = 5)
  if (length(saved$files)) tbod_provenance(readRDS(saved$files[[1L]]))
}
```

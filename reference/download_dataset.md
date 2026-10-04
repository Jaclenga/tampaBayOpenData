# Download an ArcGIS dataset into resumable local chunks

Retrieves the full matching object-ID manifest, then writes bounded
chunks of typed data to a caller-selected directory. Each chunk is an
RDS tibble or `sf` object with its own provenance; read one file at a
time with [`readRDS()`](https://rdrr.io/r/base/readRDS.html).
Downloading does not accumulate all feature pages in memory. The
manifest itself remains in memory and is subject to the
one-million-record limit.

## Usage

``` r
download_dataset(
  id,
  path,
  jurisdiction = "tampa",
  where = "1=1",
  fields = NULL,
  spatial = FALSE,
  out_sr = NULL,
  page_size = 1000,
  query = list(),
  timeout = 30,
  total_timeout = Inf,
  resume = TRUE
)
```

## Arguments

- id:

  Checked package dataset ID, one-row discovered dataset descriptor, or
  stable `arcgis:<32-hex-item-id>:<nonnegative-layer-id>` identifier.

- path:

  Local directory for the manifest, checkpoints, and chunk files.

- jurisdiction:

  Checked-registry jurisdiction: `"tampa"`, `"stpete"`, `"clearwater"`,
  or `"all"`. Omit to resolve a unique checked ID across the registry or
  to use a discovered result's or stable ArcGIS ID's jurisdiction.

- where:

  ArcGIS SQL WHERE clause, using actual source field names. Defaults to
  `"1=1"` (all records). See
  [`dataset_info()`](https://jaclenga.github.io/tampaBayOpenData/reference/dataset_info.md)
  with `refresh = TRUE`.

- fields:

  Character vector of exact source field names, or NULL/`"*"` for all
  nongeometry attributes. An object-ID field is requested internally for
  integrity checks and removed when it was not selected.

- spatial:

  Return an `sf` object. Requires the optional sf package and a layer
  with supported geometry and a reliably determined CRS.

- out_sr:

  Optional positive ArcGIS/EPSG spatial reference ID for server
  projection, such as 4326. Used only with `spatial = TRUE`; NULL keeps
  the native CRS. A projection response must confirm its spatial
  reference.

- page_size:

  Positive integer batch size, capped at 1,000 and the service maximum.
  The effective batch size must remain unchanged when resuming.

- query:

  Named list of advanced ArcGIS filter parameters: `geometry`,
  `geometryType`, `inSR`, `spatialRel`, `relationParam`, `time`,
  `distance`, `units`, `gdbVersion`, `historicMoment`, `sqlFormat`,
  `datumTransformation`. Values can be scalars or JSON-style lists.
  Response format, field selection, aggregation, geometry
  simplification, and pagination parameters are protected.

- timeout:

  Timeout in seconds for each HTTP attempt. Transient transport and HTTP
  failures may receive three attempts; one generic ArcGIS query error
  may receive four.

- total_timeout:

  Overall operation deadline in seconds. The default `Inf` permits a
  long download; a finite deadline leaves completed chunks available for
  a later resume.

- resume:

  Reuse a matching saved download and skip validated chunks.

## Value

A named list with `path`, ordered chunk `files`, `matched_rows`,
`returned_rows`, `complete`, and summary `source` provenance. A query
with no matches returns no chunk files. Individual chunks retain object
IDs in `dataset_provenance(chunk)$download$object_ids`, including when
the ID column was not selected.

## Details

A saved manifest fixes the endpoint, query, fields, schema, CRS
metadata, matching IDs, and batch size. With `resume = TRUE`, the client
rechecks the current metadata and full manifest before using any saved
chunk. Changed options, schema, CRS, or record membership cause an
error. Completed chunks must match their checkpoint checksum, expected
IDs, columns, and provenance. Temporary files from interrupted writes
are ignored. The directory must be empty on the first call; unrelated
files and existing downloads with `resume = FALSE` are rejected. An
exclusive directory lock prevents concurrent writers. A terminated R
process can leave a `.lock` directory; after confirming that no process
is still using this download, remove that empty lock directory before
resuming. Locks are never removed automatically on a new call.

Record attributes can change between chunks and between resumed calls
even when the IDs and schema remain unchanged. This is not a frozen
snapshot. Chunk provenance describes that chunk; the returned summary
reports whether the full matching manifest has been downloaded.

## Examples

``` r
dataset_info("construction-permits")$object_id_field
#> [1] "OBJECTID"
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  saved <- download_dataset("construction-permits", tempfile("permit-download-"),
    where = "OBJECTID <= 10", page_size = 5)
  if (length(saved$files)) {
    first <- readRDS(saved$files[[1]])
    dataset_provenance(first)$download$chunk
  }
}
```

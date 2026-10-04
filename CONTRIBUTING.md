# Contributing

For bugs, include the package version, dataset ID, query, and exact error. Keep
changes focused on discovery, retrieval, parsing, provenance, or reliability.

## Develop and check

From the package root:

```r
install.packages(c("devtools", "roxygen2", "testthat", "sf", "knitr", "rmarkdown"))
devtools::load_all()
devtools::test()
roxygen2::roxygenise()
devtools::check(args = "--no-manual")
```

`sf` is optional for spatial tests; rendering the vignette also needs Pandoc.
Commit generated `man/` and `NAMESPACE` changes when updating roxygen comments.
Add tests for changed behavior. Ordinary tests and package checks use mocked
responses and block live HTTP. Keep examples and vignettes offline; set network
retrieval chunks to `eval = FALSE`. See the [test guide](https://github.com/Jaclenga/tampaBayOpenData/blob/main/tests/README.md) for
focused and opt-in live checks.
The live workflow schedules bounded city, regional, and county smoke checks
twice weekly, including county descriptor, stable-ID, and projected geometry
retrieval with at most two rows per call. Manual runs keep the complete
integration suite. When adding a monitored source, use a small
row limit, current IDs rather than fixed counts, a finite portal item limit,
and explicit timeouts. A source schema or availability failure should remain
visible in the opted-in run.

## Registry and retrieval changes

Before editing `inst/extdata/datasets.json`, verify the official publisher source
page, layer metadata, and a small query. Record source and service URLs, layer
ID, publisher, stable ID, geometry, useful date fields, data terms, and
verification date. Add a fixture or test when a new schema exercises different
behavior. The checked registry has 20 Tampa layers and three each from
St. Petersburg, Clearwater, Hillsborough County, Pinellas County, and the
Tampa Bay Regional Planning Council. Live discovery supports all six public
ArcGIS organizations. A configured portal does not itself validate its layers.
`get_arcgis_layer()` accepts compatible direct
public layer URLs. Convenience functions should delegate to `get_dataset()`.

### Add a discovery publisher

Discovery publishers are configured in `inst/extdata/portals.json`.
`list_portals()` exposes this registry without a network request. To add one:

1. Follow an official publisher page to its ArcGIS portal. Query that portal's
   `sharing/rest/portals/self?f=pjson` metadata and verify its organization ID.
   Check a public service item, layer metadata, and a small feature query.
2. Add one JSON entry with `id`, `root`, `org_id`, `publisher`, `jurisdiction`,
   `website`, `verified`, `metadata_url`, and `evidence_url`. Use a unique portal
   ID as a lowercase slug, an HTTPS sharing REST root, an ISO verification
   date, and official URLs that support the publisher and organization identity.
   Preserve the existing entry format; retrieval code does not need a
   publisher-specific branch.
   Store `metadata_url` as the root's `/portals/self` or `/portals/<org_id>` URL
   without `?f=pjson`; registry URLs omit query parameters.
3. Check `list_portals()` and run the portal registry and discovery tests. Then
   opt into a bounded live search for the new ID, with `max_items = 1`,
   `timeout = 15`, and `total_timeout = 45`. Inspect discovery issues and source
   identity as well as returned rows.
4. Add curated layer entries separately when their schemas, scope, and terms
   have been checked. Registering a portal does not mark its layers `checked`.

Scheduled monitoring reads `list_portals()`, so a new configured publisher is
included automatically. Ordinary tests continue to block live network access.

```r
list_portals()
testthat::test_local(filter = "portal-registry|live-discovery|regional-discovery",
                     stop_on_failure = TRUE)
```

### Preserve retrieval guarantees

Preserve source field names and text values. Parse types from ArcGIS metadata,
handle nulls and empty results, and report uncertain date or CRS semantics.
Epoch-millisecond date fields become UTC `POSIXct`; dates declared to have an
unknown time zone remain numeric with a warning, apart from metadata-identified
UTC editor-tracking creation and edit dates. Date-only fields become `Date`;
time-only and timestamp-offset fields remain strings. Require `Query` when a
layer supplies a capabilities list, and validate actual query responses.
Preserve full-manifest integrity for complete retrievals and explicit
`integrity = "full"`; eligible finite previews may verify a returned-ID subset
manifest. Keep incomplete previews distinct from complete results. Honor
overall operation deadlines as well as per-attempt timeouts.
Resumable downloads must revalidate current schemas and full manifests, check
saved chunk content and provenance against immutable checkpoints, and publish
checksums before atomic chunk renames. Keep each feature batch bounded, preserve
completed chunks after errors, and reject changed options or record membership.
Directory locks must reject concurrent writers and preserve stale locks for
explicit recovery after the earlier process is confirmed stopped.
Route HTTP through the shared client and retain pagination completeness checks
and result provenance. Use small synthetic or selected public fixtures, not
bulk downloads. Document any intentional value normalization.

## Attribution

The project credits `nycOpenData` as inspiration. Identify the origin of any
adapted third-party code or documentation and retain required notices. Data
terms and the package's software license are separate.

# v0.1.0 validation

## 2026-09-30 follow-up

The client now retains UTC editor tracking dates when other layer dates have
unknown time zones, requires the exact `attributes` response key, retries HTTP
500/502/504 alongside 429/503, and validates registry array types and layer-ID
range before catalog conversion. The root source archive was rebuilt from these
changes.

- The deterministic offline suite passes **1,037 assertions**, with zero
  failures or test warnings. The two opt-in live tests are skipped.
- `R CMD build` succeeds, including the vignette.
- `R CMD check --no-manual` on the rebuilt archive reports **Status: OK**.

## Original 2026-09-29 validation

Validated on 2026-09-29 using R 4.5.1 on Windows 11. The source archive was
built as `tampaBayOpenData_0.1.0.tar.gz` and refreshed on 2026-09-30.

- `R CMD build .` succeeds, including the offline introductory HTML vignette.
- `R CMD check --no-manual tampaBayOpenData_0.1.0.tar.gz` reports **Status: OK**:
  zero errors, warnings, and notes. PDF manual generation was not requested.
- The deterministic testthat suite passes **967 assertions**, with no failures
  or test warnings. The two live integration cases are skipped during ordinary
  checks and were separately run successfully with `TAMPA_OPEN_DATA_LIVE=true`.
  That live run passed 28 assertions after the bug fixes.
- Deterministic R code coverage measured with covr is **98.69%**. HTTP tests use
  real httr2 requests and responses with mocked dispatch, covering request
  encoding, timeout/retry configuration, response decoding, and source-aware
  failures. Ordinary tests block accidental live dispatch.
- The minimum httr2 1.2.3 was separately installed from its official source tag
  into an isolated library. All 64 HTTP assertions pass with `LC_CTYPE=C`;
  prepared POST bytes retain Unicode filters and full geometry precision.
- Representative fixtures cover the verified schemas and routing of all eight
  datasets using synthetic feature values. Metadata regressions verify that
  malformed timezone and capability declarations fail before feature queries.
- The internal refactor preserved the public API and the original 675 assertions while
  separating pagination, type parsing, and geometry decoding. The largest
  function shrank from 124 to 67 source lines; `arcgis_fetch()` from 94 to 50,
  and `arcgis_parse()` from 69 to 11. Pagination no longer uses `<<-` to mutate
  enclosing state. Before the subsequent bug fixes, a separate comparison of
  1,188 parser cases found identical outputs, warnings, and error messages/classes.
- The [bug scan](bug-scan.md) added 216 regression assertions and corrected
  numeric rounding, polygon closure, response-integrity, metadata, CRS, and
  dependency-version issues. All regressions run offline.
- The [security audit](security-audit.md) adds 76 assertions and corrects literal
  JSON/WKT handling, redirects, retry waits, and recursive validation. It also
  hardens response-size checks and pins CI actions. The isolated httr2 1.2.3
  run passes all 140 HTTP/security assertions. Native dependency risks remain
  documented separately from the package's passing validation.
- Full spatial retrieval through the R client succeeds for all eight registered
  sources, with each result checked against its matching count and ID manifest.
- Filtering, selected fields, ordered offset pagination, and projected point,
  line, and polygon retrieval were also checked against the live City services.
- roxygen2 help, namespace, vignette rebuild, and source whitespace checks pass.

Observed live results are verification evidence, not fixed counts or guarantees
of future service availability:

| Dataset | Retrieved features | Native EPSG | Observed geometry |
| --- | ---: | ---: | --- |
| `construction-permits` | 2,594 | 3857 | POINT |
| `development-cases` | 287 | 3857 | POINT |
| `capital-projects` | 193 | 6443 | POINT |
| `city-boundary` | 1 | 3857 | MULTIPOLYGON |
| `neighborhoods` | 160 | 3857 | MULTIPOLYGON |
| `council-districts` | 4 | 3857 | MULTIPOLYGON |
| `riverwalk` | 21 | 3857 | LINESTRING |
| `parks` | 208 | 3857 | MULTIPOLYGON |

No bulk government datasets are stored in the package. Native/projected capital
project coordinates also agree with sf's transformation within the live test's
tolerance. The archive contains built vignette documentation and all tests;
workspace libraries, downloaded research material, and check output are excluded.

CI is configured for Linux release/devel/oldrel, Windows release, and macOS
release, plus a manually triggered live workflow. Remote CI has not been run
from this workspace; local validation does not claim results on those platforms.

Local check logs, coverage objects, test summaries, observed counts, and the
archive SHA-256 checksum are under the ignored `.check/` and `.artifacts/`
directories. Reproduction commands, coverage details, and opt-in live
instructions are in the [test suite guide](../tests/README.md) and
[CONTRIBUTING.md](../CONTRIBUTING.md).

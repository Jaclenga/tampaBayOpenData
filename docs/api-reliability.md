# API reliability assessment and validation

Assessment date: October 27, 2026.

## Existing protections retained

All ArcGIS metadata, discovery, count, ID, and feature queries use
`arcgis_request()` and the centralized `arcgis_http()` transport. Query POSTs
are read-only; the package does not submit edits. No public API or dependency
change was needed.

| Requirement | Implementation and regression coverage |
| --- | --- |
| Transient HTTP and transport recovery | `R/arcgis.R`; `test-http-integrity.R`, `test-reliability.R`, `test-resource-budgets.R` |
| Rate limits, numeric and date Retry-After, bounded waits | `R/arcgis.R`; `test-reliability.R` |
| Permanent failures, JSON and ArcGIS-body errors | `R/arcgis.R`; `test-http.R`, `test-bug-responses.R`, `test-request-cases.R` |
| Counts, ID manifests, schema and field validation | `R/arcgis.R`, `R/parsing.R`; `test-arcgis.R`, `test-metadata-validation.R` |
| Restricted record limits and absent offset support | `R/pagination.R`; `test-reliability.R`, `test-request-cases.R` |
| Short, empty, duplicate, repeated, or inconsistent pages | `R/pagination.R`; `test-reliability.R`, `test-http-integrity.R`, `test-review-regressions.R` |
| Validated, resumable downloads | `R/download.R`; `test-download.R`, `test-reliability.R` |
| Sanitized endpoint and failure details | `R/utils.R`, `R/arcgis.R`; `test-security.R`, `test-transport-messages.R` |

The existing implementation already covered these requirements; replacing it
would duplicate functionality and risk provenance and download behavior.

## Changes

`R/arcgis.R` now validates two session options through the internal helper
`.arcgis_transport_option()`:

- `tampaBayOpenData.connect_timeout`: defaults to 10 seconds, accepts
  0.001 through 3600. Every attempt caps the connection timeout by its transfer
  timeout and the remaining overall operation budget.
- `tampaBayOpenData.request_delay`: defaults to zero, accepts 0 through 3600
  seconds. Optional pacing precedes every actual HTTP attempt, including
  retries. It consumes the operation budget, with timeouts recomputed after
  waiting. Successful default requests incur no pacing delay.

Setting either option to `NULL` restores its default. Invalid settings fail
before HTTP dispatch without echoing their contents. The new tests in
`test-http.R` exercise actual request construction with mocked dispatch and
clock/sleep functions: connection caps, pacing plus retry backoff,
deadline exhaustion before dispatch, and malformed option values.

`vignettes/retrieval.Rmd` documents these options and the existing default
30-second attempt timeout, retry sequences, safe read-only POST recovery,
long Retry-After rejection, and sanitized diagnostics. `NEWS.md` records the
user-visible changes.

## Executed validation

Windows R 4.5.1, with `TAMPA_OPEN_DATA_LIVE=false`:

- Full `testthat::test_local(stop_on_failure = TRUE)`: 6,410 passing
  assertions, zero failures, zero test warnings, 18 opt-in live skips;
  duration 476.7 seconds.
- Focused HTTP regression suite: passed.
- Installed-package suite during `R CMD check`: 6,370 passing assertions,
  zero failures, zero test warnings, 23 skips (18 live tests and five
  development-tool tests excluded from the archive); duration 441 seconds.
- `R CMD build`: succeeded, including vignette generation.
- `R CMD check --as-cran tampaBayOpenData_0.1.0.tar.gz`: completed with exit
  code 0, zero errors, zero warnings, and one NOTE: `unable to verify current
  time`. The clock check was not disabled. Examples, vignette rebuilds, and
  PDF and HTML manuals passed. The check log is
  `.artifacts/reliability-run/tampaBayOpenData.Rcheck/00check.log`.
- `git diff --check`: passed.

The installed testthat binary emits a startup warning that it was built under
R 4.5.3; it is distinct from the zero test-warning count. PowerShell reports
native stderr as an error record, so test summaries and the R check log are
the evidence, rather than the shell wrapper status alone. Network-restricted
CRAN/Bioconductor index diagnostics are retained in the check console log.
Remote CRAN incoming checks were disabled; live publisher tests were not run.

The built source archive has SHA-256
`0629DCE8582A856249D59CC85F3EF0DC5A87D94B1209C504116D52D73EF3A7F6`.
Its changed R, test, vignette and NEWS sources match the working files, with
line endings normalized. Its namespace matches as well; DESCRIPTION has the
usual build-generated metadata. Logs and the archive are retained under
`.artifacts/reliability-run/`; the full development suite log is
`.artifacts/reliability-tests.log`.

## Limitations and follow-up

An ID manifest validates membership, not a transactionally frozen snapshot.
Attributes can change between pages. Counts and manifests must be supported;
the package errors when it cannot establish completeness. Explicit ordered
queries require ordering and offset capabilities. Automatic bounded previews
can instead use the existing ID fallback. Intentionally limited results retain
their incomplete provenance status.

Transport and HTTP-200 ArcGIS-body retries have separate finite sequences
(each defaults to three retries). Mixed failures can therefore require up to
16 HTTP attempts for one logical request with default settings, subject to the
overall deadline. Retry-After values above 30 seconds stop recovery rather
than trigger an early retry. Pacing is per attempt in one R process, not a
shared rate limiter across concurrent applications. In-memory ID manifests
and response-size limits still constrain very large services; use filters and
resumable downloads where practical.

No government endpoint is needed for deterministic tests. Real publisher
availability and native network-library behavior require separate opt-in live
validation; no such availability guarantee is inferred from mocks.

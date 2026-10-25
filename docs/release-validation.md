# Release validation: tampaBayOpenData 0.1.0

Initial validation: October 24, 2026, America/New_York. Cross-platform follow-up:
October 25. Machine-readable logs use UTC. The maintainer authorized commits
and pushes to `validation/cran-0.1.0-20261025` for this follow-up; `main` was
not changed. No CRAN submission or GitHub release was made.

## A. Release candidate

The baseline is commit `98d9780ef89d65e6211a030df10751c2a693e62f` on `main`;
the working tree was clean at inspection. The qualification candidate is
commit `0db68d969d0a8a23be55ae114d2900d9a8b4bcfc` on
`validation/cran-0.1.0-20261025`, with the package version unchanged at `0.1.0`.
Report-only follow-up commits are excluded from the package by `.Rbuildignore`.

- Archive: [tampaBayOpenData_0.1.0.tar.gz](../.artifacts/release-validation/qualified-source-run/tampaBayOpenData_0.1.0.tar.gz).
- SHA-256: `1326FAD31468F2C0229D16C3EE71B2ED2F4B2894F82953FD50EEE0CDD3BBC60E`.
- Size: 983,180 bytes.
- Build: Windows 11 x64 build 26300, R 4.5.1 (2025-06-13), locale `C`,
  `TZ=UTC`; all nine vignettes built with live retrieval disabled.
- [Staged Git source manifest](../.artifacts/release-validation/qualification-ci/qualified-source-manifest.sha256).
  SHA-256: `ACBA42BC2D803708B6E68B9B99B043B291B25BDF6212DE9D5E3C43FC64510609`.
- [Tarball member list](../.artifacts/release-validation/qualification-ci/qualified-tarball-files.txt)
  and [build log](../.artifacts/release-validation/qualified-source-run/build.log).

The source was exported from the committed Git tree before building. The
relocated RDS and PNG hashes match the original assets byte for byte.

The source was staged separately from the working repository using tracked
files plus the deliberately relocated tutorial assets. The archive contains
the required catalog, schemas, fixtures, nine vignettes, parks snapshot,
infrastructure snapshot, and fallback map. It excludes `.git`, credentials,
local libraries, check directories, development tools, this report, and
temporary diagnostic outputs. There is no package compiled code.

The original build used httr2 1.3.0, jsonlite 2.0.0, tibble 3.3.0,
testthat 3.3.2, knitr 1.50, rmarkdown 2.29, sf 1.1-3, and roxygen2 8.1.0.
The clean R 4.6.1 dependency library uses httr2 1.3.0, jsonlite 2.0.0,
tibble 3.3.1, testthat 3.3.2, knitr 1.52, rmarkdown 2.32, ggplot2 4.0.3,
and sf 1.1-3. Windows spatial libraries report GEOS 3.14.1, GDAL 3.12.1,
and PROJ 9.7.1. Exact library paths and versions are retained in the
[environment log](../.artifacts/release-validation/baseline-environment.log),
[dependency inventory](../.artifacts/release-validation/dependency-paths.tsv),
and [R 4.6 dependency installation log](../.artifacts/release-validation/install461.log).

## B. Cross-platform results

### Corrected candidate qualification (October 25)

[Run 40162249386](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40162249386)
executed all seven configurations against commit
`0db68d969d0a8a23be55ae114d2900d9a8b4bcfc`. Every job built a source
tarball, installed it, ran `R CMD check --as-cran --no-manual`, executed tests
and examples, and rebuilt the vignettes. The actual job logs and downloaded
check artifacts were inspected; all seven `00check.log` files end in
`Status: OK`, with no errors, warnings, or notes.

| OS | R version | Build | Check | Errors | Warnings | Notes | Evidence |
|---|---|---|---|---|---|---|---|
| Ubuntu 24.04.5 x64 | release 4.6.1 | PASS | PASS | 0 | 0 | 0 | [Job 121076060040](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40162249386/job/121076060040) |
| Ubuntu 24.04.5 x64 | devel 4.7.0, 2026-10-23 r90760 | PASS | PASS | 0 | 0 | 0 | [Job 121076059942](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40162249386/job/121076059942) |
| Ubuntu 24.04.5 x64 | oldrel 4.5.3 | PASS | PASS | 0 | 0 | 0 | [Job 121076059997](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40162249386/job/121076059997) |
| Windows Server 2022 x64 | release 4.6.1 | PASS | PASS | 0 | 0 | 0 | [Job 121076059747](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40162249386/job/121076059747) |
| Windows Server 2022 x64 | devel 4.7.0, 2026-10-23 r90760 | PASS | PASS | 0 | 0 | 0 | [Job 121076059950](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40162249386/job/121076059950) |
| macOS Tahoe 26.6.2 ARM64 | release 4.6.1 | PASS | PASS | 0 | 0 | 0 | [Job 121076059952](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40162249386/job/121076059952) |
| macOS Tahoe 26.6.2 ARM64 | devel 4.7.0, 2026-10-24 r90762 | PASS | PASS | 0 | 0 | 0 | [Job 121076059972](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40162249386/job/121076059972) |

Windows recorded 6,350 passing assertions per job; Linux and macOS recorded
6,349 each. All jobs had zero test failures, zero test warnings, and 23
documented skips. The extra Windows assertion verifies native cleanup's exit
status; all platforms verify that the test link disappears and its target
survives. No test was weakened to remove a warning.

The CI jobs built separate archives rather than checking the identical bytes
of the local archive in section A. Their SHA-256 hashes, R versions, test
summaries, and check statuses are recorded in
[results.csv](../.artifacts/release-validation/qualification-ci/results.csv).
All 123 selected code, test, Rd, vignette-source, catalog/schema, and binary
asset files matched the committed source in every archive, with text line
endings normalized; see
[source-equivalence.csv](../.artifacts/release-validation/qualification-ci/source-equivalence.csv).
Generated HTML and build metadata were not asserted byte-identical.
All seven archived parks HTML files contained their rendered chart; the
Linux release, Windows devel, and macOS devel charts were also visually
inspected for readable bars and labels. See the
[HTML inspection log](../.artifacts/release-validation/qualification-ci/html-inspection.log).

CI uses the R actions' defaults: CRAN incoming checks and remote clock
verification are disabled. These successful runs do not establish external
URL/ORCID verification. The local check below retains the clock check.

The exact archive in section A also passed a complete local Windows R 4.6.1
`R CMD check --as-cran`: **0 errors, 0 warnings, 1 clock note**, 6,350 passing
assertions, zero test warnings, and 23 skips. Examples, all nine vignette
rebuilds, and PDF/HTML manuals passed. See its
[check log](../.artifacts/release-validation/qualified-windows461-run/tampaBayOpenData.Rcheck/00check.log).

### Earlier local archive (October 24)

These historical results checked the earlier archive with SHA-256
`252D801FA434B618B62BC8F9A4300A7808CE707D1A6004AE1F289E88DCC77171`,
not the follow-up archive in section A. A reused archive has `NOT RUN` in the
Build column when no separate native build was performed. Local remote CRAN
incoming checks were disabled explicitly; this does not validate external
URLs or ORCID availability.

| OS | R version | Build | Check | Errors | Warnings | Notes | Evidence |
|---|---|---|---|---|---|---|---|
| Windows 11 x64 | 4.5.1 | PASS | PASS | 0 | 0 | 1 | [Local log](../.artifacts/release-validation/final3-windows451-run/tampaBayOpenData.Rcheck/00check.log) |
| Windows 11 x64 | 4.6.1 release | NOT RUN | PASS | 0 | 0 | 1 | [Local log](../.artifacts/release-validation/final3-windows461-run/tampaBayOpenData.Rcheck/00check.log) |
| Ubuntu 24.04.3, WSL2 x64 | 4.3.3, additional compatibility check | NOT RUN | FAIL | 0 | 1 | 2 | [Local log](../.artifacts/release-validation/final3-linux433-run/console.log) |

The additional Linux check completed, but fails a strict no-warning gate;
its missing-tool warning and two notes are classified in Finding 8.

### Executed baseline CI, inspected separately

[Run 40156056405](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40156056405)
checked commit `98d9780` with platform-specific builds, `--as-cran --no-manual`,
live calls disabled, and dependencies restored/installed by `r-lib/actions`.
All five downloaded `00check.log` files end in `Status: OK`; the job logs,
test outputs, HTML, and source archives were inspected. This is evidence about
the baseline commit, not a pass for the corrected final archive or unrun jobs.

| OS | R version | Build | Check | Errors | Warnings | Notes | Evidence |
|---|---|---|---|---|---|---|---|
| Ubuntu 24.04.5 x64 | 4.6.1 | PASS | PASS | 0 | 0 | 0 | [Job 121057597370](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40156056405/job/121057597370) |
| Ubuntu 24.04.5 x64 | devel 4.7.0, 2026-10-22 r90748 | PASS | PASS | 0 | 0 | 0 | [Job 121057597454](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40156056405/job/121057597454) |
| Ubuntu 24.04.5 x64 | oldrel 4.5.3 | PASS | PASS | 0 | 0 | 0 | [Job 121057597443](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40156056405/job/121057597443) |
| Windows Server 2022 x64 | 4.6.1 | PASS | PASS | 0 | 0* | 0 | [Job 121057597567](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40156056405/job/121057597567) |
| macOS Tahoe 26.6.2 ARM64 | 4.6.1 | PASS | PASS | 0 | 0 | 0 | [Job 121057597481](https://github.com/Jaclenga/tampaBayOpenData/actions/runs/40156056405/job/121057597481) |

\* Windows recorded one **test warning** despite a clean overall check
status: recursive cleanup of a test junction failed with a reparse-tag
mismatch. It also reported a temporary-session cleanup warning. Neither was
silently counted as zero test warnings. See Finding 2.

Each baseline job recorded 6,347 passing assertions and 23 skips. The 23 skips
are 18 opt-in live checks and five report-tool checks whose development scripts
are intentionally excluded from the source tarball. Local copies of the
artifacts and five full job logs are under
[ci-artifacts](../.artifacts/release-validation/ci-artifacts/) and
`.artifacts/release-validation/ci-*.log`. Artifact hashes differ across
platform builds; none is asserted to equal the local final tarball.

## C. Test results

### Category A: deterministic, offline qualification

- The current candidate's seven-platform results and exact local-archive
  check are recorded above. All 23 skips remain the same opt-in live and
  excluded development-tool cases as in the initial audit.
- Both original local Windows checks passed 6,347 assertions with zero test failures or
  test warnings and 23 documented skips. Examples, all nine vignette rebuilds,
  and PDF/HTML manuals passed. Their only check NOTE was inability to verify
  current time remotely. Linux R 4.3.3 also passed 6,347 assertions with zero
  failures or test warnings and the same 23 skips; examples and all vignette
  rebuilds passed. Its strict warning gate remains failed as detailed below.
- Full installed-package tests, examples, namespace checks, dependencies,
  syntax, documentation, manual checks, and vignette rebuilding are reported
  in the final check logs above. No live-test skips are treated as passes.
- The corrected download tests passed locally with all existing assertions
  retained: [fix-check.log](../.artifacts/release-validation/fix-check.log).
- Both installed tutorial sources rendered from a different working directory
  with `httr2::req_perform()` blocked and counted: **zero HTTP attempts**.
  Parks loading uses `system.file()`; the mapping source now also locates its
  snapshot and fallback image in installed `extdata`.
- All nine source vignettes were also rebuilt with the publisher transport
  blocked and counted: zero HTTP attempts. See the
  [offline build log](../.artifacts/release-validation/offline-build.log).
- A fresh dependency library excluding both `sf` and ggplot2 rendered the
  parks chart and mapping fallback. The mapping tutorial explains when `sf`
  is needed. This was actual dependency isolation, not a fabricated spatial
  result.
- The exact parks counting/chart chunks handled the saved data, zero rows,
  missing/blank labels, and more than five categories. The original snapshot
  remains unchanged and retains its source, query, and UTC retrieval time.
  The live chunk is visibly marked `eval=FALSE` and never runs during a build.
- Archived baseline HTML from all five CI jobs contained the parks chart;
  the extracted Windows, Linux, and macOS release charts were visually
  inspected. Fonts differ, while labels and bars remain readable.
- Windows R 4.6.1 downloads/resumes passed with spaces, forward slashes,
  backslashes, and a non-ASCII filename under a UTF-8 locale. Date parsing
  retained UTC field semantics with session time zones UTC, America/New_York,
  and Asia/Tokyo. Under forced `LC_CTYPE=C`, base R could not translate the
  non-ASCII filename; this unsupported encoding case is recorded as a
  limitation, not a pass.
- Linux installed-package rendering also passed with zero HTTP attempts.
  Linux download/resume checks passed with spaces and non-ASCII names;
  the three time-zone checks passed, and a read-only temporary destination
  produced the expected permission error without writing a manifest. The
  latter deliberate failure emitted base R's `Permission denied` warning;
  it is not an unexpected warning from the release test suite.

Evidence: [installed tutorial checks](../.artifacts/release-validation/final3-tutorials461.log),
[checks without spatial packages](../.artifacts/release-validation/final3-tutorials-no-sf.log),
[Windows UTF-8 filesystem/time-zone checks](../.artifacts/release-validation/stress461-utf8.log),
[ASCII-locale failure](../.artifacts/release-validation/stress461.log), and
[CI HTML inspection](../.artifacts/release-validation/ci-html.log).
Additional Linux evidence:
[installed rendering](../.artifacts/release-validation/tutorials-linux.log),
[filesystem/time zones](../.artifacts/release-validation/stress-linux.log),
and [installation](../.artifacts/release-validation/linux-installed.log).
The final qualified archive's installed parks and mapping sources were also
rendered with HTTP blocked, with zero attempted requests:
[qualified-tutorials.log](../.artifacts/release-validation/qualification-ci/qualified-tutorials.log).

The reviewed suite deterministically exercises timeouts, rate limits,
Retry-After handling, HTTP/ArcGIS errors, invalid JSON, empty responses,
unexpected structures, pagination, interrupted/resumed downloads, checksum
and provenance tampering, schema drift, field types, and spatial coordinates.
Its offline setup replaces the HTTP transport with an error unless a test
installs its own fixture. No assertions or meaningful tests were disabled.

### Category B: bounded live integration

The final installed candidate retrieved the tutorial's current parks preview
with `limit=100`, compared its required fields with the saved preview, and ran
the same counting/chart code. Two additional requests retrieved at most two
features each from `capital-projects` and `city-boundary`, with `spatial=TRUE`
and `out_sr=4326`; returned CRS and provenance checks passed.

The final qualification log records exact endpoints, UTC times,
returned/matching counts, and completeness:
[qualified-live.log](../.artifacts/release-validation/qualification-ci/qualified-live.log).
The live parks and capital-project results were deliberately incomplete
previews; the one-feature boundary was complete. This smoke check passed but
does **not** establish that every checked layer or live discovery path works.
The entire opt-in live suite was NOT RUN for this candidate. No publisher
was intentionally overloaded or asked to manufacture failure responses.

## D. Findings

1. **Documentation defect — resolved.** Two generated Rd pages differed from
   roxygen2 8.1.0 output: the search query description was stale, and a download
   cross-reference had different generated wrapping. Regenerated those pages;
   the 16-function namespace and public signatures are unchanged. The
   hand-authored catalog-health help page is intentionally not generated.

2. **Windows test cleanup defect — resolved and verified remotely.** Baseline
   CI's `test-download.R` could not remove a redirected test directory because
   of a Windows reparse-tag mismatch. Nonrecursive `unlink()` passed locally
   but retained the warning on hosted Windows release/devel runners. Cleanup
   now uses PowerShell's nonrecursive `[System.IO.Directory]::Delete()` on
   Windows and `unlink()` on Unix. Existing path-containment and rejection
   assertions remain, with additional assertions for successful cleanup and
   preservation of the target. Both final Windows jobs passed without the
   test or session-cleanup warnings; no warnings were suppressed.

3. **Installed tutorial defect — resolved.** Re-rendering the installed
   mapping Rmd failed at `readRDS("data/tampa-infrastructure.rds")`; its data
   directory was absent from the installed `doc` directory. Relocated the
   existing RDS, provenance note, and fallback PNG to `inst/extdata` and used
   `system.file(..., mustWork=TRUE)` for both paths. No duplicate data, new
   dependency, geometry transformation, or public function was introduced.
   Installed renders with and without `sf` now pass offline.

4. **CI coverage gap — resolved for the requested matrix.** Added Windows
   R-devel and macOS R-devel and executed all seven jobs on the corrected
   candidate. The initial macOS R-devel attempt failed while installing
   `units`, before package checks, because UDUNITS2 was absent. A conditional
   Homebrew step now installs `pkg-config`, `udunits`, and `gdal` and supplies
   the documented UDUNITS2 include/library paths. This follows the
   [units configuration](https://github.com/r-quantities/units/blob/main/configure.ac)
   and [sf installation guidance](https://github.com/r-spatial/sf/blob/main/README.md).
   Both the system-library fix and Windows cleanup correction were verified
   by the final matrix. YAML was validated before execution. The pinned
   actions, caching, artifacts, read-only permissions, and separate live
   workflow remain. Intel macOS remains untested.

5. **Local environment issues — isolated.** Early Windows R 4.6.1 attempts
   loaded an old unprefixed package from a portable runtime's forced
   `site-library`; R 4.5 dependency DLLs also failed under a separate R 4.6
   runtime. These attempts are not successful candidate checks. Used a
   separate runtime copy, matching binary dependencies, and absolute check
   library paths. The earlier erroneous example/test output is preserved in
   `windows461-run`, with diagnostics in `env-probe.R` and
   `installed-mapping-probe.log`.

6. **Build hygiene — resolved before final archive.** A local diagnostic probe
   created `tampaBayOpenData-Ex.pdf`, and an intermediate archive included it.
   Removed that audit-generated file, restaged the source, rebuilt, and audited
   the final member list before restarting complete checks. Intermediate
   archives and interrupted/superseded checks are not final release evidence.

7. **Infrastructure limitations — recorded.** Remote repository indexes and
   clock verification can fail under the local network restrictions. Remote
   incoming checks were explicitly disabled, with failures retained in logs.
   WSL discarded an initial temporary dependency library between sessions;
   the final Linux run uses a persistent workspace dependency library. Windows
   ACL-restricted destinations were NOT RUN; `chmod` was not substituted for
   an ACL test. Non-ASCII paths under an ASCII locale remain unsupported by
   the exercised base-R file operations.

8. **Final check diagnostics — investigated, no package change required.**
   The local Windows checks report `unable to verify current time` (R 4.6.1 uses
   capitalized wording). The clock check remained enabled; no package dates
   or timestamps were changed to hide the note. Remote package-index access
   warnings are retained in console logs; dependency checks still completed.
   The historical R 4.5.1 check also reports that its local testthat binary was built under R 4.5.3;
   this dependency-version warning precedes tests, whose warning count is zero.
   The newer R 4.6.1 dependency library does not have that mismatch.

   Linux R 4.3.3 reports `qpdf is needed for checks on size reduction of PDFs`.
   This is a missing external check tool, not a failed package installation;
   install qpdf and repeat the exact tarball check to clear that warning.
   Its notes are `unable to verify current time` and `Author field differs
   from that derived from Authors@R`: the R 4.5.1-built `Author` field includes
   `ORCID:` while R 4.3.3 derives the same name, roles, and URL without that
   prefix. The source `Authors@R` remains correct. Treat the latter as a
   cross-version generated-metadata diagnostic; do not hand-edit generated
   author fields. Neither note establishes a data-integrity failure.

## E. Remaining risks

The required Linux release/devel and Windows release/devel checks, Linux
oldrel, and macOS ARM64 release/devel qualification have now executed and
passed on the corrected source. Intel macOS and R 4.1, declared as the
minimum, were not executed. Linux R 4.3.3 is only an additional historical
compatibility check; its missing-qpdf warning was not hidden or counted as a
clean check. CI omits the PDF manual; the exact current archive's local
Windows check passed both PDF and HTML manual checks.

External URL/ORCID checks, the full live suite, Intel macOS, and Windows ACL
restrictions remain unverified. Native curl, GDAL, GEOS, and PROJ behavior
depends on the installed dependencies; successful package tests do not certify
every native-library version. Publisher updates and network availability
remain outside the package's control.

### Reproducing the local evidence

Use the archive above rather than the development working directory, verify
its SHA-256, and install all declared Imports and Suggests for the selected R
version. Use absolute paths for the check library. Keep
`TAMPA_OPEN_DATA_LIVE=false` for deterministic checks.

```sh
R CMD build /absolute/path/to/staged-source
R CMD check --as-cran --library=/absolute/path/to/clean-library tampaBayOpenData_0.1.0.tar.gz
```

[run.ps1](../.artifacts/release-validation/run.ps1) records the actual Windows
commands and environment. For example, from the repository root:

```powershell
& .artifacts/release-validation/run.ps1 -Action check -Stage repeat-windows451 -ArtifactStage qualified-source
```

The dependency inventory, final source manifest, source archive, and logs are
preserved locally under `.artifacts/release-validation/`, which is intentionally
Git-ignored and excluded from CRAN archives. Archive that evidence directory's
logs, manifests, scripts, and tarballs separately before cleaning the workspace;
the dependency libraries themselves are not release artifacts. The excluded
report can be updated without changing the checked package payload.

## F. CRAN readiness decision

**CONDITIONALLY READY.** The previously missing platform checks are complete:
all seven requested configurations passed on the corrected candidate, and no
known release-blocking package defect remains. The earlier **NOT READY**
decision based on an incomplete matrix is superseded.

Remaining noncritical validation gaps are the unexecuted Intel macOS/minimum-R
configurations, full live suite beyond the bounded smoke checks, and remote
CRAN incoming URL/ORCID verification. The maintainer should review the latter
before submission. This decision does not claim that every platform checked
the identical local tarball bytes; the platform archives and source-equivalence
evidence are preserved. No CRAN submission or release publication was attempted.

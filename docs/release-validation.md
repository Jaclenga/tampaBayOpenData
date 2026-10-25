# Release validation: tampaBayOpenData 0.1.0

Validation date: October 24, 2026, America/New_York. Machine-readable logs use
UTC and therefore include October 25. This report distinguishes the committed
baseline from the locally corrected candidate. No release was published,
submitted, committed, or pushed by this audit.

## A. Release candidate

The baseline is commit `98d9780ef89d65e6211a030df10751c2a693e62f` on `main`;
the working tree was clean at inspection. The final candidate is that commit
plus the changes listed below, with the package version unchanged at `0.1.0`.
It is an uncommitted candidate, not a new Git revision.

- Archive: [tampaBayOpenData_0.1.0.tar.gz](../.artifacts/release-validation/final3-run/tampaBayOpenData_0.1.0.tar.gz).
- SHA-256: `252D801FA434B618B62BC8F9A4300A7808CE707D1A6004AE1F289E88DCC77171`.
- Size: 985,279 bytes.
- Build: Windows 11 x64 build 26300, R 4.5.1 (2025-06-13), locale `C`,
  `TZ=UTC`; all nine vignettes built with live retrieval disabled.
- [Source manifest](../.artifacts/release-validation/final-source-manifest.sha256)
  SHA-256: `2AB5AB0A03C7032A49FA5E8FBFF40316CA4242DDB1705D79B9E8DAA99CCA8E91`.
- [Source patch](../.artifacts/release-validation/final-source.patch),
  [tarball member list](../.artifacts/release-validation/final-tarball-files.txt),
  and [build log](../.artifacts/release-validation/final3-run/build.log).

The patch records tracked-file edits; the newly located assets are recorded
in the manifest and included in the source archive. Their RDS and PNG hashes
match the original assets byte for byte.

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

### Final prebuilt archive

Only results against the SHA-256 above belong in this table. A reused archive
has `NOT RUN` in the Build column when no separate native build was performed.
Local remote CRAN incoming checks were disabled explicitly; this does not
validate external URLs or ORCID availability.

| OS | R version | Build | Check | Errors | Warnings | Notes | Evidence |
|---|---|---|---|---|---|---|---|
| Windows 11 x64 | 4.5.1 | PASS | PASS | 0 | 0 | 1 | [Local log](../.artifacts/release-validation/final3-windows451-run/tampaBayOpenData.Rcheck/00check.log) |
| Windows 11 x64 | 4.6.1 release | NOT RUN | PASS | 0 | 0 | 1 | [Local log](../.artifacts/release-validation/final3-windows461-run/tampaBayOpenData.Rcheck/00check.log) |
| Ubuntu 24.04.3, WSL2 x64 | 4.3.3, additional compatibility check | NOT RUN | FAIL | 0 | 1 | 2 | [Local log](../.artifacts/release-validation/final3-linux433-run/console.log) |
| Ubuntu Linux | release | NOT RUN | NOT RUN | — | — | — | Baseline CI below is a different artifact |
| Ubuntu Linux | devel | NOT RUN | NOT RUN | — | — | — | Baseline CI below is a different artifact |
| Ubuntu Linux | oldrel | NOT RUN | NOT RUN | — | — | — | Baseline CI below is a different artifact |
| Windows | devel | NOT RUN | NOT RUN | — | — | — | Added to CI; no run of the updated workflow |
| macOS Apple Silicon | release | NOT RUN | NOT RUN | — | — | — | Baseline CI below is a different artifact |
| macOS Apple Silicon | devel | NOT RUN | NOT RUN | — | — | — | Added to CI; no run of the updated workflow |
| macOS Intel | release/devel | NOT RUN | NOT RUN | — | — | — | No Intel runner used in this audit |

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

- Both final Windows checks passed 6,347 assertions with zero test failures or
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

The log records exact endpoints, UTC times, returned/matching counts, and
completeness: [final-live.log](../.artifacts/release-validation/final-live.log).
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

2. **Windows test cleanup defect — resolved.** Baseline CI's
   `test-download.R` recursively removed a temporary junction. A local R 4.6.1
   reproduction showed that nonrecursive `unlink()` removes the link while
   retaining its target and marker file. Changed only cleanup to nonrecursive
   removal, preserving the existing path-containment checks and all rejection
   assertions. The focused download suite passed without the junction warning.

3. **Installed tutorial defect — resolved.** Re-rendering the installed
   mapping Rmd failed at `readRDS("data/tampa-infrastructure.rds")`; its data
   directory was absent from the installed `doc` directory. Relocated the
   existing RDS, provenance note, and fallback PNG to `inst/extdata` and used
   `system.file(..., mustWork=TRUE)` for both paths. No duplicate data, new
   dependency, geometry transformation, or public function was introduced.
   Installed renders with and without `sf` now pass offline.

4. **CI coverage gap — configured, NOT RUN.** Added Windows R-devel and
   macOS R-devel to the existing matrix. The pinned maintained R actions,
   caching, artifact uploads, read-only permissions, PR/main triggers, and
   separate bounded live workflow remain in place. YAML parsed successfully;
   seven matrix configurations were verified. The updated workflow has not
   run, and it was not pushed. Intel macOS remains untested.

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
   Both Windows checks report `unable to verify current time` (R 4.6.1 uses
   capitalized wording). The clock check remained enabled; no package dates
   or timestamps were changed to hide the note. Remote package-index access
   warnings are retained in console logs; dependency checks still completed.
   R 4.5.1 also reports that its local testthat binary was built under R 4.5.3;
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

The final corrected artifact still needs the current Linux release/devel and
Windows devel checks, and macOS qualification. Baseline CI is encouraging
evidence but cannot certify the changed artifact. Linux R 4.3.3 is an extra
compatibility result, not a substitute for release or devel. R 4.1, declared
as the minimum, was not executed. The local Linux check omits the PDF manual;
the baseline CI jobs also use `--no-manual`.

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
& .artifacts/release-validation/run.ps1 -Action check -Stage repeat-windows451 -ArtifactStage final3
```

The dependency inventory, final source manifest, source archive, and logs are
preserved locally under `.artifacts/release-validation/`, which is intentionally
Git-ignored and excluded from CRAN archives. Archive that evidence directory's
logs, manifests, scripts, and tarballs separately before cleaning the workspace;
the dependency libraries themselves are not release artifacts. The excluded
report can be updated without changing the checked package payload.

## F. CRAN readiness decision

**NOT READY.** No release-blocking package defect was found in the completed
final checks, but required qualification of this corrected artifact is
incomplete: current Linux release/devel and Windows devel results are missing.
The baseline matrix cannot certify a changed tarball, and the additional
Linux R 4.3.3 check has a documented missing-tool warning. Complete the
remaining matrix and review those diagnostics before submitting. No submission
or release publication was attempted.

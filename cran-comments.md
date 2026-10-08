## Submission

This is a new submission of `tampaBayOpenData` 0.1.0. The maintainer in the
candidate archive is Jack Lenga <jlenga@alumni.cmu.edu>.

## Candidate archive

The candidate source archive was built from the tracked working-tree files on
2026-10-07 with R 4.6.1. Its SHA-256 is
`F0CD0EF707F2A3D022856F94C8993CED94B62CD146E65C3D0E68624B20D0E0DA`
(247,849 bytes). The archive contains no development or local check directories,
prior archives, or `cran-comments.md`.

## Checks on this exact archive

* Windows 11 x64, R 4.6.1: `R CMD check --as-cran` exited 0 with **0 ERRORs,
  0 WARNINGs, 1 NOTE**. The NOTE was `Unable to verify current time`; the local
  check environment could not complete remote clock verification. No file was
  reported as future-dated. Tests recorded 5,541 passes, 18 intentional
  opt-in live-test skips, and no failures or test warnings. Examples, all four
  vignettes, and PDF and HTML manuals passed.
* Windows 11 x64, R 4.5.1: `R CMD check --as-cran` on the same archive exited 0
  with **0 ERRORs, 0 WARNINGs, 1 NOTE**. The NOTE was inability to verify the
  current time. Tests recorded 5,541 passes, 18 intentional live-test skips,
  and no failures or test warnings. Examples, vignettes, and PDF and HTML
  manuals passed. This run had `pdflatex`, Pandoc, `qpdf`, and HTML Tidy
  available; an earlier tool-limited attempt did not complete the PDF manual.
* Ubuntu 24.04.3, R 4.3.3: `R CMD check --as-cran --no-manual` exited 0 with
  **1 WARNING, 3 NOTEs**. Tests again recorded 5,541 passes and 18 intentional
  live-test skips. The WARNING says `qpdf` is unavailable on that local check
  host. The NOTEs are `New submission`, inability to verify current time, and
  an `Author`/`Authors@R` difference: R 4.3.3 formats the ORCID in the archive
  built by R 4.6.1 differently. The PDF manual was not checked in this run.

The successful Windows R 4.6.1 run set `_R_CHECK_CRAN_INCOMING_REMOTE_=FALSE`.
An attempt with remote incoming checks enabled stopped before package tests
because R could not open CRAN's `PACKAGES.in` over HTTPS (SSL connection error).
Remote incoming checks therefore remain unverified for this archive.

## Earlier test interruption and remaining platform evidence

Two earlier concurrent Windows R 4.5.1 checks stopped in `tests/testthat.R`
after about 286 seconds. Their test subprocesses ended within 10 milliseconds
of each other, and their identical output ends at `test_check()` without an
assertion failure, traceback, or timeout report. A later run of the same earlier
source revision completed the tests. The Windows R 4.6.1 and two independent
R 4.5.1 runs on this candidate archive also completed the tests. A shared
external interruption is suggested by the timing, but its cause is unconfirmed.

A prior win-builder R-devel upload used source revision `746ad50`, which still
had the previous maintainer email. Only the upload log is available locally;
there is no stored win-builder result or NOTE to report. That upload did not
test this candidate archive. No macOS or R-devel result for this archive is
available. Live ArcGIS integration tests are opt-in with
`TAMPA_OPEN_DATA_LIVE=true` and do not run during ordinary package checks.

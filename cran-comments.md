## Resubmission

This is a resubmission of `tampaBayOpenData` 0.1.0. CRAN reported a possibly
invalid `LICENSE.md` file URI in `README.md`. The MIT badge now links to the
repository's `LICENSE.md` through an absolute HTTPS URL. Three links in the
packaged `tests/README.md` to repository-only files also now use HTTPS URLs.
`LICENSE.md` is excluded from the source archive by `.Rbuildignore`; the
package's `LICENSE` file and `License: MIT + file LICENSE` metadata remain in
place. The maintainer is Jack Lenga <jlenga@alumni.cmu.edu>.

## Candidate archive

The source archive was built with R 4.5.1 from tracked working-tree files on
2026-10-08 (EDT). Its SHA-256 is
`A739F0D42D7E6CEC0A2163A3CCAF32F296ACFBC7D7E257CB65EA4B2869758BE8`
(248,288 bytes). It contains no development or local check directories, prior
archives, or `cran-comments.md`.

Compared with the original candidate archive, only `README.md` and
`tests/README.md` source content changed. The `Packaged` timestamp in
`DESCRIPTION`, `build/vignette.rds`, and example output formatting in two
generated vignette HTML files also changed during the build.

## Checks on this exact archive

* Windows 11 x64, R 4.5.1: `R CMD build` completed and built the vignettes.
* Windows 11 x64, R 4.5.1: `R CMD check --as-cran` completed with **0 ERRORs,
  1 WARNING, 2 NOTEs**. Tests recorded 5,541 passes, 18 intentional opt-in
  live-test skips, and no failures or test warnings. Examples, vignettes, and
  the PDF manual passed.
* The archived README contains the absolute license URL, and the packaged
  test README contains absolute links to repository-only files. The archive
  includes the package `LICENSE` file and intentionally excludes `LICENSE.md`.

The WARNING reports that this local environment lacks `qpdf` for PDF size
reduction checks. The NOTEs report `Unable to verify current time` and skipped
HTML validation because `tidy` is unavailable. This check set
`_R_CHECK_CRAN_INCOMING_REMOTE_=FALSE` and
`_R_CHECK_CRAN_INCOMING_CHECK_FILE_URIS_=TRUE`; the clock check remained
enabled.

## Earlier checks

The preceding candidate archive, before the README badge change, passed
`R CMD check --as-cran` on Windows R-devel with 0 ERRORs, 0 WARNINGs, 0 NOTEs,
and on Windows R 4.6.1 and R 4.5.1 with 0 ERRORs, 0 WARNINGs, 1 clock NOTE
each. A WSL Ubuntu 24.04.3 R 4.3.3 check completed with 0 ERRORs, 1 missing
`qpdf` WARNING, and 3 NOTEs. All four checks passed the test suite. The
previous archive's SHA-256 was
`A25397F09AFD53569870F5C481FA156A129F6B9A89DE49ED4E2D05EEFDCDCED9`.

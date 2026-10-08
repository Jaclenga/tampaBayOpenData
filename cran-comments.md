## Submission

This is a new submission of `tampaBayOpenData` 0.1.0. The maintainer in the
candidate archive is Jack Lenga <jlenga@alumni.cmu.edu>.

## Candidate archive

The source archive was built with R 4.6.1 from the tracked working-tree files
on 2026-10-07 (EDT). It includes the revised `Description` field and retains
the six public source-page links. Its SHA-256 is
`A25397F09AFD53569870F5C481FA156A129F6B9A89DE49ED4E2D05EEFDCDCED9`
(248,218 bytes). The archive contains no development or local check
directories, prior archives, or `cran-comments.md`.

## Checks on this exact archive

* Windows 11 x64, R-devel (2026-10-06 r90643, R 4.7.0 development snapshot):
  `R CMD check --as-cran` exited 0 with **0 ERRORs, 0 WARNINGs, 0 NOTEs**.
  Tests recorded 5,541 passes, 18 intentional opt-in live-test skips, and
  no failures or test warnings. Examples, vignettes, and PDF and HTML manuals
  passed.
* Windows 11 x64, R 4.6.1: `R CMD check --as-cran` exited 0 with **0 ERRORs,
  0 WARNINGs, 1 NOTE**. Tests recorded 5,541 passes, 18 intentional opt-in
  live-test skips, and no failures or test warnings. Examples, vignettes, and
  PDF and HTML manuals passed.
* Windows 11 x64, R 4.5.1: `R CMD check --as-cran` exited 0 with **0 ERRORs,
  0 WARNINGs, 1 NOTE**. Tests recorded 5,541 passes, the same 18 intentional
  live-test skips, and no failures or test warnings. Examples, vignettes, and
  PDF and HTML manuals passed.
* WSL Ubuntu 24.04.3, R 4.3.3: `R CMD check --as-cran --no-manual` exited 0
  with **0 ERRORs, 1 WARNING, 3 NOTEs**. Tests recorded 5,541 passes, 18
  intentional live-test skips, and no failures or test warnings. The PDF
  manual was not checked because this WSL installation lacks `pdflatex`.

The sole NOTE in each Windows release check was `Unable to verify current time`
under `checking for future file timestamps`. The WSL check reported the same
clock NOTE; none of these logs reports a future-dated package file. The WSL
check also reported `New submission` and an `Author` field difference caused
by R 4.3.3 formatting the ORCID differently from the R version used to build
the archive. Its WARNING says `qpdf` is needed for PDF size-reduction checks;
`qpdf` is absent from this WSL installation. The three Windows runs set
`_R_CHECK_CRAN_INCOMING_REMOTE_=FALSE`, while the WSL run used the default
incoming setting. The clock check remained enabled in the Windows runs.

## Remaining evidence

Two earlier concurrent Windows R 4.5.1 checks of an earlier source revision
stopped in `tests/testthat.R` after about 286 seconds. Their logs show no
assertion failure, traceback, or timeout report, and the cause remains
unconfirmed. All four checks of this archive completed the test suite.

An earlier win-builder R-devel log confirms only an upload of older source
revision `746ad50`, which had the previous maintainer email. The exact archive
above was uploaded to win-builder R-devel on 2026-10-07, and the upload page
reported its name and size, but no result log has been received. The local
Windows R-devel result above is separate from win-builder. No macOS check of
this exact archive is available. Live ArcGIS integration tests require
`TAMPA_OPEN_DATA_LIVE=true` and are skipped in ordinary package checks.

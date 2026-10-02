# Bug scan: 2026-09-29

This scan reproduced and corrected the following client defects with synthetic,
offline data. It covered parsing, pagination, response validation, spatial
references, HTTP construction, and dependency requirements.

| Area | Reproduced failure | Correction |
| --- | --- | --- |
| Polygon coordinates | A closed ring with mixed integer and decimal endpoints failed an `identical()` check. Named coordinates could swap XY or discard a null point. | Compare finite XY values and require positional coordinate arrays. |
| Big integers | Default display precision rounded `123456789.5` to `"123456790"`. | Reject fractional and nonfinite numbers before formatting; retain exact source strings. |
| JSON objects | Nested duplicate keys could select conflicting schema, feature, geometry, or CRS values. Object-valued metadata accepted arrays. | Reject duplicate keys recursively and require object shapes. |
| Retrieval integrity | A string transfer-limit flag or a changed page OID declaration could be accepted as complete. | Validate flag types and compare page declarations with the layer schema. |
| Field aliases | Malformed aliases caused an uninformative `vapply()` error. | Validate aliases before inspection and retain source context in failures. |
| Spatial references | Conflicting resolvable `wkid` and `latestWkid` values could select one CRS silently. | Resolve both, normalize known aliases, and reject disagreement; prefer explicit WKT. |
| HTTP dependency | Earlier `httr2` versions lacked the configured retry option or changed Unicode query values in the C locale. | Require `httr2` 1.2.3 or later and check prepared POST bytes. |

The dependency decision follows the published
[`httr2` retry code](https://github.com/r-lib/httr2/blob/v1.0.4/R/req-retries.R)
and the [1.2.3 query formatter](https://github.com/r-lib/httr2/blob/v1.2.3/R/url.R).
The spatial check follows Esri's
[spatial reference documentation](https://developers.arcgis.com/rest/services-reference/enterprise/using-spatial-references/).

The three regression files added 213 assertions:
[parsing](../tests/testthat/test-bug-parsing.R) (60),
[responses](../tests/testthat/test-bug-responses.R) (92), and
[spatial handling](../tests/testthat/test-bug-spatial.R) (61). Three more
[HTTP assertions](../tests/testthat/test-http.R) checked POST bytes. At the
end of this scan, the offline suite passed 891 assertions and measured 98.38%
deterministic coverage. In an isolated `httr2` 1.2.3 installation with
`LC_CTYPE=C`, 64 HTTP assertions passed. Two opt-in live cases passed 28
assertions after these fixes. These are dated results; later checks are in
[validation](validation.md).

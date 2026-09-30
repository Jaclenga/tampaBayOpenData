# Bug scan and corrections

Reviewed the R client, registry, discovery, parsing, pagination, spatial
conversion, provenance, HTTP construction, and dependency requirements on
2026-09-29. Each finding below was reproduced before correction. Ordinary
regressions use synthetic values and require no live service.

| Finding | Effect before correction | Correction |
| --- | --- | --- |
| Mixed integer/decimal polygon endpoints | A valid closed JSON ring was rejected because `identical()` distinguishes numeric storage types. | Compare finite XY values; different endpoint coordinates still fail. |
| Numeric big-integer fractions | `123456789.5` could become `"123456790"` at default display precision. | Reject fractional/nonfinite numbers before formatting; exact integers ignore display precision and source strings remain unchanged. |
| Named coordinate objects | Object member order could silently swap XY, or discard a named null point. | Require positional coordinate arrays before interpreting or dropping them. |
| Nested duplicate JSON keys | Conflicting field types, feature attributes, geometry, or CRS properties selected the first value. | Reject duplicate object keys throughout decoded responses. |
| Arrays in object-valued metadata | Malformed date-reference metadata could bypass timezone checks and assign UTC. | Reject nonempty unnamed arrays where metadata objects are required. |
| Malformed manifest transfer flags | A string `"true"` was treated as false while retrieval could claim completeness. | Validate logical scalar flags consistently for ID manifests and feature pages. |
| Changed page ID declarations | A page naming a different object-ID field could still claim complete retrieval. | Compare each optional page declaration with the validated layer schema. |
| Malformed optional field aliases | Live schema inspection raised a raw `vapply()` error without source context. | Validate aliases before inspection; retain valid and missing-alias behavior. |
| Conflicting known WKIDs | Resolvable identifiers naming different coordinate systems silently selected one label. | Resolve each WKID independently, normalize supported aliases, and reject disagreement. |
| Incorrect httr2 minimum version | Versions allowed by DESCRIPTION lacked the retry argument, preventing HTTP requests. | Require httr2 1.2.3 or later, which supports the configured retry option. |
| Locale-dependent query encoding | Older httr2 releases changed accented characters into ASCII escape text in the C locale, silently changing filters. | Require httr2 1.2.3 or later; verify the prepared POST bytes preserve UTF-8. |

Esri defines `latestWkid` as the current identifier for the same spatial
reference. The consistency check retains unknown legacy-ID fallback and the
supported Web Mercator and Tampa capital-project aliases. Explicit WKT remains
preferred because it can contain compound definitions with vertical components.
See [Esri geometry objects](https://developers.arcgis.com/rest/services-reference/enterprise/geometry-objects/)
and [using spatial references](https://developers.arcgis.com/rest/services-reference/enterprise/using-spatial-references/).

The dependency correction follows the published retry signatures:
[httr2 1.0.0](https://github.com/r-lib/httr2/blob/v1.0.0/R/req-retries.R)
lacks `retry_on_failure`, while
[httr2 1.0.4](https://github.com/r-lib/httr2/blob/v1.0.4/R/req-retries.R)
supports the option used by this client.
The published query formatter in
[httr2 1.2.2](https://github.com/r-lib/httr2/blob/v1.2.2/R/url.R)
also applies locale-dependent display formatting to character values;
[httr2 1.2.3](https://github.com/r-lib/httr2/blob/v1.2.3/R/url.R)
retains those values before URL encoding. The required minimum is therefore
1.2.3.

The three new regression files add **213 assertions**:

- [Parsing](../tests/testthat/test-bug-parsing.R): 60 assertions.
- [Response validation](../tests/testthat/test-bug-responses.R): 92 assertions.
- [Spatial handling](../tests/testthat/test-bug-spatial.R): 61 assertions.

Three additional assertions in [HTTP construction](../tests/testthat/test-http.R)
check prepared POST bytes, bringing the scan's regression additions to **216**.

After this bug scan, the complete offline suite passed **891 assertions**, with
no test failures or warnings, and deterministic coverage was **98.38%**.
The later [security audit](security-audit.md) adds further checks; current totals
are recorded in validation.md. Reproduction commands are in the
[test suite guide](../tests/README.md); package validation is recorded in
[validation.md](validation.md).

The minimum httr2 1.2.3 was also installed from its official source tag in an
isolated research library. With `LC_CTYPE=C`, all **64 HTTP assertions** passed,
and a separate prepared-body retrieval check preserved SQL, Unicode, percent
signs, and geometry precision across six requests. Both opt-in live integration
cases passed **28 assertions** against City services after the fixes.

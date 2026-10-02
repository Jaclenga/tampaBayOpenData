# Security audit: 2026-09-29

The audit considered hostile ArcGIS responses and untrusted caller-supplied
query values. Public retrieval uses bundled dataset IDs, not arbitrary endpoint
URLs. Reproductions used synthetic responses, benign local files, mocked
sockets, and recorded sleeps; no credentials or live attacks were involved.

| Finding | Reproduced effect | Correction |
| --- | --- | --- |
| JSON text treated as a source locator | `jsonlite::fromJSON()` read a benign filename supplied as an HTTP body and could also fetch a URL. | Parse literal text with `parse_json()`; require `jsonlite` 1.6.0 or later. |
| WKT treated as a path or URL | A remote `.prj` pathname reached GDAL's general CRS input parser. | Require an inline WKT root and opening delimiter before native parsing. |
| Redirect following | A server could direct a request away from its registered HTTPS endpoint. | Disable redirects and report the HTTP result with source context. |
| Excessive retry wait | `Retry-After: 86400` requested day-long sleeps despite a one-second transfer timeout. | Cap valid server-requested waits at 30 seconds; retain ordinary backoff for invalid or missing headers. |
| Deep JSON nesting | About 3,000 nested arrays exhausted recursive key validation. | Reject more than 64 nested containers with a response error. |

These findings depend on control of an upstream response; the audit found no
evidence that City services were compromised. The JSON distinction is documented
in [`jsonlite`'s parser](https://github.com/jeroen/jsonlite/blob/master/R/read_json.R).
The WKT check prevents path/URL lookup by GDAL's
[`SetFromUserInput()`](https://gdal.org/en/stable/doxygen/classOGRSpatialReference.html),
but does not isolate its native parser. Each HTTP transfer has its own timeout
and at most three attempts; a full multi-request retrieval has no overall
deadline. See the [`httr2` retry API](https://httr2.r-lib.org/reference/req_retry.html).

The client also configures a 50 MiB native transfer ceiling and rejects larger
accepted response text before JSON decoding. This is not full memory isolation:
older libcurl versions can bypass the native ceiling for unknown lengths or
decompression, and the text check runs after buffering. The nesting guard runs
after native JSON parsing. Large result sets still accumulate in memory. See
[`CURLOPT_MAXFILESIZE_LARGE`](https://curl.se/libcurl/c/CURLOPT_MAXFILESIZE_LARGE.html).

CI action references were pinned to full commits for
[`actions/checkout`](https://github.com/actions/checkout/commit/d23441a48e516b6c34aea4fa41551a30e30af803)
and [`r-lib/actions`](https://github.com/r-lib/actions/commit/f9a764fea8d5c63df6ef9a5c7795bf7deb5d7e05).
Both workflows grant `contents: read`; Dependabot checks GitHub Actions
weekly. YAML and workflow behavior were checked locally, but remote CI was
not run as part of this audit.

The audited Windows installation used libcurl 8.14.1 with Schannel, GDAL
3.12.1, and PROJ 9.7.1. An isolated CRAN Windows `curl` 8.0.0 R package
binary still linked the same native libcurl. The audit did not establish
reachability of every [libcurl 8.14.1 advisory](https://curl.se/docs/vuln-8.14.1.html)
or distributor backports. Native dependencies come from the user's runtime;
updating only the R `curl` package was not shown to remediate them. Verify
native security updates or documented backports for a deployment. Inherited
proxy and authentication settings were outside the test scope.

[test-security.R](../tests/testthat/test-security.R) added 76 offline
assertions. A separate isolated `httr2` 1.2.3 run passed 140 HTTP and security
assertions in the C locale with network calls and positive sleeps blocked.
The review found no embedded credentials, runtime evaluation, shell execution,
or R deserialization of upstream data. The [validation record](validation.md)
contains dated package results, and the [test guide](../tests/README.md)
contains reproduction commands.

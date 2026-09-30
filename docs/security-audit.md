# Security audit and corrections

Reviewed on 2026-09-29 with three independent agents covering HTTP/query handling,
parsing/geometry/files, and CI/supply chain. The primary review also checked
dependencies, sensitive-data patterns, and the final corrections.

The threat model includes malicious or compromised upstream ArcGIS responses and
untrusted query values supplied by an R caller. Public retrieval accepts bundled
dataset IDs, not arbitrary endpoint URLs. Reproductions used benign local files,
synthetic HTTP responses, mocked sockets, and recorded sleeps. No live attacks or
credential access were performed.

## Confirmed findings

Severity reflects the potential impact when an attacker controls the upstream
response; it is not evidence that the City service has been compromised.

| Severity | Finding | Reproduction and effect | Correction |
| --- | --- | --- | --- |
| High, conditional | HTTP text interpreted as a JSON source locator | A synthetic HTTP 200 body containing a benign JSON filename returned that unrelated file's contents. `fromJSON()` also accepts HTTP URLs, bypassing the shared transport. | Use `parse_json()` for literal response text; require jsonlite 1.6.0 or later. |
| High, conditional | Spatial WKT interpreted as a file or URL | A benign `.prj` pathname in remote `wkt` resolved through sf/GDAL. GDAL's general CRS input API also accepts URLs. | Require an inline WKT1/WKT2 root and opening delimiter before native resolution. |
| Medium, conditional | Redirects leave the registered HTTPS endpoint | The transport inherited automatic redirect following, allowing a server-controlled destination or HTTPS downgrade. | Set `followlocation = FALSE`; report redirects through contextual HTTP errors. |
| Medium | Unbounded server-requested retry sleep | Synthetic HTTP 503 with `Retry-After: 86400` requested two one-day sleeps despite a one-second transfer timeout. | Validate retry delays and cap each server-requested wait at 30 seconds, retaining normal backoff for missing or invalid headers. |
| Low | Excessive JSON nesting exhausts R validation | Approximately 6 KB containing 3,000 nested arrays parsed but exhausted recursive duplicate-key validation. | Reject more than 64 nested containers with a contextual `tampa_response_error`. |

The JSON source ambiguity follows the documented difference between
[`fromJSON()`](https://github.com/jeroen/jsonlite/blob/master/R/fromJSON.R) and
[`parse_json()`](https://github.com/jeroen/jsonlite/blob/master/R/read_json.R).
The literal API was introduced in jsonlite 1.6; see its
[release history](https://github.com/cran/jsonlite/blob/master/NEWS).

The CRS correction restricts input before GDAL's general
[`SetFromUserInput()`](https://gdal.org/en/stable/doxygen/classOGRSpatialReference.html)
dispatch. Genuine inline WKT, including compound definitions, still uses the
native parser; this check does not sandbox native libraries.

Retry behavior is defined by [httr2's retry API](https://httr2.r-lib.org/reference/req_retry.html).
The caller's timeout applies to each transfer attempt, rather than the entire
retrieval. Three attempts remain the maximum per request.

## Additional hardening

- Configure a 50 MiB native transfer-size ceiling and reject accepted response
  text exceeding 50 MiB before JSON decoding.
- Pin all eight CI action references to verified full commits and configure
  weekly GitHub Actions updates through Dependabot.

Both workflow permissions remain `contents: read`. Ordinary pull requests do
not use privileged `pull_request_target` execution. Inline CI scripts do not
interpolate untrusted event values. Commit pinning follows
[GitHub's action security guidance](https://docs.github.com/en/actions/reference/security/secure-use#using-third-party-actions).

The verified action commits are
[`actions/checkout`](https://github.com/actions/checkout/commit/d23441a48e516b6c34aea4fa41551a30e30af803)
and [`r-lib/actions`](https://github.com/r-lib/actions/commit/f9a764fea8d5c63df6ef9a5c7795bf7deb5d7e05).
YAML validation and a semantic comparison preserved the existing triggers,
permissions, jobs, and step behavior. Remote CI has not run from this workspace.

## Deployment dependency risk and limits

The audited Windows runtime links libcurl **8.14.1**, uses Schannel for curl TLS,
and has GDAL **3.12.1** and PROJ **9.7.1**. The latest official CRAN Windows R 4.5
`curl` 8.0.0 binary was separately inspected in an isolated library and still
links the same native libcurl. Updating only the R package does not demonstrate
native security remediation. Published advisories exist for
[libcurl 8.14.1](https://curl.se/docs/vuln-8.14.1.html); their complete reachability
and any distributor backports were not established by this audit.

Before production deployment, use a native libcurl build incorporating current
security fixes, or verify documented security backports. The current upstream
release is [8.22.0](https://curl.se/docs/releases.html). OpenSSL users should also
check [the applicable advisories](https://openssl-library.org/news/vulnerabilities-3.5/);
the audited curl backend is Schannel, rather than its inactive OpenSSL backend.

No native exploit was demonstrated. Several reviewed advisories require
cleartext redirects, explicit HTTP/2 stream dependencies, accepted server push,
or an active OpenSSL provider configuration, which the current client does not
configure. Inherited corporate proxy/authentication configurations were not
exercised. Runtime dependencies are supplied by the user's environment, not
bundled in this package's source archive.

Response-size limits are not complete memory isolation across supported native
versions. Before libcurl 8.4.0, unknown transfer sizes may bypass the native limit;
before 8.20.0, automatic decompression can exceed it. The post-transfer check
bounds accepted JSON but occurs after buffering. See
[`CURLOPT_MAXFILESIZE_LARGE`](https://curl.se/libcurl/c/CURLOPT_MAXFILESIZE_LARGE.html).
The nesting guard bounds package validation after native JSON parsing. Large
result sets still accumulate in memory, and native parser patching remains
necessary.

## Validation

[test-security.R](../tests/testthat/test-security.R) adds **76 offline assertions**
for literal JSON, inline WKT, contextual failures, redirect policy, actual retry
orchestration, malformed retry headers, JSON depth, and response-size limits.
An isolated httr2 1.2.3 run passes all **140 HTTP and security assertions** in the
C locale, with real network calls and positive sleeps blocked.

No embedded credentials, unsafe runtime evaluation, shell execution, or R
deserialization of upstream data was found. Query parameters use an allowlist,
form encoding, and protected response-shape parameters. Read-only ArcGIS SQL
filtering is intentional. Geometry decoding uses a generated local ESRIJSON
file with controlled fields and cleanup.

Full package test, coverage, and build results are recorded in
[validation.md](validation.md); commands are in the [test suite guide](../tests/README.md).

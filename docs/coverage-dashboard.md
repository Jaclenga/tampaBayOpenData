# Coverage dashboard

The [Data coverage dashboard](https://jaclenga.github.io/tampaBayOpenData/articles/coverage.html)
is generated from the installed package's checked catalog. It helps readers
see where the curated list has entries and where a recent metadata check
reported a problem. It is not an inventory of a publisher's entire portal.

## Build locally

From the repository root, with package dependencies and `pkgdown` installed:

```sh
R CMD INSTALL .
Rscript tools/check-catalog.R
Rscript -e "pkgdown::build_site_github_pages(dest_dir = '_site', clean = TRUE, lazy = FALSE, new_process = FALSE, install = TRUE)"
```

The catalog check is optional. It writes timestamped JSON, RDS, CSV, and
Markdown reports under ignored `.artifacts/catalog-health/`; the site build
reads the latest usable health RDS there. The local command runs the same
zero-match count query probe as the daily workflow. It reads no feature rows.
Set `TAMPA_OPEN_DATA_HEALTH_REPORT_DIR` to another report directory before
building to use that location. With no report, the dashboard still builds and
shows health as **unverified**. The site build itself uses the bundled catalog
and saved report without making live ArcGIS requests. Open
`_site/articles/coverage.html` after the build.
The published site restores the latest successful catalog-health workflow
artifact when available and rebuilds after a successful new health run.

## How to read it

Counts come from `tbod_list_datasets(source = "checked")` in the installed
package. Publisher summaries count curated checked entries for each publisher;
per-layer rows retain each entry's primary category. These are not counts of
features, geographic area, current availability, or all public layers on that
topic.
Discovered layers and direct URLs are outside the dashboard. A zero means the
package currently has no checked entry in that cell; it does not mean the
publisher has no relevant data. Any missing schema baseline count is derived
from the current checked registry at build time.

Health comes from the latest usable optional `tbod_check_catalog()` report.
Each result must match the current catalog's publisher, jurisdiction, dataset
ID, and endpoint. It must also be no older than the catalog's own verification
date and have been checked within the last 30 days. Recent
`unavailable`, `schema_changed`, and `unsupported` results are shown as
problems. `unknown`, stale, future-dated, missing, or unmatched results are **unverified**,
not healthy. The report's broader `health_state` is `healthy`, `degraded`,
`unavailable`, or `unknown`; the dashboard uses the detailed `status` for its
existing labels. A recent `healthy` result means the layer endpoint and saved
schema matched when checked, and the count query passed if the report enabled
`probe_query`. The checker does not read every feature. A saved catalog
`verified` date remains visible as dated snapshot
evidence but does not turn an unverified row healthy. The dashboard does not
update the checked catalog or its saved schemas.

## Known gaps

The checked catalog is intentionally selective. Primary categories simplify
layers that may serve several topics, and publishers use different field
definitions, update schedules, and geographic footprints. The dashboard
cannot establish publisher completeness, comparable coverage across
jurisdictions, record freshness, legal accuracy, or future service uptime.
Consult each layer's `scope_note` and source terms, the [catalog policy](checked-catalog-policy.md),
and the dated [validation record](validation.md) before interpreting a cell or
using a layer for analysis.

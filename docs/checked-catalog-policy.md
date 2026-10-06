# Checked catalog selection and maintenance policy

The checked catalog contains selected regional layers. Live discovery searches
more of the configured publishers' public ArcGIS services. A `checked` layer
has a recorded source, scope, query check, and dated schema expectation. A
`discovered` layer was found through a public portal or service without that
review. Neither label measures the correctness of the publisher's data.

## Selection policy

Choose layers that satisfy most of these conditions:

1. An identifiable public organization publishes the layer or clearly
   identifies its underlying source.
2. The layer supports useful regional research or planning.
3. It covers a consequential regional topic or a useful geographic baseline.
4. Its fields, geometry, geographic extent, dates, and major limitations can be
   explained accurately.
5. Its public ArcGIS endpoint is stable enough to justify a maintained schema
   snapshot and supports a usable `Query` operation.
6. Source terms can be identified and stated accurately, even if the source
   does not grant an explicit open-data license.
7. It adds geographic, topical, or methodological value beyond other checked
   layers. Comparable layers from different governments may support regional
   analysis.
8. The package can validate its object-ID field, field types, geometry, CRS,
   count and pagination behavior, and bounded retrieval automatically.

Do not add a layer merely to fill a cell in a coverage matrix or reach a target
count. Exclude sources with an unknown or misattributed publisher, a private or
unqueryable endpoint, an unusable or uninterpretable schema, restrictions that
prevent the intended use, or important limitations that cannot be stated
clearly. A temporary outage calls for investigation before retirement. A
historical planning layer may qualify if its date and intended use are explicit.
Research inventories assembled by a public agency require particular scrutiny:
their publisher's authority does not by itself verify each underlying record.

Candidate scoring supports editorial judgment; it does not automatically grant
checked status. Record a short reason for every score and favor sources with
cross-jurisdiction analytical value.

| Dimension | Points | Question |
| --- | ---: | --- |
| Public or research usefulness | 0–3 | Can users answer a consequential question with this layer? |
| Regional significance | 0–3 | Does the subject or footprint matter to Tampa Bay? |
| Source authority | 0–2 | Is the publisher responsible for the underlying data? |
| Endpoint and schema stability | 0–2 | Can the same layer be monitored over time? |
| Metadata quality | 0–2 | Are fields, dates, extent, and limitations interpretable? |
| Cross-jurisdiction analytical value | 0–3 | Can it support comparison or regional analysis? |
| Distinctiveness | 0–2 | Does it add coverage or a useful technical case? |

The maximum is 17. Low scores in authority, interpretability, or queryability
need a specific justification and may be disqualifying regardless of the total.
The catalog remains intentionally bounded; live discovery is the route to
other public layers.

## Limits of checked status

The `verified` date records what maintainers observed **at that time**. It is
not a feature update date, a service-availability guarantee, or a promise that
future metadata will match. Retrieval compares current layer metadata to the
saved expectation; added fields warn, while incompatible changes stop checked
retrieval. An ArcGIS item modification timestamp may describe the item rather
than its feature records.

Checked status does **not** guarantee government-data correctness,
completeness, legal accuracy, currentness, historical preservation, continuous
availability, or publisher endorsement. It also does not grant a license. The
package's MIT license covers package code only. Record the exact source's
license or terms without transferring a license from a related item or service.
For example, the City of Tampa's [Conditions and Use](https://www.tampa.gov/about-us/tampagov/conditions-and-use)
provides general site terms, while several exact checked services have no
separate explicit license. Users should read `tbod_dataset_info(id)$terms`
before reuse.

## Baseline audit: 35 checked layers

This audit uses the bundled registry, schema snapshots, source notes, and the
[October 4, 2026 live validation record](validation.md). A further bounded
metadata and count recheck on October 5 reached all 35 baseline endpoints.
Six county and regional expected schemas previously held only selected fields;
their complete observed field lists were saved so routine retrieval will not
warn about those already-present fields. **Retain** means the layer has a
defensible use given these dated checks. A later audit may recommend
**replace** or **retire** if a better source is validated or a layer's limits
outweigh its value. The audit does not guarantee future endpoint availability.

| Publisher | Checked ID | Disposition and reason |
| --- | --- | --- |
| Tampa | `construction-permits` | Retain: high-value active permit view; no complete history or exact-service license claimed. |
| Tampa | `development-cases` | Retain: active entitlement applications; not a historical case ledger. |
| Tampa | `capital-projects` | Retain: costs, phases, and dates support infrastructure analysis; document the public-view filter and feet-based CRS. |
| Tampa | `city-boundary` | Retain: useful municipal reference; shoreline-adjusted representation is not a legal survey. |
| Tampa | `neighborhoods` | Retain: civic geography distinct from city limits; public contact fields warrant care. |
| Tampa | `council-districts` | Retain: the [City Council page](https://www.tampa.gov/city-council/about-us) says seats 1–3 are elected at-large citywide, while [layer metadata](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Boundary/MapServer/0?f=pjson) maps only geographic districts 4–7; representative names need current confirmation. |
| Tampa | `riverwalk` | Retain: pedestrian corridor and segment status, distinct from the street network. |
| Tampa | `parks` | Retain: park footprints and ownership; no exact-service license inferred. |
| Tampa | `fire-stations` | Retain: facility locations; not operational status or response coverage. |
| Tampa | `bike-lanes` | Retain: bicycle and shared-route network; some segments are not dedicated lanes. |
| Tampa | `recycling-pickup` | Retain: service-area analysis; verify address-level schedules with the City. |
| Tampa | `community-redevelopment` | Retain: ordinance-linked planning areas. |
| Tampa | `high-injury-network` | Retain: safety-planning network; not a complete crash history. |
| Tampa | `historic-district-local` | Retain: local designation polygons, distinct from landmark points. |
| Tampa | `historic-landmarks-local` | Retain: local designation points; verify legal status with the City. |
| Tampa | `police-districts` | Retain: district geography; not incidents or response coverage. |
| Tampa | `street-speed-reductions` | Retain: source-defined speed policy and dates; not proof of current posted limits. |
| Tampa | `truck-routes` | Retain: freight-routing reference; current restrictions need City confirmation. |
| Tampa | `water-service-area` | Retain: cross-boundary utility geography and a distinct feet-based CRS; not proof of service for an address. |
| Tampa | `zoning-districts` | Retain: core land-use reference; not a legal parcel determination. |
| St. Petersburg | `stpete-parks` | Retain: comparable municipal park footprints. |
| St. Petersburg | `stpete-city-boundary` | Retain: municipal geographic baseline. |
| St. Petersburg | `stpete-streets` | Retain: road-network baseline; restrictions may change. |
| Clearwater | `clearwater-park-buffers` | Retain for park buffer/access analysis, not as park footprints; seek actual footprints separately. [Service item metadata](https://gis.myclearwater.com/arcgis/rest/services/ArcGISMapServices/Clearwater_Park_Buffers/MapServer/info/iteminfo?f=pjson) states no explicit reuse license. |
| Clearwater | `clearwater-zoning` | Retain: cross-city land-use comparison. |
| Clearwater | `clearwater-libraries` | Retain: public facility locations; hours and services require confirmation. |
| Hillsborough | `hillsborough-libraries` | Retain: county cooperative facilities, including partner cities. |
| Hillsborough | `hillsborough-sidewalks` | Retain: pedestrian network with condition and width attributes; accuracy varies. |
| Hillsborough | `hillsborough-parks` | Retain: county-managed park properties, distinct from city parks. |
| Pinellas | `pinellas-fire-stations` | Retain: county-wide facility comparison; status is a source attribute. |
| Pinellas | `pinellas-park-boundaries` | Retain: county parks and preserves; boundaries are planning representations. |
| Pinellas | `pinellas-trail` | Retain: major regional trail asset and condition fields. |
| TBRPC | `tbrpc-developments-of-regional-impact` | Retain as a historical planning snapshot: the [official item](https://www.arcgis.com/home/item.html?id=f0f925147e714beca2ae7b723c5a0e69) was last updated in March 2023 and asks users to confirm source, scale, accuracy, and currentness. |
| TBRPC | `tbrpc-regional-storm-surge-zones` | Retain only as a historical SLOSH planning layer: the [official item](https://www.arcgis.com/home/item.html?id=78308e23f12c411ebbb8cfccc58f5895) was last updated in November 2021, and the layer description says it uses a 2004 shoreline. It is not current emergency guidance; its WKT-only CRS is a useful validation case. |
| TBRPC | `tbrpc-regional-data-centers` | Retain as a timely regional *research inventory*, not an authoritative facility register. The [TBRPC StoryMap](https://storymaps.arcgis.com/stories/9c4da244e480433fbe81a3733bcc41d2) explains its policy purpose and invites corrections. Current service fields include `Data_Source` and `Estimated_Size`; these describe the Council's research, not independent confirmation of each facility. Reassess if the publisher stops maintaining it. |

At the baseline, the registry had no duplicate service/layer combinations. It
had 35 unique IDs and a schema snapshot for each one. That mechanical
consistency is necessary, but does not by itself establish checked status.

## October 2026 catalog decisions

All **35 baseline layers were retained** after review. Clearwater park buffers
and the older TBRPC DRI, storm-surge, and data-center layers have the
strongest cautions; their uses and limits appear above and in registry
`scope_note` values.

The following **17 layers were added**. Scores use the 17-point rubric above;
they are editorial rankings, not a service-quality guarantee. The linked source
items, exact terms, scope notes, and verification dates are recorded in the
bundled registry. Each row gives the main reason for inclusion and its most
important interpretive limit. Rows are grouped by publisher; a higher score
indicates stronger editorial priority within this reviewed shortlist.

| Publisher | Added checked layer | Score | Why it qualifies and what to watch |
| --- | --- | ---: | --- |
| St. Petersburg | [`stpete-zoning-districts`](https://csp.maps.arcgis.com/home/item.html?id=db80bf8cae334213ac59d038482a35ba) | 16 | Adds city zoning to a cross-government comparison; the view has no record-date field and is not a legal determination. |
| St. Petersburg | [`stpete-future-land-use`](https://csp.maps.arcgis.com/home/item.html?id=96965b6e4ad54b438e355e86b8bd8d7b) | 16 | Adds adopted planning classifications distinct from zoning; the view has no record-date field. |
| St. Petersburg | [`stpete-sidewalks`](https://csp.maps.arcgis.com/home/item.html?id=f52c48737a9f4fa9b61c12dac8f980fe) | 16 | Makes mapped pedestrian infrastructure comparable across cities and counties; mapped segments do not guarantee current condition or accessibility. |
| St. Petersburg | [`stpete-public-works-projects`](https://csp.maps.arcgis.com/home/item.html?id=dc7fabd74c6b4d709b9454253c665bfd) | 15 | Adds a mapped capital-project view useful beside Tampa's; the city keeps a separate table for projects without mapped locations. |
| Clearwater | [`clearwater-future-land-use`](https://cityofclearwater.maps.arcgis.com/home/item.html?id=4d25938e0ee4484e822f5ab516507b53) | 16 | Extends land-use comparison across the three cities; the portal item's 2016 modification date does not establish feature freshness. |
| Clearwater | [`clearwater-critical-assets`](https://cityofclearwater.maps.arcgis.com/home/item.html?id=96b0ca177b914f209be21fc99c0ad649) | 14 | Adds a distinct resilience-planning asset view; its 406 modeled polygons are not a complete infrastructure inventory or live emergency guidance. |
| Clearwater | [`clearwater-sidewalks`](https://cityofclearwater.maps.arcgis.com/home/item.html?id=e3b7e675f2b04ec8939226b801bd4fa3) | 15 | Adds city pedestrian segments to regional comparison; source collection began in 2011 and current condition is not assured. |
| Hillsborough County | [`hillsborough-hart-routes`](https://hillsborough.maps.arcgis.com/home/item.html?id=6de4b3ac6ebd4d139edbb5758c2790ec) | 14 | Adds the first checked transit routes; the item cites a March 2025 HART source and is not a live schedule. |
| Hillsborough County | [`hillsborough-fema-flood-zones`](https://hillsborough.maps.arcgis.com/home/item.html?id=eab9b28e7af94f0dbd8eaaacf7c55f0a) | 16 | Adds a recently updated flood-planning layer; use official FEMA and County records for property or legal decisions. |
| Hillsborough County | [`hillsborough-zoning`](https://hillsborough.maps.arcgis.com/home/item.html?id=1b99b0e8d38d4a85916fb9018b8f74c1) | 16 | Adds county zoning to municipal comparisons; it covers unincorporated land and the GIS may lag zoning-atlas actions. |
| Hillsborough County | [`hillsborough-water-quality`](https://hillsborough.maps.arcgis.com/home/item.html?id=04f8f5d7491b4d7aa2aacc6df7ea7f13) | 15 | Adds an environmental monitoring baseline; it shows the latest reviewed station samples, not a complete time series. |
| Hillsborough County | [`hillsborough-land-cover-2023`](https://hillsborough.maps.arcgis.com/home/item.html?id=b2c5c247ca6f482cbf92ea989d90d585) | 14 | Adds a countywide 2023 SWFWMD land-cover snapshot; it is observed classification, not current zoning or future land use. |
| Pinellas County | [`pinellas-countywide-plan`](https://pinellas-egis.maps.arcgis.com/home/item.html?id=c4679b6609234442bbefc3b667725809) | 16 | Adds countywide plan categories for land-use comparison; it is not parcel zoning or a legal survey. |
| Pinellas County | [`pinellas-bicycle-facilities`](https://pinellas-egis.maps.arcgis.com/home/item.html?id=271578471c694165b90b58c868e8a4bb) | 16 | Adds facility classes, widths, and traffic context beyond the checked Pinellas Trail; mapped segments do not prove safety or continuity. |
| Pinellas County | [`pinellas-sidewalks`](https://pinellas-egis.maps.arcgis.com/home/item.html?id=1b7e0d3791d94ffc8e8cadd15b392a37) | 16 | Adds a pedestrian inventory with condition and accessibility attributes; conditions may change on the ground. |
| Pinellas County | [`pinellas-assisted-housing`](https://pinellas-egis.maps.arcgis.com/home/item.html?id=2277d597855b4fba9e4c3e892bc5ddd7) | 15 | Adds the first checked housing program inventory; units, subsidy dates, eligibility, and availability require confirmation. |
| TBRPC | [`tbrpc-regional-boundary`](https://www.arcgis.com/home/item.html?id=ab27e5f7ccd743709ce886988691c6b8) | 14 | Adds a six-county analysis frame derived from 2022 Census geography; it is not a legal boundary survey. |

The following candidates were **not promoted**. They failed a freshness,
source-identity, interpretability, stability, or distinctiveness screen before
full scoring; assigning them a comparable total would imply checks they did
not pass.

| Candidate | Reason to defer or reject |
| --- | --- |
| Older Hillsborough FEMA flood-zone copy | Its data edit date was in 2025; the selected county copy documents a September 2026 revision. |
| HART stops | The layer reported an implausible geographic extent, requiring investigation before a checked snapshot. |
| TBRPC `TESTLiving_Shoreline_Inventory` | Test naming and sparse provenance did not justify a stable checked ID. |
| Older Hillsborough affordable housing | Source scope and update information were too unclear for a maintained housing reference. |
| Pinellas impaired waters | Its 2018 source vintage weakened temporal usefulness beside the selected environmental layers. |
| Pinellas septic inventory | Completeness and privacy questions need resolution first. |
| Older Pinellas storm surge | It added little beyond the already checked, explicitly historical TBRPC surge reference. |
| Clearwater park footprints | No validated public endpoint for the intended footprint layer was found. |
| St. Petersburg fiscal-year dashboard | Its narrow fiscal-year horizon would make the checked ID quickly stale. |

Public layers can still appear through live discovery when indexed; rejection
here is a maintenance decision, not a judgment that the underlying data is
unusable.

## Coverage before and after the catalog review

Each cell gives the **baseline → reviewed** count of checked layers in one
primary registry category. A layer may support several topics, and a nonzero
count does not establish comprehensive, current, or comparable coverage.

| Primary topic | Tampa | St. Pete | Clearwater | Hillsborough | Pinellas | TBRPC |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Boundaries | 3 → 3 | 1 → 1 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 1 |
| Development | 2 → 2 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 | 1 → 1 |
| Environment | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 2 | 0 → 0 | 0 → 0 |
| Hazards | 0 → 0 | 0 → 0 | 0 → 1 | 0 → 1 | 0 → 0 | 1 → 1 |
| Housing | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 1 | 0 → 0 |
| Infrastructure | 2 → 2 | 0 → 1 | 0 → 0 | 0 → 0 | 0 → 0 | 1 → 1 |
| Planning | 4 → 4 | 0 → 2 | 1 → 2 | 0 → 1 | 0 → 1 | 0 → 0 |
| Public facilities | 0 → 0 | 0 → 0 | 1 → 1 | 1 → 1 | 0 → 0 | 0 → 0 |
| Public safety | 2 → 2 | 0 → 0 | 0 → 0 | 0 → 0 | 1 → 1 | 0 → 0 |
| Recreation | 1 → 1 | 1 → 1 | 1 → 1 | 1 → 1 | 2 → 2 | 0 → 0 |
| Solid waste | 1 → 1 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 |
| Transportation | 4 → 4 | 1 → 2 | 0 → 1 | 1 → 2 | 0 → 2 | 0 → 0 |
| Utilities | 1 → 1 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 |
| **Total** | **20 → 20** | **3 → 7** | **3 → 6** | **3 → 8** | **3 → 7** | **3 → 4** |

The topic shift is more specific than the primary categories imply. Comparable
zoning or future-land-use layers now cover Tampa, St. Petersburg, Clearwater,
Hillsborough County, and Pinellas County. Checked bicycle or pedestrian assets
now cover both counties and all three cities, though their inventories use
different definitions. HART routes add transit coverage; Pinellas assisted
housing adds one program inventory; Hillsborough adds water quality, land
cover, and flood zones. The TBRPC boundary gives a six-county reference.

Clearwater's recreation layer is a buffer rather than a park footprint. The
TBRPC infrastructure layer is a research inventory, and its storm-surge layer
is historical. Coverage remains thin for demographics, environmental and flood
data outside Hillsborough, housing outside Pinellas, and transit outside HART.
These gaps remain candidates for live discovery and later editorial review;
they do not justify adding weak checked layers merely to fill cells.

## Maintenance workflow

1. Search the configured publishers with `tbod_discover()` and the relevant
   portal. Check the publisher's item page, REST metadata, source URL, reuse
   statement, scope, and update claims. For a candidate layer, run
   `Rscript tools/prepare-checked-candidate.R <layer-url> <jurisdiction> <slug>`
   from the package root after installing the current source. This live-only
   helper saves a draft schema, incomplete registry entry, and validation
   evidence under ignored `.research/checked-candidates/`; it changes no
   checked registry files.
2. Score candidates and record why each adds useful coverage. Compare with
   existing checked layers and document candidates rejected after review.
3. Validate endpoint, `Query`, fields and types, object ID, geometry, CRS,
   date fields, count, full object-ID list, pagination, provenance, terms, and
   a bounded retrieval. Exercise `tbod_get_dataset()`, `tbod_schema()`, and
   `tbod_check_schema()`. The helper exercises object-ID batching and, when
   advertised, ordered pagination on
   up to two rows; review its report before claiming broader compatibility.
4. Generate a dated schema snapshot from the inspected metadata, then add the
   registry entry, source and terms URLs, verification date, and `scope_note`.
   Keep the registry and snapshot in sync.
5. Run offline catalog invariants and retrieval fixtures; run separate opt-in
   live checks for availability, schema drift, and bounded result integrity.
   Keep live endpoint checks outside ordinary offline `R CMD check`.
6. Review warnings and failures against publisher metadata. Refresh a
   snapshot only after understanding the change; do not hide drift by merely
   replacing the saved schema.
7. Retire an obsolete or misleading checked entry, or replace it with a
   better-validated layer. Keep a dated decision record and update the
   coverage table, examples, and monitoring lists.

See [architecture](architecture.md), [coverage](../vignettes/coverage.Rmd), and
the [test guide](../tests/README.md) for implementation and test boundaries.

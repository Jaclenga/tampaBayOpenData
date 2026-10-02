# City of Tampa source research

The 2026-09-29 audit selected eight City-published ArcGIS layers. Counts,
capabilities, fields, terms, and access findings below describe the checks on
2026-09-29, not current service guarantees. The shipped
[`datasets.json`](../inst/extdata/datasets.json) holds package metadata and
scope notes; package IDs are not City-assigned identifiers.

## 2026-09-29 publisher and selected layers

The [City GIS page](https://www.tampa.gov/technology-and-innovation/geographic-information-systems)
links its [GeoHub](https://city-tampa.opendata.arcgis.com/) and maps gallery.
The [organization record](https://tampa.maps.arcgis.com/sharing/rest/portals/self?f=pjson)
identifies City of Tampa as publisher. Its [REST directory](https://arcgis.tampagov.net/arcgis/rest/services?f=pjson)
exposes both FeatureServer and queryable MapServer layers. Some public catalog
items label a layer as a feature service while its URL points to a MapServer;
the registry therefore records the exact service root and layer number.

| Package ID | City layer | Geometry | Native EPSG | Rows observed | Public item terms |
| --- | --- | --- | ---: | ---: | --- |
| `construction-permits` | [PermitsAll/0](https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer/0?f=pjson) | Point | 3857 | 2,594 | No exact item license found |
| `development-cases` | [ActiveEntitlementLocations/0](https://arcgis.tampagov.net/arcgis/rest/services/Planning/ActiveEntitlementLocations/FeatureServer/0?f=pjson) | Point | 3857 | 287 | No exact item license found |
| `capital-projects` | [CapitalProjects/0](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/CapitalProjects/MapServer/0?f=pjson) | Point | 6443 | 193 | [CC0](https://www.arcgis.com/sharing/rest/content/items/2226a20de08641e38cedd1c2d7cac69e?f=pjson) |
| `city-boundary` | [Boundary/6](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Boundary/MapServer/6?f=pjson) | Polygon | 3857 | 1 | [CC0](https://www.arcgis.com/sharing/rest/content/items/ed03de89b95340359431d13bd2bc38f2?f=pjson) |
| `neighborhoods` | [Boundary/5](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Boundary/MapServer/5?f=pjson) | Polygon | 3857 | 160 | [CC0](https://www.arcgis.com/sharing/rest/content/items/4735bb6a3c564b2f900d63877dac28f3?f=pjson) |
| `council-districts` | [Boundary/0](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Boundary/MapServer/0?f=pjson) | Polygon | 3857 | 4 | [CC0](https://www.arcgis.com/sharing/rest/content/items/8a45d0b08d774a9b844acc2f4a6d2e41?f=pjson) |
| `riverwalk` | [Planning/4](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Planning/MapServer/4?f=pjson) | Line | 3857 | 21 | [CC0](https://www.arcgis.com/sharing/rest/content/items/94f4fa3121bf4a6a82aee97b5f1d77d4?f=pjson) |
| `parks` | [Location/10](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Location/MapServer/10?f=pjson) | Polygon | 3857 | 208 | [CC0](https://www.arcgis.com/sharing/rest/content/items/a8488dc7a4fa4cc5a7dcc4f3840d307a?f=pjson) |

All eight layers advertised Query, ordering, offset pagination, and a
2,000-feature `maxRecordCount`. Each count query, two ordered one-row pages,
an empty query, and a spatial query with `outSR=4326` succeeded without a
token. The boundary's second page was empty because it had one feature.
Permits exceeded one page. These checks establish basic access and pagination
behavior, not a frozen snapshot of changing data.

All selected schemas identified `OBJECTID` as the OID. The MapServer layers
omitted a top-level `objectIdField`, so the OID must also be found from field
types. Most layers advertised ArcGIS `wkid` 102100 / `latestWkid` 3857.
Capital projects advertised 103023 / 6443, in feet; a single CRS cannot be
assumed for the catalog.

## Fields, dates, and scope

Source field names are case sensitive. Permit filters use `PROJECTSTATUS`,
not `STATUS`; `LASTUPDATE` and `CREATEDDATE` are declared dates. The active
development layer's `TENTATIVEHEARING` and `TENTATIVETIME` are strings.
ArcGIS JSON date values were observed as epoch milliseconds. Permit and active
development metadata declare `America/New_York` with daylight saving rules;
the selected MapServer layers omit a specific time reference but state that
dates are not in an unknown time zone. No selected layer exposed
`editingInfo.lastEditDate`; public item modification times do not measure
feature freshness. The [permit service](https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer?f=pjson)
described daily updates; no frequency was verified for the other layers.

Important source limits:

- `construction-permits` is the public PermitsAll layer for an active-permits
  viewer. Its name does not prove a complete historical ledger, and no permit
  issue-date field was advertised.
- `development-cases` contains active entitlement locations, not every
  historical application or full Accela record. The
  [City development page](https://www.tampa.gov/development-coordination)
  links the current applications map.
- `capital-projects` is a public-facing view. The service description mentions
  a public-only definition query and contains “Dashboard Test” wording;
  the layer metadata did not expose that expression.
- `city-boundary` follows the shoreline rather than the full legal limit.
  `neighborhoods` maps associations, not a guaranteed partition of the city.
  `parks` includes ownership and public-access attributes; City publication
  does not imply City ownership of every feature.
- The ConstructionInspections service exposed permit-like point schemas, with
  no verified inspection event, result, or date fields. An inspections wrapper
  would imply unsupported semantics. A separate road centerline layer covered
  other jurisdictions and was excluded from this City-focused release.

## Terms and access

The six MapServer-backed public items in the table stated CC0 in their
`licenseInfo`. The exact permit and development FeatureServer iteminfo had
empty `licenseInfo`; a separate MapServer item's CC0 statement and the GeoHub
site item's CC-BY-SA statement cannot be assigned to them. The
[City Conditions and Use](https://www.tampa.gov/about-us/tampagov/conditions-and-use)
generally allows copying public system data with specified exceptions, and
disclaims accuracy, completeness, and official status for mapping. The package
records published terms without assigning a new dataset license.

During the audit, one web route redirected to a City geographic-access notice,
while direct API calls from the local environment succeeded. Availability can
vary by network. The client treats non-JSON responses, including an HTML page
with HTTP 200, as upstream errors rather than empty data.

The local [harvest script](../.research/tampa-harvest.py),
[candidate record](../.research/tampa-candidates.json), and
`.research/tampa/raw/` retain full schemas, query URLs, statuses, and source
metadata for the September audit. They are development evidence excluded from
package builds; no bulk government dataset is shipped.

## 2026-10-02 additions

Three more public City layers were checked through their ArcGIS JSON metadata,
count, and object-ID endpoints. Counts can change. Each layer advertised Query
and a 2,000-feature `maxRecordCount`.

| Package ID | City layer | Public item terms | Geometry | EPSG | Rows observed | Order/offset pagination |
| --- | --- | --- | --- | ---: | ---: | --- |
| `fire-stations` | [Location/1](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Location/MapServer/1?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/c35091a5fb9a4e69986e8a2382c9939c?f=pjson) | Point | 3857 | 28 | No |
| `bike-lanes` | [Transportation/0](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Transportation/MapServer/0?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/d54aac9d4559488fa439e454df5f09ce?f=pjson) | Line | 3857 | 6,858 | Yes |
| `recycling-pickup` | [SolidWaste/3](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/SolidWaste/MapServer/3?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/4613a763db274503ae76440167cd80d8?f=pjson) | Polygon | 3857 | 65 | Yes |

All three public items belong to the City's `PublicInfo_TampaGIS` account and
state CC0 in `licenseInfo`. Their layer metadata reports source WKID 2237 and
spatial reference WKID 102100 (latest WKID 3857). None declares a specific
date time reference, and all set `datesInUnknownTimezone = false`. The
fire-station layer is a joined view with qualified source field names and
OID `GIS.FacilitySitePoint.OBJECTID`. It does not advertise ordering or offset
pagination. Count, object-ID manifest, and object-ID batch queries succeeded.
The other two layers use `OBJECTID`. Their complete ID manifests matched counts,
and separate ordered one-row pages returned distinct records with WGS 84
geometry.

Declared date fields are `GIS.FacilitySitePoint.LASTUPDATE` and
`GIS.GovServiceInfo.LASTUPDATE` for fire stations; `INSTALLDATE`, `CREATEDDATE`,
and `LASTUPDATE` for bicycle segments; and `LASTUPDATE` for recycling areas.

`fire-stations` maps locations, not current operating status or response
coverage. `bike-lanes` includes shared roads, paths, and trails, so not every
line is a dedicated lane. `recycling-pickup` maps schedule service areas, not
a guaranteed current pickup day for an address. City item modification dates
do not establish feature freshness.

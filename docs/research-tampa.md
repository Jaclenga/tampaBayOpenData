# City of Tampa source research

The curated catalog contains 20 City-published ArcGIS layers: eight originally
checked on 2026-09-29 and twelve added after checks on 2026-10-02. The parks
endpoint was also updated on 2026-10-02. Counts, capabilities,
fields, terms, and access findings below describe those dated checks, not
current service guarantees. The shipped
[`datasets.json`](../inst/extdata/datasets.json) holds package metadata and
scope notes; package IDs are not City-assigned identifiers.
The `jurisdiction = "tampa"` option identifies the publisher, not a strict
geographic extent; the water service area extends beyond City limits.

## Publisher and selected layers

The [City GIS page](https://www.tampa.gov/technology-and-innovation/geographic-information-systems)
links its [GeoHub](https://city-tampa.opendata.arcgis.com/) and maps gallery.
The [organization record](https://tampa.maps.arcgis.com/sharing/rest/portals/self?f=pjson)
identifies City of Tampa as publisher. Its [REST directory](https://arcgis.tampagov.net/arcgis/rest/services?f=pjson)
exposes both FeatureServer and queryable MapServer layers. Some public catalog
items label a layer as a feature service while its URL points to a MapServer;
the registry therefore records the exact service root and layer number. The
table shows current package endpoints; seven were first checked on September
29, and the replacement parks endpoint was checked on October 2.

| Package ID | City layer | Geometry | Native EPSG | Rows observed | Public item terms |
| --- | --- | --- | ---: | ---: | --- |
| `construction-permits` | [PermitsAll/0](https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer/0?f=pjson) | Point | 3857 | 2,594 | No exact item license found |
| `development-cases` | [ActiveEntitlementLocations/0](https://arcgis.tampagov.net/arcgis/rest/services/Planning/ActiveEntitlementLocations/FeatureServer/0?f=pjson) | Point | 3857 | 287 | No exact item license found |
| `capital-projects` | [CapitalProjects/0](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/CapitalProjects/MapServer/0?f=pjson) | Point | 6443 | 193 | [CC0](https://www.arcgis.com/sharing/rest/content/items/2226a20de08641e38cedd1c2d7cac69e?f=pjson) |
| `city-boundary` | [Boundary/6](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Boundary/MapServer/6?f=pjson) | Polygon | 3857 | 1 | [CC0](https://www.arcgis.com/sharing/rest/content/items/ed03de89b95340359431d13bd2bc38f2?f=pjson) |
| `neighborhoods` | [Boundary/5](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Boundary/MapServer/5?f=pjson) | Polygon | 3857 | 160 | [CC0](https://www.arcgis.com/sharing/rest/content/items/4735bb6a3c564b2f900d63877dac28f3?f=pjson) |
| `council-districts` | [Boundary/0](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Boundary/MapServer/0?f=pjson) | Polygon | 3857 | 4 | [CC0](https://www.arcgis.com/sharing/rest/content/items/8a45d0b08d774a9b844acc2f4a6d2e41?f=pjson) |
| `riverwalk` | [Planning/4](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Planning/MapServer/4?f=pjson) | Line | 3857 | 21 | [CC0](https://www.arcgis.com/sharing/rest/content/items/94f4fa3121bf4a6a82aee97b5f1d77d4?f=pjson) |
| `parks` | [ParksPolygons/0](https://arcgis.tampagov.net/arcgis/rest/services/Parks/ParksPolygons/MapServer/0?f=pjson) | Polygon | 3857 | 208 | No exact item license found |

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

### 2026-10-02 `parks` endpoint update

The package now queries the City's [ParksPolygons/MapServer/0](https://arcgis.tampagov.net/arcgis/rest/services/Parks/ParksPolygons/MapServer/0?f=pjson).
The original [Location/10](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Location/MapServer/10?f=pjson)
selection remains available as a separate endpoint.
Both layers returned 208 features with the same complete set of 208 unique
object IDs. `OBJECTID`, `GlobalID`, `PARKNAME`, `ACRES`, and `LASTUPDATE`
matched across all 208 records. The first projected polygon and its selected
attributes matched as well. The replacement returned two distinct ordered
one-row pages and EPSG:4326 geometry; it adds a `LASTEDITOR` field. During a
later three-ID geometry comparison, Location/10 returned ArcGIS error 400,
while the replacement returned all three records. A complete 208-row spatial
retrieval through `get_dataset()` succeeded in 50-row pages. The
[replacement service iteminfo](https://arcgis.tampagov.net/arcgis/rest/services/Parks/ParksPolygons/MapServer/info/iteminfo?f=pjson)
identifies City of Tampa in its access information but has empty
`licenseInfo`. The older [Location/10 public item](https://www.arcgis.com/sharing/rest/content/items/a8488dc7a4fa4cc5a7dcc4f3840d307a?f=pjson)
states CC0, but its license is not assigned to the replacement endpoint in the
package catalog.

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

Five MapServer-backed public items in the table stated CC0 in their
`licenseInfo`. The exact permit and development FeatureServer iteminfo and the
replacement parks MapServer iteminfo had empty `licenseInfo`; separate item
license statements cannot be assigned to them. The
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
| `fire-stations` | [Fire/10](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Fire/MapServer/10?f=pjson) | [Layer iteminfo: no access and use limitations](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Fire/MapServer/10/iteminfo?f=pjson) | Point | 3857 | 28 | Yes |
| `bike-lanes` | [Transportation/0](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Transportation/MapServer/0?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/d54aac9d4559488fa439e454df5f09ce?f=pjson) | Line | 3857 | 6,858 | Yes |
| `recycling-pickup` | [SolidWaste/3](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/SolidWaste/MapServer/3?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/4613a763db274503ae76440167cd80d8?f=pjson) | Polygon | 3857 | 65 | Yes |

The bicycle and recycling public items belong to the City's
`PublicInfo_TampaGIS` account and state CC0. The selected Fire/10 layer has no
verified public item with a CC0 designation; its own iteminfo says there are
no access and use limitations. All three layers report source WKID 2237 and
spatial reference WKID 102100 (latest WKID 3857). None declares a specific
date time reference, and all set `datesInUnknownTimezone = false`. The three
selected layers use `OBJECTID`; complete ID manifests matched counts, and
separate ordered one-row pages returned distinct records with WGS 84 geometry.

The initial `fire-stations` source, [Location/1](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Location/MapServer/1?f=pjson),
is a joined view that intermittently returned ArcGIS 400 during retrieval.
The replacement [Fire/10](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Fire/MapServer/10?f=pjson)
has the same 28 object IDs. A checked station (ID 215337) had the same name
and WGS 84 coordinates in both layers. Fire/10 is an unjoined base layer and
supports ordering and offset pagination. Its fields are unqualified (for
example, `NAME` rather than `GIS.FacilitySitePoint.NAME`), and the joined
`GIS.GovServiceInfo.*` fields are absent. Existing code requesting either
qualified field family must change; the package does not invent missing
joined attributes.

Declared date fields are `LASTUPDATE` for fire stations; `INSTALLDATE`, `CREATEDDATE`,
and `LASTUPDATE` for bicycle segments; and `LASTUPDATE` for recycling areas.

`fire-stations` maps locations, not current operating status or response
coverage. `bike-lanes` includes shared roads, paths, and trails, so not every
line is a dedicated lane. `recycling-pickup` maps schedule service areas, not
a guaranteed current pickup day for an address. City item modification dates
do not establish feature freshness.

## 2026-10-02 further additions

Nine more City MapServer layers passed public metadata, count, complete
object-ID manifest, and one-feature WGS 84 geometry queries. Each advertised
Query, ordering, offset pagination, and a 2,000-feature `maxRecordCount`;
distinct ordered first and second pages were also checked. The row counts are
observations from that date, not fixed catalog properties.

| Package ID | City layer | Public item terms | Geometry | Layer EPSG | Rows observed |
| --- | --- | --- | --- | ---: | ---: |
| `community-redevelopment` | [Planning/0](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Planning/MapServer/0?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/f7e626e1cc4f4661880200fce38df2e4?f=pjson) | Polygon | 3857 | 10 |
| `high-injury-network` | [Transportation/10](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Transportation/MapServer/10?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/26f3a52af49840fd8192017fbf0a948b?f=pjson) | Line | 3857 | 55 |
| `historic-district-local` | [Planning/1](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Planning/MapServer/1?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/cdb8c1ac06c64b0c8ef81dd79957fd43?f=pjson) | Polygon | 3857 | 4 |
| `historic-landmarks-local` | [Planning/29](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Planning/MapServer/29?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/57cc463185ba4c928024ed0231c83c01?f=pjson) | Point | 3857 | 106 |
| `police-districts` | [LawEnforcement/1](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/LawEnforcement/MapServer/1?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/41ac9e149731446f9c2f4287370fc94d?f=pjson) | Polygon | 3857 | 3 |
| `street-speed-reductions` | [Transportation/4](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Transportation/MapServer/4?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/be693f2c9624459bb11d1a90f53bca27?f=pjson) | Line | 3857 | 112 |
| `truck-routes` | [Transportation/5](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Transportation/MapServer/5?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/4b5e9c1f1d234b8aaa49e1c01631f7a0?f=pjson) | Line | 3857 | 2,527 |
| `water-service-area` | [UtilityWater/1](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/UtilityWater/MapServer/1?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/1737b1233358432a93efb61663e3919c?f=pjson) | Polygon | 2237 | 6 |
| `zoning-districts` | [Planning/28](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Planning/MapServer/28?f=pjson) | [CC0](https://www.arcgis.com/sharing/rest/content/items/4998fcab196544d789e38cde69a84217?f=pjson) | Polygon | 3857 | 3,933 |

All nine public item records state CC0, though the water item's `licenseInfo`
wraps the text in HTML. The water service area advertises EPSG:2237; the other
eight advertise EPSG:3857. Their source date metadata does not establish when
individual features were last checked. Item update and refresh statements do
not prove feature freshness.

These are mapped areas and segments, not legal or operational determinations.
Local historic designations and zoning should be checked against current City
records before use in a decision. `high-injury-network` describes a published
network; it does not measure current safety at every location. The street speed
layer includes a status field, so a mapped segment alone does not establish its
current posted limit. The water service area extends beyond City boundaries;
City publication does not make every mapped parcel part of the City.

Three other candidates, [Location/6](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Location/MapServer/6?f=pjson),
[Location/9](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Location/MapServer/9?f=pjson),
and [Location/11](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Location/MapServer/11?f=pjson),
were excluded. Their metadata advertised Query, but count, ID, and feature
requests returned ArcGIS 400 errors during the October 2 check.

## Live discovery sources (2026-10-02)

The package's live search uses Esri's public [item search API](https://developers.arcgis.com/rest/users-groups-and-items/search/)
for the [City of Tampa organization](https://www.arcgis.com/sharing/rest/portals/IbNXlmt2RVVRCZ6M?f=json)
(`IbNXlmt2RVVRCZ6M`) and the [Tampa Bay Regional Planning Council
organization](https://www.arcgis.com/sharing/rest/portals/RgIBbQIF0Y6T3AX6?f=json)
(`RgIBbQIF0Y6T3AX6`). The October 2 scan searched public `Feature Service`
items, followed `nextStart` pages, and expanded service roots into candidate
feature layers and tables. Some items typed `Feature Service` pointed to a
MapServer layer. `Map Service` items found in those two organizations at the
time were tile services. The current client searches both item types, then
inspects each layer's own metadata for type, geometry, and Query capability;
it skips tile services without queryable layers. A direct compatible MapServer
layer can also be retrieved by URL.

That Feature Service scan found 163 City and 95 regional service items. Expanding
them produced 323 distinct layer URLs (166 City, 157 regional); one
City item pointed to a service that returned HTTP 403 and was recorded as a
skipped-item issue. These are live observations, not a fixed catalog size.
Duplicate portal items can point to the same layer URL, so the package uses
service URL plus layer ID for dataset identity and chooses one exact item for
item metadata. It does not combine terms or infer a license from a duplicate
item. Item titles are not stable keys; discovered IDs contain the ArcGIS item
ID and layer ID.

The [City GeoHub dataset search](https://city-tampa.opendata.arcgis.com/api/search/v1/collections/dataset/items)
listed 133 items during this check, a subset of the City organization search.
The [regional GeoHub](https://opendata-tbrpc.hub.arcgis.com/api/search/v1/collections/dataset/items)
listed five. Only 16 of the 20 checked City layer endpoints appeared in the
City organization results. The package therefore unions its checked registry
with live discovery; `construction-permits`, `development-cases`, `parks`, and
`fire-stations` remain available under their checked IDs. Portal indexing,
deleted items, or changed service permissions can affect future results.

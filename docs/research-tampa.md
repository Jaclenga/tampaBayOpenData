# City of Tampa public-data research

Verified on 2026-09-29 against public City endpoints. This report preceded the client implementation. The scope is City of Tampa publication infrastructure and eight selected datasets; other governments are not implemented.

## Authoritative infrastructure

The [City GIS page](https://www.tampa.gov/technology-and-innovation/geographic-information-systems) links its Data Download action to the [City of Tampa GeoHub](https://city-tampa.opendata.arcgis.com/) and its map gallery to `tampa.maps.arcgis.com`. The [organization metadata](https://tampa.maps.arcgis.com/sharing/rest/portals/self?f=pjson) identifies that organization as City of Tampa, public access, organization ID `IbNXlmt2RVVRCZ6M`. This connection establishes publisher provenance; an arbitrary ArcGIS item with “Tampa” in its title does not.

The [REST service directory](https://arcgis.tampagov.net/arcgis/rest/services?f=pjson) reports ArcGIS Server 11.5. Its [OpenData folder](https://arcgis.tampagov.net/arcgis/rest/services/OpenData?f=pjson) contains queryable MapServer layers for boundaries, locations, capital projects, planning, streets, transportation, and utilities. Its [Planning folder](https://arcgis.tampagov.net/arcgis/rest/services/Planning?f=pjson) also exposes FeatureServers, including `PermitsAll`, `ActiveEntitlementLocations`, and `ConstructionInspections`.

**Implementation decision:** use a generic ArcGIS layer query client that accepts either `FeatureServer` or `MapServer`. ArcGIS Online labels several selected public catalog entries “Feature Service” even though their `url` points to a `MapServer/<layer>` endpoint. Selecting the transport by item type would be incorrect. A registry entry must retain the exact service root and numeric layer ID.

The GeoHub site is a JavaScript application. Its [public site item](https://www.arcgis.com/sharing/rest/content/items/316ee3c5e5ef40bc84694258182d94f3?f=pjson) and [configuration data](https://www.arcgis.com/sharing/rest/content/items/316ee3c5e5ef40bc84694258182d94f3/data?f=pjson) can be read through the ArcGIS API; no scraping of rendered catalog results is needed. The public organization search returned 163 Feature Service / Map Service items during this audit. This is an observed catalog count, not a supported-dataset count or a promise of future availability.

## Eight selected datasets

`inst/extdata/datasets.json` is the shipped registry. IDs below are stable package identifiers assigned to verified upstream layers, not claims that Tampa publishes those slugs. URLs in the table link the exact authoritative layer, making the layer number explicit.

| Package ID | Authoritative layer | Geometry | Advertised CRS (`wkid` / `latestWkid`) | Rows observed |
| --- | --- | --- | --- | ---: |
| `construction-permits` | [Planning/PermitsAll/FeatureServer/0](https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer/0?f=pjson) | Point | 102100 / 3857 | 2,594 |
| `development-cases` | [Planning/ActiveEntitlementLocations/FeatureServer/0](https://arcgis.tampagov.net/arcgis/rest/services/Planning/ActiveEntitlementLocations/FeatureServer/0?f=pjson) | Point | 102100 / 3857 | 287 |
| `capital-projects` | [OpenData/CapitalProjects/MapServer/0](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/CapitalProjects/MapServer/0?f=pjson) | Point | 103023 / 6443 | 193 |
| `city-boundary` | [OpenData/Boundary/MapServer/6](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Boundary/MapServer/6?f=pjson) | Polygon | 102100 / 3857 | 1 |
| `neighborhoods` | [OpenData/Boundary/MapServer/5](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Boundary/MapServer/5?f=pjson) | Polygon | 102100 / 3857 | 160 |
| `council-districts` | [OpenData/Boundary/MapServer/0](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Boundary/MapServer/0?f=pjson) | Polygon | 102100 / 3857 | 4 |
| `riverwalk` | [OpenData/Planning/MapServer/4](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Planning/MapServer/4?f=pjson) | Polyline | 102100 / 3857 | 21 |
| `parks` | [OpenData/Location/MapServer/10](https://arcgis.tampagov.net/arcgis/rest/services/OpenData/Location/MapServer/10?f=pjson) | Polygon | 102100 / 3857 | 208 |

Each layer advertises `maxRecordCount = 2000`, Query capability, ordered queries, pagination, and JSON / GeoJSON / PBF query formats. The FeatureServer service roots advertise only JSON while their individual layers advertise additional formats; layer metadata is the relevant source for a layer query. Ordinary retrieval should use JSON and interpret the ArcGIS schema directly.

The audit sent `where=1=1&returnCountOnly=true`, two ordered one-record queries at offsets zero and one, and an empty `where=1=0` query to every selected layer. All succeeded without an access token. Distinct object IDs were observed at successive offsets for every layer with more than one record; the boundary returned one record then an empty second page. Every empty query returned a feature array with zero entries. Every first spatial sample accepted `outSR=4326` and declared that spatial reference in its response. The permit layer exceeds its 2,000-feature limit, so pagination is required for a complete default retrieval. These checks verify the endpoint and basic offset behavior; they do not claim a transactionally consistent snapshot while source data changes.

## Verified field and update metadata

Names are case-sensitive source schema names. The package should preserve them. Examples should use `PROJECTSTATUS = 'Issued'`, not an invented `STATUS` field, for the permit layer.

| Dataset | Useful advertised attributes | Fields typed `esriFieldTypeDate` |
| --- | --- | --- |
| Permits | `RECORD_ID`, `PROJECTSTATUS`, `PROJECTDESCRIPTION`, `ADDRESS`, `RECORDTYPE`, `OCCUPANCYTYPE`, `NBROFUNITS`, `URL` | `LASTUPDATE`, `CREATEDDATE` |
| Active development | `RECORDID`, `APPSTATUS`, `RECORDALIAS`, `ADDRESS`, `TENTATIVEHEARING`, `TENTATIVETIME`, `URL` | `CREATEDDATE`, `LASTUPDATE` |
| Capital projects | `projid`, `projname`, `projdesc`, `projphase`, `status`, `estcost`, `actcost`, `ShowPublic` | `planstart`, `planend`, `actstart`, `actend`, `CreationDate`, `EditDate`, `created_date`, `last_edited_date` |
| Shoreline boundary | `ID`, `Municipality` | `LASTUPDATE`, `created_date` |
| Neighborhood associations | `Association`, `AssocLabel`, `Description`, `NEIGHSTATUS`, `MEETING_INFO` | `created_date`, `last_edited_date`, `ContactUpdated` |
| Council districts | `DISTRICTID`, `NAME`, `REPNAME`, `DISTRICTURL` | `LASTUPDATE` |
| Riverwalk | `STATUS`, `NAME` | `LASTUPDATE` |
| Parks | `FACILITYID`, `PARKNAME`, `PARKTYPE`, `OWNER`, `OWNERTYPE`, `SITADDR`, `ACRES`, `PUBLIC_` | `LASTUPDATE` |

All selected layers have an `OBJECTID` OID field. FeatureServer metadata declares `objectIdField`; the selected MapServer metadata lacks that top-level property, so the client should find the field typed `esriFieldTypeOID`. The source may expose geometry and computed measurement fields with punctuation such as `SHAPE.STArea()`; do not rename them or mistake the geometry field for a normal string column.

ArcGIS JSON Date values were observed as epoch milliseconds, including missing values. Permits and active development explicitly declare Eastern Standard Time, `America/New_York`, and daylight-saving observance in `dateFieldsTimeReference`. Preserve the numeric timestamp instant when converting to `POSIXct`; retain the source time-reference metadata for interpreting SQL date literals. A string such as `TENTATIVEHEARING` must remain a string even though its name sounds like a date. The selected MapServer layers report `datesInUnknownTimezone = false` but omit a specific time-reference object; do not invent a local zone for them.

The [permit service description](https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer?f=pjson) states daily updates. No corresponding verified update-frequency guarantee was found for the other selected layers. Selected layer metadata does not expose an `editingInfo.lastEditDate` timestamp. The public ArcGIS item `modified` values below are metadata item timestamps; they must not be presented as feature modification times or freshness guarantees.

| Dataset | ArcGIS public item | Item modified (UTC) | Exact item licenseInfo |
| --- | --- | --- | --- |
| Permits FeatureServer | No exact public organization item match found | Unknown | Empty service iteminfo licenseInfo |
| Active development FeatureServer | No exact public organization item match found | Unknown | Empty service iteminfo licenseInfo |
| Capital projects | [2226a20de08641e38cedd1c2d7cac69e](https://www.arcgis.com/sharing/rest/content/items/2226a20de08641e38cedd1c2d7cac69e?f=pjson) | 2024-12-18 19:31:02 | CC0, wrapped in HTML |
| Shoreline boundary | [ed03de89b95340359431d13bd2bc38f2](https://www.arcgis.com/sharing/rest/content/items/ed03de89b95340359431d13bd2bc38f2?f=pjson) | 2026-02-09 19:06:24 | CC0 |
| Neighborhoods | [4735bb6a3c564b2f900d63877dac28f3](https://www.arcgis.com/sharing/rest/content/items/4735bb6a3c564b2f900d63877dac28f3?f=pjson) | 2026-02-09 19:12:00 | CC0 |
| Council districts | [8a45d0b08d774a9b844acc2f4a6d2e41](https://www.arcgis.com/sharing/rest/content/items/8a45d0b08d774a9b844acc2f4a6d2e41?f=pjson) | 2018-03-05 18:50:01 | CC0 |
| Riverwalk | [94f4fa3121bf4a6a82aee97b5f1d77d4](https://www.arcgis.com/sharing/rest/content/items/94f4fa3121bf4a6a82aee97b5f1d77d4?f=pjson) | 2018-03-05 19:09:25 | CC0 |
| Parks | [a8488dc7a4fa4cc5a7dcc4f3840d307a](https://www.arcgis.com/sharing/rest/content/items/a8488dc7a4fa4cc5a7dcc4f3840d307a?f=pjson) | 2018-03-05 19:01:22 | CC0 |

## Scope and inconsistencies

- **Permits:** the source layer is named `Permits` and the service describes an active-permits viewer. An endpoint named `PermitsAll` does not prove a complete historical construction archive. The package ID `construction-permits` is a usability choice with this qualification visible in its title, description, and scope note. There is no advertised issue-date field.
- **Development:** the source is active entitlement locations, not all historical cases or an entire Accela record. The [City Development Coordination page](https://www.tampa.gov/development-coordination) links the public current-applications map.
- **Capital projects:** the service description mentions a public-only definition query and contains “Dashboard Test” wording, while the public catalog item identifies City capital improvement projects. The registry preserves the public endpoint and that caveat. Its native CRS differs from the other selected datasets: ArcGIS 103023 / EPSG 6443, feet.
- **Boundary:** this polygon follows the shoreline. It is not the full legal incorporated limit extending into the bays.
- **Neighborhoods:** these are neighborhood association boundaries. Source attributes include association contact details; retrieval should preserve source values and add no contact enrichment.
- **Parks:** City publication does not prove City ownership of every feature. Source ownership and public-access fields remain available.
- **Descriptions:** the OpenData Planning service description mentions law enforcement, and the ConstructionInspections service-level `description` claims zoning. Layer metadata and actual field schemas are more informative than these copied descriptions.
- **Inspections:** the ConstructionInspections FeatureServer has Commercial, Townhouses, and Residential point layers with the same permit attributes as PermitsAll. No inspection-event, inspection-result, or inspection-date field was verified. A `get_inspections()` function would imply unsupported semantics, so it is excluded.
- **Roads:** the verified OpenData Road Centerline layer explicitly covers Tampa, unincorporated Hillsborough County, Plant City, and Temple Terrace. It is excluded from this small City-focused release; Riverwalk supplies a clearly City-specific line dataset without a hidden spatial filter.

## Terms, access, and reliability

The selected public catalog item metadata explicitly states CC0 for the six MapServer-backed datasets. The exact permit and active-entitlement FeatureServer service iteminfo documents have empty `licenseInfo`. A separate public Development Coordination Locations MapServer item states CC0, but its terms should not silently be transferred to a different endpoint. The GeoHub site's own item states CC-BY-SA and its site configuration contains a copyright footer. Site-item terms are not a dataset license. Preserve this distinction in metadata and documentation.

The [City Conditions and Use](https://www.tampa.gov/about-us/tampagov/conditions-and-use) generally permits copying or distributing public system data, identifies exceptions such as protected artwork and the City seal, and disclaims assurances of accuracy, completeness, and adequacy. It describes mapping as a representation and directs users needing official evidence to underlying records. The registry links these published conditions and reports exact item terms where available; it does not create a legal interpretation or relabel the package as the data publisher.

Access is not universally available from every network. During web research an OpenData URL redirected to the City's [outside-the-US / VPN notice](https://www.tampa.gov/it-looks-youre-trying-connect-outside-united-states), which says access is geographically limited. Direct public API calls from the local environment subsequently succeeded. The HTTP client must therefore recognize non-JSON HTML, including a geographic-access page returned with HTTP 200, as an informative upstream failure. It should never treat that body as an empty dataset or advise evasion of access controls.

Pagination must follow service limits, order by the source OID, check transfer-limit indications, and detect duplicate or stalled pages. A read against a changing service is not guaranteed to be a snapshot: newly inserted or deleted records can affect counts and offsets. A bounded `limit` should be distinguished from an accidental partial result in provenance. Unknown geometry or CRS should produce an explicit error rather than an invented CRS. Esri point `x/y`, line `paths`, and polygon `rings` were observed in successful queries; parsing needs to support multiple paths/rings and missing geometries beyond these small live samples.

The reproducible research script and raw evidence are retained locally under `.research/tampa-harvest.py`, `.research/tampa-candidates.json`, and `.research/tampa/raw/`. These include every complete field schema, exact query URL, HTTP status, observed dates, and source metadata. They are development evidence, not a hosted government data copy, and are excluded from package builds. The shipped registry contains publication metadata only.

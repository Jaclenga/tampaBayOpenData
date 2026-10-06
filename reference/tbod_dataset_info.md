# Inspect a dataset and its source

Inspects a bundled, discovered, or direct ArcGIS dataset. Use
[`tbod_schema`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_schema.md)
to inspect expected or current fields and
[`tbod_check_schema`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_check_schema.md)
to compare them.

## Usage

``` r
tbod_dataset_info(
  id, jurisdiction = NULL, refresh = FALSE, timeout = 30,
  total_timeout = 60, portal = NULL
)
```

## Arguments

- id:

  Bundled ID, one-row discovery result, stable ArcGIS ID, or public
  HTTPS ArcGIS layer URL.

- jurisdiction:

  Optional bundled catalog jurisdiction; `NULL` resolves a unique ID or
  preserves the discovery source. Direct URLs do not accept a
  jurisdiction override.

- refresh:

  Whether to retrieve the current ArcGIS layer metadata.

- timeout:

  Per-request timeout in seconds.

- total_timeout:

  Overall operation budget in seconds; `Inf` disables it.

- portal:

  Optional sharing REST portal root when `id` is a stable
  `arcgis:<item-id>:<layer-id>` identifier.

## Value

A named source information list. With `refresh = TRUE`, includes current
fields and raw ArcGIS metadata.

## Examples

``` r
tbod_dataset_info("construction-permits")
#> $id
#> [1] "construction-permits"
#> 
#> $title
#> [1] "Permits (active GIS view)"
#> 
#> $description
#> [1] "Permit locations and attributes from the City active-permits GIS viewer. The service describes daily updates; it does not establish a complete historical permit ledger."
#> 
#> $jurisdiction
#> [1] "tampa"
#> 
#> $publisher
#> [1] "City of Tampa"
#> 
#> $source_url
#> [1] "https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer/0"
#> 
#> $service_url
#> [1] "https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer"
#> 
#> $layer_id
#> [1] 0
#> 
#> $layer_name
#> [1] "Permits"
#> 
#> $geometry_type
#> [1] "esriGeometryPoint"
#> 
#> $date_fields
#> [1] "LASTUPDATE"  "CREATEDDATE"
#> 
#> $category
#> [1] "Development"
#> 
#> $tags
#> [1] "permits"      "construction" "building"     "active"      
#> 
#> $verified
#> [1] "2026-09-29"
#> 
#> $terms
#> [1] "No explicit dataset license was found for this exact FeatureServer; its service iteminfo licenseInfo is empty. No license is inferred from a separate MapServer or the GeoHub site item. Source: https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer/info/iteminfo?f=pjson. City Conditions and Use says data is generally available to copy or distribute, subject to specified exceptions; it does not guarantee accuracy, completeness, or adequacy, and maps are reasonable representations rather than official records. Source: https://www.tampa.gov/about-us/tampagov/conditions-and-use."
#> 
#> $terms_url
#> [1] "https://www.tampa.gov/about-us/tampagov/conditions-and-use"
#> 
#> $license_info
#> NULL
#> 
#> $license_source
#> NULL
#> 
#> $publisher_evidence
#> $publisher_evidence[[1]]
#> [1] "https://www.tampa.gov/technology-and-innovation/geographic-information-systems"
#> 
#> $publisher_evidence[[2]]
#> [1] "https://tampa.maps.arcgis.com/sharing/rest/portals/self?f=pjson"
#> 
#> $publisher_evidence[[3]]
#> [1] "https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer?f=pjson"
#> 
#> 
#> $spatial_reference
#> $spatial_reference$wkid
#> [1] 102100
#> 
#> $spatial_reference$latestWkid
#> [1] 3857
#> 
#> 
#> $object_id_field
#> [1] "OBJECTID"
#> 
#> $max_record_count
#> [1] 2000
#> 
#> $supports_pagination
#> [1] TRUE
#> 
#> $supports_order_by
#> [1] TRUE
#> 
#> $upstream_modified
#> NULL
#> 
#> $date_time_reference
#> $date_time_reference$timeZone
#> [1] "Eastern Standard Time"
#> 
#> $date_time_reference$timeZoneIANA
#> [1] "America/New_York"
#> 
#> $date_time_reference$respectsDaylightSaving
#> [1] TRUE
#> 
#> 
#> $scope_note
#> [1] "The upstream service is described as data for an internal active-permits viewer, although its public Query endpoint is accessible without a token. The date fields are LASTUPDATE and CREATEDDATE; no permit issue-date field is advertised. No explicit dataset license was found on this exact FeatureServer service or in the selected public ArcGIS organization catalog. Do not infer the license of a separate MapServer layer."
#> 
#> $expected_schema
#> $expected_schema$endpoint
#> [1] "https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer/0"
#> 
#> $expected_schema$fields
#> $expected_schema$fields[[1]]
#> $expected_schema$fields[[1]]$name
#> [1] "OBJECTID"
#> 
#> $expected_schema$fields[[1]]$type
#> [1] "esriFieldTypeOID"
#> 
#> $expected_schema$fields[[1]]$alias
#> [1] "OBJECTID"
#> 
#> 
#> $expected_schema$fields[[2]]
#> $expected_schema$fields[[2]]$name
#> [1] "RECORD_ID"
#> 
#> $expected_schema$fields[[2]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[2]]$alias
#> [1] "Record ID"
#> 
#> 
#> $expected_schema$fields[[3]]
#> $expected_schema$fields[[3]]$name
#> [1] "PROJECTNAME1"
#> 
#> $expected_schema$fields[[3]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[3]]$alias
#> [1] "Project Name 1"
#> 
#> 
#> $expected_schema$fields[[4]]
#> $expected_schema$fields[[4]]$name
#> [1] "PROJECTNAME2"
#> 
#> $expected_schema$fields[[4]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[4]]$alias
#> [1] "Project Name 2"
#> 
#> 
#> $expected_schema$fields[[5]]
#> $expected_schema$fields[[5]]$name
#> [1] "PROJECTDESCRIPTION"
#> 
#> $expected_schema$fields[[5]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[5]]$alias
#> [1] "Project Description"
#> 
#> 
#> $expected_schema$fields[[6]]
#> $expected_schema$fields[[6]]$name
#> [1] "ADDRESS"
#> 
#> $expected_schema$fields[[6]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[6]]$alias
#> [1] "Address"
#> 
#> 
#> $expected_schema$fields[[7]]
#> $expected_schema$fields[[7]]$name
#> [1] "UNIT"
#> 
#> $expected_schema$fields[[7]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[7]]$alias
#> [1] "Unit"
#> 
#> 
#> $expected_schema$fields[[8]]
#> $expected_schema$fields[[8]]$name
#> [1] "ZIP"
#> 
#> $expected_schema$fields[[8]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[8]]$alias
#> [1] "Zip Code"
#> 
#> 
#> $expected_schema$fields[[9]]
#> $expected_schema$fields[[9]]$name
#> [1] "PROJECTSTATUS"
#> 
#> $expected_schema$fields[[9]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[9]]$alias
#> [1] "Project Status"
#> 
#> 
#> $expected_schema$fields[[10]]
#> $expected_schema$fields[[10]]$name
#> [1] "NEWCONSTRUCTIONSF"
#> 
#> $expected_schema$fields[[10]]$type
#> [1] "esriFieldTypeInteger"
#> 
#> $expected_schema$fields[[10]]$alias
#> [1] "New Construction SF"
#> 
#> 
#> $expected_schema$fields[[11]]
#> $expected_schema$fields[[11]]$name
#> [1] "OCCUPANCYCATEGORY"
#> 
#> $expected_schema$fields[[11]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[11]]$alias
#> [1] "Occupancy Category"
#> 
#> 
#> $expected_schema$fields[[12]]
#> $expected_schema$fields[[12]]$name
#> [1] "OCCUPANCYTYPE"
#> 
#> $expected_schema$fields[[12]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[12]]$alias
#> [1] "Occupancy Type"
#> 
#> 
#> $expected_schema$fields[[13]]
#> $expected_schema$fields[[13]]$name
#> [1] "NBROFUNITS"
#> 
#> $expected_schema$fields[[13]]$type
#> [1] "esriFieldTypeInteger"
#> 
#> $expected_schema$fields[[13]]$alias
#> [1] "Number of Units"
#> 
#> 
#> $expected_schema$fields[[14]]
#> $expected_schema$fields[[14]]$name
#> [1] "PRIVATEPROVIDER"
#> 
#> $expected_schema$fields[[14]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[14]]$alias
#> [1] "Private Provider"
#> 
#> 
#> $expected_schema$fields[[15]]
#> $expected_schema$fields[[15]]$name
#> [1] "STOPWORKORDER"
#> 
#> $expected_schema$fields[[15]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[15]]$alias
#> [1] "Stop Work Order"
#> 
#> 
#> $expected_schema$fields[[16]]
#> $expected_schema$fields[[16]]$name
#> [1] "LASTUPDATE"
#> 
#> $expected_schema$fields[[16]]$type
#> [1] "esriFieldTypeDate"
#> 
#> $expected_schema$fields[[16]]$alias
#> [1] "Last Update"
#> 
#> 
#> $expected_schema$fields[[17]]
#> $expected_schema$fields[[17]]$name
#> [1] "LASTEDITOR"
#> 
#> $expected_schema$fields[[17]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[17]]$alias
#> [1] "Last Editor"
#> 
#> 
#> $expected_schema$fields[[18]]
#> $expected_schema$fields[[18]]$name
#> [1] "GlobalID"
#> 
#> $expected_schema$fields[[18]]$type
#> [1] "esriFieldTypeGlobalID"
#> 
#> $expected_schema$fields[[18]]$alias
#> [1] "GlobalID"
#> 
#> 
#> $expected_schema$fields[[19]]
#> $expected_schema$fields[[19]]$name
#> [1] "CREATED"
#> 
#> $expected_schema$fields[[19]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[19]]$alias
#> [1] "Created By"
#> 
#> 
#> $expected_schema$fields[[20]]
#> $expected_schema$fields[[20]]$name
#> [1] "CREATEDDATE"
#> 
#> $expected_schema$fields[[20]]$type
#> [1] "esriFieldTypeDate"
#> 
#> $expected_schema$fields[[20]]$alias
#> [1] "Created Date"
#> 
#> 
#> $expected_schema$fields[[21]]
#> $expected_schema$fields[[21]]$name
#> [1] "COMBLDGAREA"
#> 
#> $expected_schema$fields[[21]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[21]]$alias
#> [1] "Commercial Buliding Inspector Area"
#> 
#> 
#> $expected_schema$fields[[22]]
#> $expected_schema$fields[[22]]$name
#> [1] "RESBLDGAREA"
#> 
#> $expected_schema$fields[[22]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[22]]$alias
#> [1] "Residential Building Inspector Area"
#> 
#> 
#> $expected_schema$fields[[23]]
#> $expected_schema$fields[[23]]$name
#> [1] "CRA"
#> 
#> $expected_schema$fields[[23]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[23]]$alias
#> [1] "Community Redevelopment Area"
#> 
#> 
#> $expected_schema$fields[[24]]
#> $expected_schema$fields[[24]]$name
#> [1] "COUNCIL"
#> 
#> $expected_schema$fields[[24]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[24]]$alias
#> [1] "Council District"
#> 
#> 
#> $expected_schema$fields[[25]]
#> $expected_schema$fields[[25]]$name
#> [1] "NEIGHBORHOOD"
#> 
#> $expected_schema$fields[[25]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[25]]$alias
#> [1] "Neighborhood"
#> 
#> 
#> $expected_schema$fields[[26]]
#> $expected_schema$fields[[26]]$name
#> [1] "RECORDTYPE"
#> 
#> $expected_schema$fields[[26]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[26]]$alias
#> [1] "Record Type"
#> 
#> 
#> $expected_schema$fields[[27]]
#> $expected_schema$fields[[27]]$name
#> [1] "URL"
#> 
#> $expected_schema$fields[[27]]$type
#> [1] "esriFieldTypeString"
#> 
#> $expected_schema$fields[[27]]$alias
#> [1] "URL"
#> 
#> 
#> 
#> $expected_schema$geometry_type
#> [1] "esriGeometryPoint"
#> 
#> $expected_schema$spatial_reference
#> $expected_schema$spatial_reference$wkid
#> [1] 102100
#> 
#> $expected_schema$spatial_reference$latestWkid
#> [1] 3857
#> 
#> 
#> $expected_schema$object_id_field
#> [1] "OBJECTID"
#> 
#> 
#> $validation_status
#> [1] "checked"
#> 
#> $original_metadata
#> $original_metadata$id
#> [1] "construction-permits"
#> 
#> $original_metadata$title
#> [1] "Permits (active GIS view)"
#> 
#> $original_metadata$description
#> [1] "Permit locations and attributes from the City active-permits GIS viewer. The service describes daily updates; it does not establish a complete historical permit ledger."
#> 
#> $original_metadata$jurisdiction
#> [1] "tampa"
#> 
#> $original_metadata$publisher
#> [1] "City of Tampa"
#> 
#> $original_metadata$source_url
#> [1] "https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer/0"
#> 
#> $original_metadata$service_url
#> [1] "https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer"
#> 
#> $original_metadata$layer_id
#> [1] 0
#> 
#> $original_metadata$layer_name
#> [1] "Permits"
#> 
#> $original_metadata$geometry_type
#> [1] "esriGeometryPoint"
#> 
#> $original_metadata$date_fields
#> [1] "LASTUPDATE"  "CREATEDDATE"
#> 
#> $original_metadata$category
#> [1] "Development"
#> 
#> $original_metadata$tags
#> [1] "permits"      "construction" "building"     "active"      
#> 
#> $original_metadata$verified
#> [1] "2026-09-29"
#> 
#> $original_metadata$terms
#> [1] "No explicit dataset license was found for this exact FeatureServer; its service iteminfo licenseInfo is empty. No license is inferred from a separate MapServer or the GeoHub site item. Source: https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer/info/iteminfo?f=pjson. City Conditions and Use says data is generally available to copy or distribute, subject to specified exceptions; it does not guarantee accuracy, completeness, or adequacy, and maps are reasonable representations rather than official records. Source: https://www.tampa.gov/about-us/tampagov/conditions-and-use."
#> 
#> $original_metadata$terms_url
#> [1] "https://www.tampa.gov/about-us/tampagov/conditions-and-use"
#> 
#> $original_metadata$license_info
#> NULL
#> 
#> $original_metadata$license_source
#> NULL
#> 
#> $original_metadata$publisher_evidence
#> $original_metadata$publisher_evidence[[1]]
#> [1] "https://www.tampa.gov/technology-and-innovation/geographic-information-systems"
#> 
#> $original_metadata$publisher_evidence[[2]]
#> [1] "https://tampa.maps.arcgis.com/sharing/rest/portals/self?f=pjson"
#> 
#> $original_metadata$publisher_evidence[[3]]
#> [1] "https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer?f=pjson"
#> 
#> 
#> $original_metadata$spatial_reference
#> $original_metadata$spatial_reference$wkid
#> [1] 102100
#> 
#> $original_metadata$spatial_reference$latestWkid
#> [1] 3857
#> 
#> 
#> $original_metadata$object_id_field
#> [1] "OBJECTID"
#> 
#> $original_metadata$max_record_count
#> [1] 2000
#> 
#> $original_metadata$supports_pagination
#> [1] TRUE
#> 
#> $original_metadata$supports_order_by
#> [1] TRUE
#> 
#> $original_metadata$upstream_modified
#> NULL
#> 
#> $original_metadata$date_time_reference
#> $original_metadata$date_time_reference$timeZone
#> [1] "Eastern Standard Time"
#> 
#> $original_metadata$date_time_reference$timeZoneIANA
#> [1] "America/New_York"
#> 
#> $original_metadata$date_time_reference$respectsDaylightSaving
#> [1] TRUE
#> 
#> 
#> $original_metadata$scope_note
#> [1] "The upstream service is described as data for an internal active-permits viewer, although its public Query endpoint is accessible without a token. The date fields are LASTUPDATE and CREATEDDATE; no permit issue-date field is advertised. No explicit dataset license was found on this exact FeatureServer service or in the selected public ArcGIS organization catalog. Do not infer the license of a separate MapServer layer."
#> 
#> $original_metadata$expected_schema
#> $original_metadata$expected_schema$endpoint
#> [1] "https://arcgis.tampagov.net/arcgis/rest/services/Planning/PermitsAll/FeatureServer/0"
#> 
#> $original_metadata$expected_schema$fields
#> $original_metadata$expected_schema$fields[[1]]
#> $original_metadata$expected_schema$fields[[1]]$name
#> [1] "OBJECTID"
#> 
#> $original_metadata$expected_schema$fields[[1]]$type
#> [1] "esriFieldTypeOID"
#> 
#> $original_metadata$expected_schema$fields[[1]]$alias
#> [1] "OBJECTID"
#> 
#> 
#> $original_metadata$expected_schema$fields[[2]]
#> $original_metadata$expected_schema$fields[[2]]$name
#> [1] "RECORD_ID"
#> 
#> $original_metadata$expected_schema$fields[[2]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[2]]$alias
#> [1] "Record ID"
#> 
#> 
#> $original_metadata$expected_schema$fields[[3]]
#> $original_metadata$expected_schema$fields[[3]]$name
#> [1] "PROJECTNAME1"
#> 
#> $original_metadata$expected_schema$fields[[3]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[3]]$alias
#> [1] "Project Name 1"
#> 
#> 
#> $original_metadata$expected_schema$fields[[4]]
#> $original_metadata$expected_schema$fields[[4]]$name
#> [1] "PROJECTNAME2"
#> 
#> $original_metadata$expected_schema$fields[[4]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[4]]$alias
#> [1] "Project Name 2"
#> 
#> 
#> $original_metadata$expected_schema$fields[[5]]
#> $original_metadata$expected_schema$fields[[5]]$name
#> [1] "PROJECTDESCRIPTION"
#> 
#> $original_metadata$expected_schema$fields[[5]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[5]]$alias
#> [1] "Project Description"
#> 
#> 
#> $original_metadata$expected_schema$fields[[6]]
#> $original_metadata$expected_schema$fields[[6]]$name
#> [1] "ADDRESS"
#> 
#> $original_metadata$expected_schema$fields[[6]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[6]]$alias
#> [1] "Address"
#> 
#> 
#> $original_metadata$expected_schema$fields[[7]]
#> $original_metadata$expected_schema$fields[[7]]$name
#> [1] "UNIT"
#> 
#> $original_metadata$expected_schema$fields[[7]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[7]]$alias
#> [1] "Unit"
#> 
#> 
#> $original_metadata$expected_schema$fields[[8]]
#> $original_metadata$expected_schema$fields[[8]]$name
#> [1] "ZIP"
#> 
#> $original_metadata$expected_schema$fields[[8]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[8]]$alias
#> [1] "Zip Code"
#> 
#> 
#> $original_metadata$expected_schema$fields[[9]]
#> $original_metadata$expected_schema$fields[[9]]$name
#> [1] "PROJECTSTATUS"
#> 
#> $original_metadata$expected_schema$fields[[9]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[9]]$alias
#> [1] "Project Status"
#> 
#> 
#> $original_metadata$expected_schema$fields[[10]]
#> $original_metadata$expected_schema$fields[[10]]$name
#> [1] "NEWCONSTRUCTIONSF"
#> 
#> $original_metadata$expected_schema$fields[[10]]$type
#> [1] "esriFieldTypeInteger"
#> 
#> $original_metadata$expected_schema$fields[[10]]$alias
#> [1] "New Construction SF"
#> 
#> 
#> $original_metadata$expected_schema$fields[[11]]
#> $original_metadata$expected_schema$fields[[11]]$name
#> [1] "OCCUPANCYCATEGORY"
#> 
#> $original_metadata$expected_schema$fields[[11]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[11]]$alias
#> [1] "Occupancy Category"
#> 
#> 
#> $original_metadata$expected_schema$fields[[12]]
#> $original_metadata$expected_schema$fields[[12]]$name
#> [1] "OCCUPANCYTYPE"
#> 
#> $original_metadata$expected_schema$fields[[12]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[12]]$alias
#> [1] "Occupancy Type"
#> 
#> 
#> $original_metadata$expected_schema$fields[[13]]
#> $original_metadata$expected_schema$fields[[13]]$name
#> [1] "NBROFUNITS"
#> 
#> $original_metadata$expected_schema$fields[[13]]$type
#> [1] "esriFieldTypeInteger"
#> 
#> $original_metadata$expected_schema$fields[[13]]$alias
#> [1] "Number of Units"
#> 
#> 
#> $original_metadata$expected_schema$fields[[14]]
#> $original_metadata$expected_schema$fields[[14]]$name
#> [1] "PRIVATEPROVIDER"
#> 
#> $original_metadata$expected_schema$fields[[14]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[14]]$alias
#> [1] "Private Provider"
#> 
#> 
#> $original_metadata$expected_schema$fields[[15]]
#> $original_metadata$expected_schema$fields[[15]]$name
#> [1] "STOPWORKORDER"
#> 
#> $original_metadata$expected_schema$fields[[15]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[15]]$alias
#> [1] "Stop Work Order"
#> 
#> 
#> $original_metadata$expected_schema$fields[[16]]
#> $original_metadata$expected_schema$fields[[16]]$name
#> [1] "LASTUPDATE"
#> 
#> $original_metadata$expected_schema$fields[[16]]$type
#> [1] "esriFieldTypeDate"
#> 
#> $original_metadata$expected_schema$fields[[16]]$alias
#> [1] "Last Update"
#> 
#> 
#> $original_metadata$expected_schema$fields[[17]]
#> $original_metadata$expected_schema$fields[[17]]$name
#> [1] "LASTEDITOR"
#> 
#> $original_metadata$expected_schema$fields[[17]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[17]]$alias
#> [1] "Last Editor"
#> 
#> 
#> $original_metadata$expected_schema$fields[[18]]
#> $original_metadata$expected_schema$fields[[18]]$name
#> [1] "GlobalID"
#> 
#> $original_metadata$expected_schema$fields[[18]]$type
#> [1] "esriFieldTypeGlobalID"
#> 
#> $original_metadata$expected_schema$fields[[18]]$alias
#> [1] "GlobalID"
#> 
#> 
#> $original_metadata$expected_schema$fields[[19]]
#> $original_metadata$expected_schema$fields[[19]]$name
#> [1] "CREATED"
#> 
#> $original_metadata$expected_schema$fields[[19]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[19]]$alias
#> [1] "Created By"
#> 
#> 
#> $original_metadata$expected_schema$fields[[20]]
#> $original_metadata$expected_schema$fields[[20]]$name
#> [1] "CREATEDDATE"
#> 
#> $original_metadata$expected_schema$fields[[20]]$type
#> [1] "esriFieldTypeDate"
#> 
#> $original_metadata$expected_schema$fields[[20]]$alias
#> [1] "Created Date"
#> 
#> 
#> $original_metadata$expected_schema$fields[[21]]
#> $original_metadata$expected_schema$fields[[21]]$name
#> [1] "COMBLDGAREA"
#> 
#> $original_metadata$expected_schema$fields[[21]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[21]]$alias
#> [1] "Commercial Buliding Inspector Area"
#> 
#> 
#> $original_metadata$expected_schema$fields[[22]]
#> $original_metadata$expected_schema$fields[[22]]$name
#> [1] "RESBLDGAREA"
#> 
#> $original_metadata$expected_schema$fields[[22]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[22]]$alias
#> [1] "Residential Building Inspector Area"
#> 
#> 
#> $original_metadata$expected_schema$fields[[23]]
#> $original_metadata$expected_schema$fields[[23]]$name
#> [1] "CRA"
#> 
#> $original_metadata$expected_schema$fields[[23]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[23]]$alias
#> [1] "Community Redevelopment Area"
#> 
#> 
#> $original_metadata$expected_schema$fields[[24]]
#> $original_metadata$expected_schema$fields[[24]]$name
#> [1] "COUNCIL"
#> 
#> $original_metadata$expected_schema$fields[[24]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[24]]$alias
#> [1] "Council District"
#> 
#> 
#> $original_metadata$expected_schema$fields[[25]]
#> $original_metadata$expected_schema$fields[[25]]$name
#> [1] "NEIGHBORHOOD"
#> 
#> $original_metadata$expected_schema$fields[[25]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[25]]$alias
#> [1] "Neighborhood"
#> 
#> 
#> $original_metadata$expected_schema$fields[[26]]
#> $original_metadata$expected_schema$fields[[26]]$name
#> [1] "RECORDTYPE"
#> 
#> $original_metadata$expected_schema$fields[[26]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[26]]$alias
#> [1] "Record Type"
#> 
#> 
#> $original_metadata$expected_schema$fields[[27]]
#> $original_metadata$expected_schema$fields[[27]]$name
#> [1] "URL"
#> 
#> $original_metadata$expected_schema$fields[[27]]$type
#> [1] "esriFieldTypeString"
#> 
#> $original_metadata$expected_schema$fields[[27]]$alias
#> [1] "URL"
#> 
#> 
#> 
#> $original_metadata$expected_schema$geometry_type
#> [1] "esriGeometryPoint"
#> 
#> $original_metadata$expected_schema$spatial_reference
#> $original_metadata$expected_schema$spatial_reference$wkid
#> [1] 102100
#> 
#> $original_metadata$expected_schema$spatial_reference$latestWkid
#> [1] 3857
#> 
#> 
#> $original_metadata$expected_schema$object_id_field
#> [1] "OBJECTID"
#> 
#> 
#> $original_metadata$validation_status
#> [1] "checked"
#> 
#> 
```

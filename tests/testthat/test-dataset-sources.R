# Actual, trimmed upstream layer schemas; all feature values below are synthetic.
# This exercises schema differences that a single permit-shaped mock cannot cover.
source_schema_fixture <- function(id) {
  jsonlite::fromJSON(test_path("fixtures", "tampa-layer-schemas.json"),
                     simplifyVector = FALSE)[[id]]
}

source_fixture_feature <- function(attributes, geometry = NULL) {
  list(attributes = attributes, geometry = geometry)
}

source_fixture_transport <- function(id, features) {
  snapshot <- source_schema_fixture(id)
  fixture_transport(features = features, metadata = snapshot$metadata)
}

source_capital_fixture <- function() {
  list(
    fields = c("projname", "planstart", "planend", "CreationDate", "EditDate",
               "created_date", "last_edited_date", "estcost", "NumVotes", "ShowPublic"),
    features = list(
      source_fixture_feature(
        list(OBJECTID = 8L, projname = "synthetic-future-project", planstart = 1704240000000,
             planend = NULL, CreationDate = 1704153600000, EditDate = 1704240000000,
             created_date = 1704153600000, last_edited_date = 1704240000000,
             estcost = 123456.75, NumVotes = 2L, ShowPublic = "Yes"),
        list(x = 900008, y = 1300008)),
      source_fixture_feature(
        list(OBJECTID = 3L, projname = "synthetic-earlier-project", planstart = 1704153600000,
             planend = 1704326400000, CreationDate = 1704067200000, EditDate = 1704153600000,
             created_date = 1704067200000, last_edited_date = 1704153600000,
             estcost = 50000.25, NumVotes = NULL, ShowPublic = "Yes"),
        list(x = 900003, y = 1300003))
    )
  )
}

expect_source_routing <- function(result, transport, id, fields) {
  snapshot <- source_schema_fixture(id)
  metadata_url <- snapshot$metadata_url
  query_url <- paste0(metadata_url, "/query")
  expect_identical(unique(vapply(transport$state$requests, function(x) x$url,
                                character(1))), c(metadata_url, query_url))
  provenance <- dataset_provenance(result)
  expect_identical(provenance$dataset_id, id)
  expect_identical(provenance$endpoint, query_url)
  expect_identical(provenance$layer_id,
                   as.integer(sub(".*/", "", metadata_url)))
  expect_identical(provenance$query$fields, fields)
  expect_true(provenance$complete)
}

test_that("every catalog entry matches its recorded source schema", {
  entries <- .read_registry()
  snapshots <- jsonlite::fromJSON(test_path("fixtures", "tampa-layer-schemas.json"),
                                  simplifyVector = FALSE)
  expect_setequal(names(snapshots), vapply(entries, `[[`, character(1), "id"))
  for (entry in entries) {
    snapshot <- snapshots[[entry$id]]
    metadata <- snapshot$metadata
    expect_identical(snapshot$metadata_url,
                     paste0(entry$service_url, "/", entry$layer_id))
    expect_identical(snapshot$verified, entry$verified)
    expect_identical(metadata$geometryType, entry$geometry_type)
    expect_equal(metadata$maxRecordCount, entry$max_record_count)
    oid_fields <- Filter(function(x) x$type == "esriFieldTypeOID", metadata$fields)
    expect_length(oid_fields, 1L)
    expect_identical(oid_fields[[1L]]$name, entry$object_id_field)
    date_fields <- vapply(Filter(function(x) x$type == "esriFieldTypeDate",
                                 metadata$fields), `[[`, character(1), "name")
    expect_identical(date_fields, unlist(entry$date_fields, use.names = FALSE))
    expect_identical(metadata$advancedQueryCapabilities$supportsPagination,
                     entry$supports_pagination)
    expect_identical(metadata$advancedQueryCapabilities$supportsOrderBy,
                     entry$supports_order_by)
    expect_equal(metadata$spatialReference, entry$spatial_reference)
  }
})

test_that("the distinct FeatureServer record schemas preserve literal date strings", {
  cases <- list(
    list(id = "construction-permits", record_field = "RECORD_ID",
         attributes = list(RECORD_ID = "synthetic-permit", CREATED = "01/02/2024",
                           CREATEDDATE = 1704153600000, LASTUPDATE = 1704240000000,
                           NEWCONSTRUCTIONSF = 2400L),
         integer_field = "NEWCONSTRUCTIONSF"),
    list(id = "development-cases", record_field = "RECORDID",
         attributes = list(RECORDID = "synthetic-case", CREATED = "01/02/2024",
                           CREATEDDATE = 1704153600000, LASTUPDATE = 1704240000000,
                           TENTATIVEHEARING = "09/29/2026", TENTATIVETIME = "10:30 AM"))
  )
  for (case in cases) {
    attributes <- c(list(OBJECTID = 17L), case$attributes)
    transport <- source_fixture_transport(case$id, list(source_fixture_feature(attributes)))
    local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
    fields <- names(case$attributes)
    result <- get_dataset(case$id, fields = fields)
    expect_identical(names(result), fields)
    expect_identical(result[[case$record_field]], case$attributes[[case$record_field]])
    expect_identical(result$CREATED, "01/02/2024")
    expect_identical(result$CREATEDDATE,
                     as.POSIXct("2024-01-02", tz = "UTC"))
    expect_identical(result$LASTUPDATE,
                     as.POSIXct("2024-01-03", tz = "UTC"))
    if (case$id == "development-cases") {
      expect_identical(result$TENTATIVEHEARING, "09/29/2026")
      expect_identical(result$TENTATIVETIME, "10:30 AM")
    } else {
      expect_identical(result$NEWCONSTRUCTIONSF, 2400L)
    }
    expect_identical(dataset_provenance(result)$date_fields_time_reference$timeZoneIANA,
                     "America/New_York")
    expect_identical(fixture_queries(transport, "features")[[1L]]$params$outFields,
                     paste(c(fields, "OBJECTID"), collapse = ","))
    expect_source_routing(result, transport, case$id, fields)
  }
})

test_that("capital project dates and numeric attributes work without optional spatial support", {
  fixture <- source_capital_fixture()
  fields <- fixture$fields
  transport <- source_fixture_transport("capital-projects", fixture$features)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  result <- get_dataset("capital-projects", fields = fields, page_size = 1)
  expect_identical(names(result), fields)
  expect_identical(result$projname, c("synthetic-earlier-project", "synthetic-future-project"))
  expect_identical(result$planstart,
                   as.POSIXct(c("2024-01-02", "2024-01-03"), tz = "UTC"))
  expect_identical(result$planend,
                   as.POSIXct(c("2024-01-04", NA_character_), tz = "UTC"))
  for (field in c("CreationDate", "created_date")) {
    expect_identical(result[[field]],
                     as.POSIXct(c("2024-01-01", "2024-01-02"), tz = "UTC"))
  }
  for (field in c("EditDate", "last_edited_date")) {
    expect_identical(result[[field]],
                     as.POSIXct(c("2024-01-02", "2024-01-03"), tz = "UTC"))
  }
  expect_identical(result$estcost, c(50000.25, 123456.75))
  expect_identical(result$NumVotes, c(NA_integer_, 2L))
  expect_identical(result$ShowPublic, c("Yes", "Yes"))
  expect_identical(vapply(fixture_queries(transport, "features"),
                          function(x) x$params$objectIds, character(1)), c("3", "8"))
  expect_source_routing(result, transport, "capital-projects", fields)
})

test_that("capital project geometry uses the advertised native feet-based CRS", {
  skip_if_not_installed("sf")
  fixture <- source_capital_fixture()
  transport <- source_fixture_transport("capital-projects", fixture$features)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  result <- get_dataset("capital-projects", fields = fixture$fields,
                         spatial = TRUE, page_size = 1)
  expect_identical(names(sf::st_drop_geometry(result)), fixture$fields)
  expect_equal(sf::st_crs(result)$epsg, 6443)
  expect_match(sf::st_crs(result)$units_gdal, "foot|feet", ignore.case = TRUE)
  expect_equal(unname(sf::st_coordinates(result)),
               matrix(c(900003, 900008, 1300003, 1300008), ncol = 2L))
  expect_identical(dataset_provenance(result)$spatial_reference,
                   list(wkid = 103023L, latestWkid = 6443L))
  expect_source_routing(result, transport, "capital-projects", fixture$fields)
})

test_that("the shared Boundary MapServer preserves layer-specific fields and routing", {
  cases <- list(
    list(id = "city-boundary",
         attributes = list(Municipality = "synthetic-city", ID = 1L,
                           LASTUPDATE = 1704153600000, created_date = NULL,
                           `SHAPE.STArea()` = 400.5, `SHAPE.STLength()` = 80.25)),
    list(id = "neighborhoods",
         attributes = list(Association = "synthetic-association", Neighborhood_ID = 12L,
                           created_date = 1704153600000, ContactUpdated = NULL,
                           `Shape.STArea()` = 900.5, `Shape.STLength()` = 120.25)),
    list(id = "council-districts",
         attributes = list(DISTRICTID = "synthetic-district", NAME = "synthetic-name",
                           LASTUPDATE = 1704153600000,
                           `SHAPE.STArea()` = 1600.5, `SHAPE.STLength()` = 160.25))
  )
  for (case in cases) {
    metadata <- source_schema_fixture(case$id)$metadata
    transport <- source_fixture_transport(case$id, list(source_fixture_feature(
      c(list(OBJECTID = 21L), case$attributes))))
    local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
    result <- get_dataset(case$id)
    attribute_schema <- Filter(function(x) x$type != "esriFieldTypeGeometry", metadata$fields)
    fields <- vapply(attribute_schema, function(x) x$name, character(1))
    expect_identical(names(result), fields)
    expect_identical(result$OBJECTID, 21L)
    geometry_fields <- vapply(Filter(function(x) x$type == "esriFieldTypeGeometry",
                                     metadata$fields), function(x) x$name, character(1))
    expect_false(any(geometry_fields %in% names(result)))
    for (field in names(case$attributes)) {
      schema <- metadata$fields[[match(field, vapply(metadata$fields,
                                                    function(x) x$name, character(1)))]]
      expected <- case$attributes[[field]]
      if (schema$type == "esriFieldTypeDate") {
        expected <- as.POSIXct(if (is.null(expected)) NA_real_ else expected / 1000,
                              origin = "1970-01-01", tz = "UTC")
      }
      expect_identical(result[[field]], expected)
    }
    # Fields not supplied by a feature remain present with their declared types.
    expect_identical(result$GlobalID, NA_character_)
    expect_source_routing(result, transport, case$id, fields)
  }
})

test_that("Riverwalk and parks preserve expression field names and source codes", {
  cases <- list(
    list(id = "riverwalk",
         attributes = list(NAME = "synthetic-segment", STATUS = "synthetic-status",
                           LASTUPDATE = 1704153600000, `SHAPE.STLength()` = 12.75)),
    list(id = "parks",
         attributes = list(PARKNAME = "synthetic-park", SUBTYPE = 4L, PUBLIC_ = "Y",
                           LASTUPDATE = 1704153600000, ACRES = 1.25,
                           `Shape.STArea()` = 2500.5, `Shape.STLength()` = 200.25))
  )
  for (case in cases) {
    fields <- names(case$attributes)
    transport <- source_fixture_transport(case$id, list(source_fixture_feature(
      c(list(OBJECTID = 29L), case$attributes))))
    local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
    result <- get_dataset(case$id, fields = fields)
    expect_identical(names(result), fields)
    for (field in setdiff(fields, "LASTUPDATE")) {
      expect_identical(result[[field]], case$attributes[[field]])
    }
    expect_identical(result$LASTUPDATE, as.POSIXct("2024-01-02", tz = "UTC"))
    expect_identical(fixture_queries(transport, "features")[[1L]]$params$outFields,
                     paste(c(fields, "OBJECTID"), collapse = ","))
    expect_source_routing(result, transport, case$id, fields)
  }
})

test_that("fire stations use the qualified OID without offset pagination", {
  oid <- "GIS.FacilitySitePoint.OBJECTID"
  fields <- c("GIS.FacilitySitePoint.NAME", "GIS.FacilitySitePoint.MAPID",
              "GIS.FacilitySitePoint.LASTUPDATE", "GIS.GovServiceInfo.OPERDAYS",
              "GIS.GovServiceInfo.OBJECTID")
  features <- list(
    source_fixture_feature(setNames(
      list(41L, "synthetic-north", 3L, 1704153600000, "Monday-Friday", 901L),
      c(oid, fields))),
    source_fixture_feature(setNames(
      list(7L, "synthetic-south", NULL, NULL, "Weekends", 902L),
      c(oid, fields)))
  )
  transport <- source_fixture_transport("fire-stations", features)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  result <- get_dataset("fire-stations", fields = fields, page_size = 1)
  expect_identical(names(result), fields)
  expect_identical(result[[fields[[1L]]]], c("synthetic-south", "synthetic-north"))
  expect_identical(result[[fields[[2L]]]], c(NA_integer_, 3L))
  expect_identical(result[[fields[[3L]]]],
                   as.POSIXct(c(NA_character_, "2024-01-02"), tz = "UTC"))
  expect_identical(result[[fields[[4L]]]], c("Weekends", "Monday-Friday"))
  expect_identical(result[[fields[[5L]]]], c(902L, 901L))
  queries <- fixture_queries(transport, "features")
  expect_identical(vapply(queries, function(x) x$params$objectIds, character(1)),
                   c("7", "41"))
  expect_true(all(vapply(queries, function(x)
    is.null(x$params$resultOffset) && is.null(x$params$orderByFields), logical(1))))
  expect_identical(queries[[1L]]$params$outFields, paste(c(fields, oid), collapse = ","))
  expect_identical(dataset_provenance(result)$pagination, "object-id batches")
  expect_source_routing(result, transport, "fire-stations", fields)

  expect_error(get_dataset("fire-stations", fields = fields,
                           order_by = paste(fields[[1L]], "ASC")),
               "does not support reliable server-side ordering")
  expect_length(fixture_queries(transport, "features"), 2L)
})

test_that("bike lanes preserve measured lengths, dates, and source strings", {
  fields <- c("ROADWAY", "WIDTH", "INSTALLDATE", "SHAPE.STLength()",
              "MILEAGE", "CREATED")
  features <- list(
    source_fixture_feature(c(list(OBJECTID = 14L),
      setNames(list("synthetic-z", 5.5, 1704240000000, 25.75, 0.8, "source-string"),
               fields))),
    source_fixture_feature(c(list(OBJECTID = 2L),
      setNames(list("synthetic-a", 3.25, NULL, 10.5, 0.3, "another-string"),
               fields)))
  )
  transport <- source_fixture_transport("bike-lanes", features)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  result <- get_dataset("bike-lanes", fields = fields, page_size = 1,
                        order_by = "ROADWAY ASC")
  expect_identical(names(result), fields)
  expect_identical(result$ROADWAY, c("synthetic-a", "synthetic-z"))
  expect_identical(result$WIDTH, c(3.25, 5.5))
  expect_identical(result$INSTALLDATE,
                   as.POSIXct(c(NA_character_, "2024-01-03"), tz = "UTC"))
  expect_identical(result[["SHAPE.STLength()"]], c(10.5, 25.75))
  expect_identical(result$MILEAGE, c(0.3, 0.8))
  expect_identical(result$CREATED, c("another-string", "source-string"))
  queries <- fixture_queries(transport, "features")
  expect_identical(vapply(queries, function(x) x$params$orderByFields,
                          character(1)), rep("ROADWAY ASC,OBJECTID ASC", 2L))
  expect_identical(vapply(queries, function(x) x$params$resultOffset,
                          numeric(1)), c(0, 1))
  expect_identical(dataset_provenance(result)$pagination, "ordered offsets")
  expect_source_routing(result, transport, "bike-lanes", fields)
})

test_that("recycling pickup keeps collection labels and typed area", {
  fields <- c("NAME", "SCHEDULE", "COLLECTIONDAYS", "WEEKONE", "MILES",
              "LASTUPDATE", "SHAPE.STArea()")
  feature <- source_fixture_feature(c(list(OBJECTID = 32L),
    setNames(list("synthetic-zone", "synthetic-cycle", "Tuesday", "Y", "5.5",
                  1704153600000, 1500.25), fields)))
  transport <- source_fixture_transport("recycling-pickup", list(feature))
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  result <- get_dataset("recycling-pickup", fields = fields)
  expect_identical(names(result), fields)
  expect_identical(result$SCHEDULE, "synthetic-cycle")
  expect_identical(result$COLLECTIONDAYS, "Tuesday")
  expect_identical(result$WEEKONE, "Y")
  expect_identical(result$MILES, "5.5")
  expect_identical(result$LASTUPDATE, as.POSIXct("2024-01-02", tz = "UTC"))
  expect_identical(result[["SHAPE.STArea()"]], 1500.25)
  expect_source_routing(result, transport, "recycling-pickup", fields)
})

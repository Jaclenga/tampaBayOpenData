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

schema_test_case <- function() {
  entry <- .lookup_dataset("construction-permits")
  metadata <- source_schema_fixtures()[["construction-permits"]]$metadata
  list(entry = entry, metadata = metadata)
}

test_that("all checked layers carry field snapshots matching the verified metadata", {
  entries <- .read_registry()
  snapshots <- source_schema_fixtures()
  expect_length(entries, 35L)
  for (entry in entries) {
    metadata <- snapshots[[entry$id]]$metadata
    metadata$objectIdField <- entry$object_id_field
    check <- .compare_schema(entry$expected_schema, metadata, entry)
    expect_identical(check$status, "unchanged", info = entry$id)
    expect_equal(nrow(check$issues), 0L, info = entry$id)
  }
})

test_that("added fields are compatible drift and warn during checked retrieval", {
  case <- schema_test_case()
  changed <- case$metadata
  changed$fields <- c(changed$fields,
                      list(fixture_field("NEW_FIELD", "esriFieldTypeString")))
  check <- .compare_schema(case$entry$expected_schema, changed, case$entry)
  expect_identical(check$status, "compatible")
  expect_identical(check$issues$category, "added_field")
  expect_identical(check$issues$field, "NEW_FIELD")

  transport <- fixture_transport(metadata = changed)
  local_mocked_bindings(arcgis_http = transport$http)
  expect_warning(result <- get_dataset("construction-permits",
                                       fields = "RECORD_ID", limit = 1),
                 "added_field.*NEW_FIELD")
  expect_identical(result$RECORD_ID, "synthetic-1")
  expect_length(fixture_queries(transport, "features"), 1L)
})

test_that("removed fields stop retrieval before querying", {
  case <- schema_test_case()
  changed <- case$metadata
  changed$fields <- Filter(function(x) x$name != "PROJECTSTATUS", changed$fields)
  check <- .compare_schema(case$entry$expected_schema, changed, case$entry)
  expect_identical(check$status, "incompatible")
  expect_true("removed_field" %in% check$issues$category)
  expect_true("PROJECTSTATUS" %in% check$issues$field)

  transport <- fixture_transport(metadata = changed)
  local_mocked_bindings(arcgis_http = transport$http)
  expect_error(get_dataset("construction-permits", fields = "RECORD_ID"),
               "removed_field.*PROJECTSTATUS", class = "tampa_schema_error")
  expect_error(download_dataset("construction-permits", tempfile("schema-download-"),
                                fields = "RECORD_ID"),
               "removed_field.*PROJECTSTATUS", class = "tampa_schema_error")
  expect_length(fixture_queries(transport), 0L)
})

test_that("a removed object-ID field is reported as schema drift", {
  case <- schema_test_case()
  changed <- case$metadata
  changed$fields <- Filter(function(x) x$name != "OBJECTID", changed$fields)
  transport <- fixture_transport(metadata = changed)
  local_mocked_bindings(arcgis_http = transport$http)

  report <- tbod_check_schema("construction-permits")
  expect_identical(report$status, "incompatible")
  expect_true("removed_field" %in% report$issues$category)
  expect_true("OBJECTID" %in% report$issues$field)
  expect_error(get_dataset("construction-permits"), "removed_field.*OBJECTID",
               class = "tampa_schema_error")
  expect_length(fixture_queries(transport), 0L)
})

test_that("unambiguous field rename and changed type are classified", {
  case <- schema_test_case()
  renamed <- case$metadata
  i <- match("RECORD_ID", .field_names(renamed))
  renamed$fields[[i]]$name <- "RECORD_NUMBER"
  check <- .compare_schema(case$entry$expected_schema, renamed, case$entry)
  expect_identical(check$status, "incompatible")
  expect_true("renamed_field" %in% check$issues$category)
  expect_false("removed_field" %in% check$issues$category)
  expect_false("added_field" %in% check$issues$category)

  typed <- case$metadata
  typed$fields[[i]]$type <- "esriFieldTypeInteger"
  check <- .compare_schema(case$entry$expected_schema, typed, case$entry)
  expect_identical(check$status, "incompatible")
  expect_identical(check$issues$category, "changed_type")
  expect_identical(check$issues$field, "RECORD_ID")
})

test_that("an alias edit is reported as compatible drift", {
  case <- schema_test_case()
  changed <- case$metadata
  i <- match("RECORD_ID", .field_names(changed))
  changed$fields[[i]]$alias <- "Permit record number"
  check <- .compare_schema(case$entry$expected_schema, changed, case$entry)
  expect_identical(check$status, "compatible")
  expect_identical(check$issues$category, "changed_alias")
  expect_identical(check$issues$field, "RECORD_ID")
})

test_that("geometry and CRS changes are incompatible but equivalent WKIDs compare equal", {
  case <- schema_test_case()
  equivalent <- case$metadata
  equivalent$spatialReference <- list(wkid = 3857L)
  expect_identical(.compare_schema(case$entry$expected_schema,
                                   equivalent, case$entry)$status, "unchanged")

  geometry <- case$metadata
  geometry$geometryType <- "esriGeometryPolygon"
  check <- .compare_schema(case$entry$expected_schema, geometry, case$entry)
  expect_true("geometry_change" %in% check$issues$category)
  expect_identical(check$status, "incompatible")

  crs <- case$metadata
  crs$spatialReference <- list(wkid = 4326L)
  check <- .compare_schema(case$entry$expected_schema, crs, case$entry)
  expect_true("crs_change" %in% check$issues$category)
  expect_identical(check$status, "incompatible")
})

test_that("equivalent WKT and WKID representations do not imply CRS drift", {
  skip_if_not_installed("sf")
  case <- schema_test_case()
  equivalent <- case$metadata
  equivalent$spatialReference <- list(wkt = sf::st_crs(3857)$wkt)
  check <- .compare_schema(case$entry$expected_schema, equivalent, case$entry)
  expect_identical(check$status, "unchanged")
})

test_that("malformed CRS scalar values produce classified response errors", {
  case <- schema_test_case()
  metadata <- case$metadata
  local_mocked_bindings(arcgis_http = function(...) fixture_response(metadata))

  metadata$spatialReference <- list(wkid = c(3857L, 4326L))
  expect_error(tbod_check_schema("construction-permits"),
               "malformed `spatialReference`", class = "tampa_response_error")
  metadata$spatialReference <- list(wkt = c("WKT A", "WKT B"))
  expect_error(tbod_check_schema("construction-permits"),
               "malformed `spatialReference`", class = "tampa_response_error")
  metadata$spatialReference <- NULL
  metadata$extent$spatialReference <- list(wkid = c(3857L, 4326L))
  expect_error(tbod_check_schema("construction-permits"),
               "malformed `extentSpatialReference`", class = "tampa_response_error")
})

test_that("malformed expected CRS values produce input errors before network", {
  expected <- schema_test_case()$entry$expected_schema
  expected$spatial_reference <- list(wkid = c(3857L, 4326L))
  expect_error(tbod_check_schema("construction-permits", expected = expected),
               "invalid spatial reference", class = "tampa_input_error")
})

test_that("a missing endpoint and a missing layer receive explicit drift reports", {
  case <- schema_test_case()
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    list(status = 404L, body = "")
  })
  report <- tbod_check_schema("construction-permits")
  expect_identical(report$status, "incompatible")
  expect_identical(report$issues$category, "endpoint_disappeared")
  expect_error(get_dataset("construction-permits"),
               "endpoint_disappeared", class = "tampa_schema_error")

  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    fixture_response(list(error = list(code = 404L,
      message = "Layer not found", details = list())))
  })
  report <- tbod_check_schema("construction-permits")
  expect_identical(report$status, "incompatible")
  expect_identical(report$issues$category, "endpoint_disappeared")
  expect_error(get_dataset("construction-permits"),
               "endpoint_disappeared", class = "tampa_schema_error")

  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    list(status = 410L, body = "")
  })
  report <- tbod_check_schema("construction-permits")
  expect_identical(report$status, "incompatible")
  expect_identical(report$issues$category, "endpoint_disappeared")
  expect_error(get_dataset("construction-permits"),
               "endpoint_disappeared", class = "tampa_schema_error")
})

test_that("schema inspection supports direct URLs and explicit expectations", {
  url <- "https://data.example.invalid/arcgis/rest/services/Public/Test/FeatureServer/0"
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  current <- tbod_schema(url, refresh = TRUE)
  expect_s3_class(current$fields, "tbl_df")
  expect_identical(current$object_id_field, "OBJECTID")
  expect_identical(tbod_check_schema(url)$status, "untracked")
  expect_identical(tbod_check_schema(url, expected = current)$status, "unchanged")
  expect_error(tbod_schema(url), "no bundled expected schema",
               class = "tampa_input_error")
})

test_that("schema inspection accepts stable IDs from a custom portal", {
  portal <- "https://enterprise.example.org/arcgis/sharing/rest"
  endpoint <- "https://services.example.org/arcgis/rest/services/Water/FeatureServer/0"
  item_id <- strrep("c", 32L)
  stable_id <- paste0("arcgis:", item_id, ":0")
  item <- discovery_test_item(item_id, endpoint, org = "UnbundledOrg1234")
  resources <- list()
  resources[[paste0(portal, "/content/items/", item_id)]] <- item
  metadata <- fixture_metadata()
  metadata$id <- 0L
  resources[[endpoint]] <- metadata
  transport <- discovery_test_transport(resources = resources)
  local_mocked_bindings(arcgis_http = transport$http)

  current <- tbod_schema(stable_id, refresh = TRUE, portal = portal)
  expect_identical(current$endpoint, endpoint)
  expect_identical(tbod_check_schema(stable_id, portal = portal)$status,
                   "untracked")
  expect_identical(tbod_check_schema(stable_id, expected = current,
                                     portal = portal)$status, "unchanged")
  expect_error(tbod_check_schema("construction-permits", portal = portal),
               "portal.*only", class = "tampa_input_error")
})

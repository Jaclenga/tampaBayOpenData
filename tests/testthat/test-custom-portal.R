test_that("a custom portal uses its own public organization metadata and retrieval path", {
  portal <- "https://atlas.example.org/portal/sharing/rest"
  org <- "ExampleOrg123456"
  item_id <- strrep("f", 32L)
  endpoint <- "https://services.example.org/arcgis/rest/services/Roads/FeatureServer/0"
  item <- discovery_test_item(item_id, endpoint, org = org)
  pages <- list()
  pages[[paste0(portal, "/search/1")]] <- list(
    total = 1L, start = 1L, nextStart = -1L, results = list(item))
  metadata <- fixture_metadata()
  metadata$id <- 0L
  resources <- list()
  resources[[paste0(portal, "/portals/self")]] <-
    list(id = org, name = "Example Mapping Agency")
  resources[[endpoint]] <- metadata
  discovery <- discovery_test_transport(pages, resources)
  features <- fixture_transport(metadata = metadata)
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    if (grepl("/query$", url)) features$http(url, params, timeout) else
      discovery$http(url, params, timeout)
  }, .package = "tampaBayOpenData")

  found <- .discover_custom_portal(portal, query = "roads", max_items = 2)
  expect_identical(found$id, paste0("arcgis:", item_id, ":0"))
  expect_identical(found$portal, portal)
  expect_identical(found$publisher, "Example Mapping Agency")
  expect_identical(found$jurisdiction, "unspecified")
  expect_identical(attr(found, "discovery_scanned_items"), c(custom = 1L))
  search <- Filter(function(x) grepl("/search$", x$url), discovery$state$requests)
  expect_length(search, 1L)
  expect_match(search[[1L]]$params$q, paste0("orgid:", org), fixed = TRUE)

  data <- get_dataset(found, fields = "OBJECTID", limit = 1)
  expect_identical(data$OBJECTID, 1L)
  expect_identical(dataset_provenance(data)$portal, portal)
  expect_identical(dataset_provenance(data)$validation_status, "discovered")
})

test_that("explicit custom portal identity skips self and rejects conflicting items", {
  portal <- "https://outside.example.org/sharing/rest"
  org <- "OtherAgency12345"
  endpoint <- "https://services.example.org/arcgis/rest/services/Parcel/FeatureServer/0"
  good <- discovery_test_item(strrep("a", 32L), endpoint, org = org)
  wrong <- discovery_test_item(strrep("b", 32L), endpoint,
                               org = "DifferentOrg1234")
  pages <- list()
  pages[[paste0(portal, "/search/1")]] <- list(
    total = 2L, start = 1L, nextStart = -1L, results = list(good, wrong))
  resources <- list()
  resources[[endpoint]] <- list(id = 0L, name = "Parcels",
                                type = "Feature Layer",
                                geometryType = "esriGeometryPolygon")
  transport <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  found <- .discover_custom_portal(portal, org_id = org,
                                   publisher = "Other Agency", jurisdiction = "elsewhere")
  expect_identical(found$id, paste0("arcgis:", good$id, ":0"))
  expect_identical(found$publisher, "Other Agency")
  expect_identical(found$jurisdiction, "elsewhere")
  expect_length(attr(found, "discovery_issues"), 1L)
  urls <- vapply(transport$state$requests, `[[`, character(1), "url")
  expect_false(paste0(portal, "/portals/self") %in% urls)
})

test_that("stable item lookup accepts unbundled portal roots and organizations", {
  portal <- "https://enterprise.example.org/arcgis/sharing/rest"
  endpoint <- "https://services.example.org/arcgis/rest/services/Water/FeatureServer/0"
  item_id <- strrep("c", 32L)
  item <- discovery_test_item(item_id, endpoint, org = "UnbundledOrg1234")
  resources <- list()
  resources[[paste0(portal, "/content/items/", item_id)]] <- item
  resources[[endpoint]] <- list(id = 0L, name = "Water",
                                type = "Feature Layer",
                                geometryType = "esriGeometryPolyline")
  transport <- discovery_test_transport(resources = resources)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  found <- .discover_arcgis_item(item_id, 0L, portal = portal)
  expect_identical(found$id, paste0("arcgis:", item_id, ":0"))
  expect_identical(found$portal, portal)
  expect_identical(found$publisher, "Unknown ArcGIS publisher")
  expect_identical(found$jurisdiction, "unspecified")
})

test_that("custom portals with no public organization ID disclose an unscoped search", {
  portal <- "https://public.example.org/sharing/rest"
  endpoint <- "https://services.example.org/arcgis/rest/services/Public/FeatureServer/0"
  item <- discovery_test_item(strrep("d", 32L), endpoint,
                              org = "AnyOtherOrg12345")
  pages <- list()
  pages[[paste0(portal, "/search/1")]] <- list(
    total = 1L, start = 1L, nextStart = -1L, results = list(item))
  resources <- list()
  resources[[endpoint]] <- list(id = 0L, name = "Public",
                                type = "Feature Layer",
                                geometryType = "esriGeometryPoint")
  transport <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  expect_warning(found <- .discover_custom_portal(portal, max_items = 1),
                 "did not expose an organization ID")
  expect_identical(found$publisher, "Unknown ArcGIS publisher")
  search <- Filter(function(x) grepl("/search$", x$url), transport$state$requests)
  expect_identical(search[[1L]]$params$q,
                   '(type:"Feature Service" OR type:"Map Service")')
})

test_that("FeatureServer roots enumerate retrievable layers with a bounded scan", {
  root <- "https://services.example.org/arcgis/rest/services/Example/FeatureServer"
  first <- paste0(root, "/0")
  second <- paste0(root, "/2")
  metadata <- fixture_metadata()
  metadata$id <- 0L
  metadata$name <- "Example roads"
  resources <- list()
  resources[[root]] <- list(layers = list(
    list(id = 0L, name = "Example roads", type = "Feature Layer"),
    list(id = 2L, name = "Example places", type = "Feature Layer")),
    tables = list())
  resources[[first]] <- metadata
  second_metadata <- metadata
  second_metadata$id <- 2L
  second_metadata$name <- "Example places"
  resources[[second]] <- second_metadata
  discovery <- discovery_test_transport(resources = resources)
  features <- fixture_transport(metadata = metadata)
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    if (grepl("/query$", url)) features$http(url, params, timeout) else
      discovery$http(url, params, timeout)
  }, .package = "tampaBayOpenData")

  found <- .discover_custom_portal(root, max_items = 1,
                                   publisher = "Example Department")
  expect_identical(found$source_url, first)
  expect_identical(found$validation_status, "not_checked")
  expect_identical(found$item_id, NA_character_)
  expect_identical(found$publisher, "Example Department")
  expect_identical(attr(found, "discovery_truncated_portals"), "service")
  data <- get_dataset(found, fields = "OBJECTID", limit = 1)
  expect_identical(data$OBJECTID, 1L)
  expect_identical(dataset_provenance(data)$validation_status, "not_checked")

  filtered <- .discover_custom_portal(root, query = "places", max_items = 2)
  expect_identical(filtered$source_url, second)
  expect_true(attr(filtered, "discovery_complete"))
})

test_that("custom portal roots reject local hosts and ambiguous URL forms", {
  invalid <- c(
    "http://example.org/sharing/rest",
    "https://127.0.0.1/sharing/rest",
    "https://localhost/sharing/rest",
    "https://internal.local/sharing/rest",
    "https://user:secret@example.org/sharing/rest",
    "https://example.org/sharing/rest?token=secret",
    "https://example.org/../sharing/rest",
    "https://example.org/%2e%2e/sharing/rest",
    "https://example.org/sharing/rest/"
  )
  for (portal in invalid) {
    expect_error(.discover_custom_portal(portal, max_items = 0),
                 class = "tampa_input_error", info = portal)
  }
  expect_error(.discover_custom_portal("https://example.org/sharing/rest",
                                      org_id = "orgid:injected", max_items = 0),
               "org_id", class = "tampa_input_error")
})

test_that("portal discovery pages, expands layers and tables, and deduplicates by URL", {
  city <- "https://tampa.maps.arcgis.com/sharing/rest"
  root <- "https://example.org/arcgis/rest/services/Mixed/FeatureServer"
  a <- strrep("a", 32L)
  b <- strrep("b", 32L)
  c <- strrep("c", 32L)
  malformed <- list(id = "broken", type = "Feature Service", url = root)
  pages <- list()
  pages[[paste0(city, "/search/1")]] <- list(
    total = 4L, start = 1L, num = 100L, nextStart = 3L,
    results = list(discovery_test_item(a, root, "Mixed service"), malformed))
  pages[[paste0(city, "/search/3")]] <- list(
    total = 4L, start = 3L, num = 100L, nextStart = -1L,
    results = list(discovery_test_item(b, paste0(root, "/0"), "Road locations"),
                   discovery_test_item(c, paste0(root, "/999"), "Stale layer")))
  resources <- list()
  resources[[root]] <- list(layers = list(
    list(id = 0L, name = "Roads", type = "Feature Layer",
         geometryType = "esriGeometryPolyline"),
    list(id = 9L, name = "Group", type = "Group Layer", subLayerIds = list(0L)),
    list(id = "bad", name = "Malformed", type = "Feature Layer")),
    tables = list(list(id = 1L, name = "Inspections", type = "Table")))
  resources[[paste0(root, "/0")]] <- list(
    id = 0L, name = "Roads", type = "Feature Layer",
    geometryType = "esriGeometryPolyline", capabilities = "Query")
  resources[[paste0(root, "/1")]] <- list(
    id = 1L, name = "Inspections", type = "Table", capabilities = "Query")
  transport <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  found <- .discover_arcgis(query = "roads", portals = "city")
  expect_s3_class(found, "tbl_df")
  expect_identical(found$source_url, c(paste0(root, "/1"), paste0(root, "/0")))
  expect_identical(found$id[found$layer_id == 0L], paste0("arcgis:", b, ":0"))
  expect_identical(found$title[found$layer_id == 0L], "Road locations")
  expect_identical(found$geometry_type[found$layer_id == 1L], "none")
  expect_identical(found$validation_status, rep("discovered", 2L))
  expect_identical(found$portal, rep(city, 2L))
  expect_true(all(vapply(found$original_metadata, is.list, logical(1))))
  expect_s3_class(found$modified, "POSIXct")
  expect_length(attr(found, "discovery_issues"), 3L)
  expect_false(attr(found, "discovery_complete"))
  expect_identical(attr(found, "discovery_scanned_items"), c(city = 4L))
  searches <- Filter(function(x) grepl("/search$", x$url), transport$state$requests)
  expect_identical(vapply(searches, function(x) x$params$start, numeric(1)), c(1, 3))
  expect_true(all(vapply(searches, function(x)
    grepl('"roads"', x$params$q, fixed = TRUE), logical(1))))
})

test_that("portal root summaries are expanded from full layer metadata", {
  city <- "https://tampa.maps.arcgis.com/sharing/rest"
  root <- "https://example.org/arcgis/rest/services/Summary/FeatureServer"
  item_id <- strrep("f", 32L)
  pages <- list()
  pages[[paste0(city, "/search/1")]] <- list(
    total = 1L, start = 1L, nextStart = -1L,
    results = list(discovery_test_item(item_id, root)))
  resources <- list()
  resources[[root]] <- list(layers = list(
    list(id = 0L, name = "Roads"),
    list(id = 1L, name = "Display only"),
    list(id = 2L, name = "Stale")),
    tables = list(list(id = 3L, name = "Inspections")))
  resources[[paste0(root, "/0")]] <- list(
    id = 0L, name = "Roads", type = "Feature Layer",
    geometryType = "esriGeometryPolyline", capabilities = "Query")
  resources[[paste0(root, "/1")]] <- list(
    id = 1L, name = "Display only", type = "Feature Layer",
    geometryType = "esriGeometryPoint", capabilities = "Map")
  resources[[paste0(root, "/3")]] <- list(
    id = 3L, name = "Inspections", type = "Table", capabilities = "Query")
  transport <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  found <- .discover_arcgis(portals = "city")
  expect_setequal(found$layer_id, c(0L, 3L))
  expect_identical(found$geometry_type[found$layer_id == 0L],
                   "esriGeometryPolyline")
  expect_identical(found$geometry_type[found$layer_id == 3L], "none")
  expect_length(attr(found, "discovery_issues"), 1L)
  expect_match(attr(found, "discovery_issues"), "Layer 2")
  expect_false(attr(found, "discovery_complete"))
  requested <- vapply(transport$state$requests, `[[`, character(1), "url")
  expect_setequal(requested, c(paste0(city, "/search"), root,
                               paste0(root, "/", 0:3)))
})

test_that("malformed service roots are reported instead of looking empty", {
  city <- "https://tampa.maps.arcgis.com/sharing/rest"
  root <- "https://example.org/arcgis/rest/services/Broken/FeatureServer"
  item_id <- strrep("a", 32L)
  pages <- list()
  pages[[paste0(city, "/search/1")]] <- list(
    total = 1L, start = 1L, nextStart = -1L,
    results = list(discovery_test_item(item_id, root)))
  resources <- list()
  resources[[root]] <- list(name = "Broken")
  transport <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  found <- .discover_arcgis(portals = "city")
  expect_equal(nrow(found), 0L)
  expect_false(attr(found, "discovery_complete"))
  expect_match(attr(found, "discovery_issues"), "layer or table arrays")
  expect_error(.discover_custom_portal(root), "layer or table arrays",
               class = "tampa_response_error")
})

test_that("invalid custom portal search text is rejected before a request", {
  transport <- discovery_test_transport()
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  expect_error(.discover_custom_portal(
    "https://portal.example.org/sharing/rest", query = NA_character_),
    class = "tampa_input_error")
  expect_length(transport$state$requests, 0L)
})

test_that("portal searches include queryable Map Service items", {
  city <- "https://tampa.maps.arcgis.com/sharing/rest"
  endpoint <- "https://example.org/arcgis/rest/services/Map/MapServer/4"
  item_id <- strrep("e", 32L)
  pages <- list()
  pages[[paste0(city, "/search/1")]] <- list(
    total = 1L, start = 1L, nextStart = -1L,
    results = list(discovery_test_item(item_id, endpoint,
                                       type = "Map Service")))
  resources <- list()
  resources[[endpoint]] <- list(
    id = 4L, name = "Map parcels", type = "Feature Layer",
    geometryType = "esriGeometryPolygon", capabilities = "Query")
  transport <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  found <- .discover_arcgis(portals = "city")
  expect_identical(found$source_url, endpoint)
  expect_identical(found$service_type, "MapServer")
  search <- Filter(function(x) grepl("/search$", x$url), transport$state$requests)
  expect_match(search[[1L]]$params$q,
               '(type:"Feature Service" OR type:"Map Service")', fixed = TRUE)
})

test_that("regional discovery uses its own organization and metadata", {
  city <- "https://tampa.maps.arcgis.com/sharing/rest"
  regional <- "https://www.arcgis.com/sharing/rest"
  root_city <- "https://example.org/arcgis/rest/services/City/FeatureServer"
  root_regional <- "https://example.org/arcgis/rest/services/Region/FeatureServer"
  a <- strrep("a", 32L)
  b <- strrep("b", 32L)
  pages <- list()
  pages[[paste0(city, "/search/1")]] <- list(total = 1L, start = 1L, num = 100L,
    nextStart = -1L, results = list(discovery_test_item(a, paste0(root_city, "/0"))))
  pages[[paste0(regional, "/search/1")]] <- list(total = 1L, start = 1L, num = 100L,
    nextStart = -1L, results = list(discovery_test_item(b, paste0(root_regional, "/0"),
                                             org = "RgIBbQIF0Y6T3AX6")))
  resources <- list()
  resources[[paste0(root_city, "/0")]] <- list(id = 0L, name = "City",
    type = "Feature Layer", geometryType = "esriGeometryPoint")
  resources[[paste0(root_regional, "/0")]] <- list(id = 0L, name = "Region",
    type = "Feature Layer", geometryType = "esriGeometryPolygon")
  transport <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  found <- .discover_arcgis(portals = c("city", "tbrpc"))
  expect_setequal(found$jurisdiction, c("tampa", "tampa-bay"))
  expect_identical(found$publisher[found$jurisdiction == "tampa-bay"],
                   "Tampa Bay Regional Planning Council")
  expect_identical(found$portal[found$jurisdiction == "tampa-bay"], regional)
  searches <- Filter(function(x) grepl("/search$", x$url), transport$state$requests)
  expect_length(searches, 2L)
  expect_true(any(grepl("orgid:IbNXlmt2RVVRCZ6M", vapply(searches,
    function(x) x$params$q, character(1)), fixed = TRUE)))
  expect_true(any(grepl("orgid:RgIBbQIF0Y6T3AX6", vapply(searches,
    function(x) x$params$q, character(1)), fixed = TRUE)))
})

test_that("search items reject a conflicting organization ID", {
  city <- .portal_registry()$city
  other <- .portal_registry()$tbrpc
  ids <- c(strrep("a", 32L), strrep("b", 32L), strrep("c", 32L))
  endpoints <- paste0("https://example.org/arcgis/rest/services/Org", 1:3,
                      "/FeatureServer/0")
  valid <- discovery_test_item(ids[[1L]], endpoints[[1L]], org = city$org_id)
  wrong <- discovery_test_item(ids[[2L]], endpoints[[2L]], org = other$org_id)
  missing <- discovery_test_item(ids[[3L]], endpoints[[3L]], org = city$org_id)
  missing$orgId <- NULL
  pages <- list()
  pages[[paste0(city$root, "/search/1")]] <- list(
    total = 3L, start = 1L, nextStart = -1L,
    results = list(valid, wrong, missing))
  resources <- setNames(rep(list(list(id = 0L, name = "Point",
    type = "Feature Layer", geometryType = "esriGeometryPoint")), 3L),
    endpoints)
  transport <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  found <- .discover_arcgis(portals = "city")
  expect_setequal(found$id, paste0("arcgis:", ids[c(1L, 3L)], ":0"))
  expect_identical(found$publisher, rep(city$publisher, 2L))
  expect_identical(attr(found, "discovery_scanned_items"), c(city = 3L))
  expect_length(attr(found, "discovery_issues"), 1L)
  expect_match(attr(found, "discovery_issues"),
               "Item organization ID differs from the selected portal", fixed = TRUE)
  expect_false(attr(found, "discovery_complete"))
  requested <- vapply(transport$state$requests, `[[`, character(1), "url")
  expect_setequal(requested, c(paste0(city$root, "/search"), endpoints[c(1L, 3L)]))
})

test_that("stable item IDs resolve globally without relying on search rank", {
  regional <- "https://www.arcgis.com/sharing/rest"
  root <- "https://example.org/arcgis/rest/services/Region/FeatureServer"
  id <- strrep("d", 32L)
  resources <- list()
  resources[[paste0(regional, "/content/items/", id)]] <-
    discovery_test_item(id, root, org = "RgIBbQIF0Y6T3AX6")
  resources[[paste0("https://tampa.maps.arcgis.com/sharing/rest/content/items/", id)]] <-
    discovery_test_item(id, root, org = "RgIBbQIF0Y6T3AX6")
  resources[[root]] <- list(layers = list(
    list(id = 0L, name = "One", type = "Feature Layer",
         geometryType = "esriGeometryPoint"),
    list(id = 3L, name = "Three", type = "Feature Layer",
         geometryType = "esriGeometryPolygon")), tables = list())
  resources[[paste0(root, "/0")]] <- list(
    id = 0L, name = "One", type = "Feature Layer",
    geometryType = "esriGeometryPoint", capabilities = "Query")
  resources[[paste0(root, "/3")]] <- list(
    id = 3L, name = "Three", type = "Feature Layer",
    geometryType = "esriGeometryPolygon", capabilities = "Query")
  transport <- discovery_test_transport(resources = resources)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  one <- .discover_arcgis_item(id, 3L, portal = "all")
  expect_identical(one$id, paste0("arcgis:", id, ":3"))
  expect_identical(one$jurisdiction, "tampa-bay")
  expect_identical(one$portal, regional)
  expect_equal(nrow(.discover_arcgis_item(id, 8L)), 0L)
  expect_equal(nrow(.discover_arcgis_item(id, 3L, portal = "city")), 0L)
  expect_error(.discover_arcgis_item("bad"), "32-character", class = "tampa_input_error")
})

test_that("stable item lookup ignores a different returned item ID", {
  lookup <- "https://www.arcgis.com/sharing/rest"
  requested_id <- strrep("a", 32L)
  returned_id <- strrep("b", 32L)
  endpoint <- "https://example.org/arcgis/rest/services/Wrong/FeatureServer/0"
  resources <- list()
  resources[[paste0(lookup, "/content/items/", requested_id)]] <-
    discovery_test_item(returned_id, endpoint)
  resources[[endpoint]] <- list(id = 0L, name = "Wrong",
    type = "Feature Layer", geometryType = "esriGeometryPoint")
  transport <- discovery_test_transport(resources = resources)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  found <- .discover_arcgis_item(requested_id, 0L)
  expect_equal(nrow(found), 0L)
  requested <- vapply(transport$state$requests, `[[`, character(1), "url")
  expect_identical(requested, paste0(lookup, "/content/items/", requested_id))
})

test_that("empty search and malformed pages have explicit outcomes", {
  city <- "https://tampa.maps.arcgis.com/sharing/rest"
  pages <- list()
  pages[[paste0(city, "/search/1")]] <- list(total = 0L, start = 1L, num = 100L,
                                               nextStart = -1L, results = list())
  transport <- discovery_test_transport(pages)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  empty <- .discover_arcgis(query = "  ", portals = "city")
  expect_equal(nrow(empty), 0L)
  expect_true(attr(empty, "discovery_complete"))
  expect_identical(attr(empty, "discovery_scanned_items"), c(city = 0L))
  expect_true(all(c("id", "item_id", "original_metadata", "validation_status") %in%
                    names(empty)))
  expect_identical(.discovery_query("  "), .discovery_query(NULL))
  zero <- .discover_arcgis(portals = "city", max_items = 0)
  expect_equal(nrow(zero), 0L)
  expect_true(attr(zero, "discovery_complete"))
  expect_identical(attr(zero, "discovery_scanned_items"), c(city = 0L))
  expect_length(transport$state$requests, 1L)

  pages[[paste0(city, "/search/1")]] <- list(total = 2L, start = 1L, num = 100L,
                                               nextStart = 1L, results = list())
  bad <- discovery_test_transport(pages)
  local_mocked_bindings(arcgis_http = bad$http, .package = "tampaBayOpenData")
  expect_error(.discover_arcgis(portals = "city"), "malformed search pagination",
               class = "tampa_discovery_error")
})

test_that("unsafe, unsupported, and non-queryable item URLs are isolated", {
  city <- "https://tampa.maps.arcgis.com/sharing/rest"
  good <- "https://example.org/arcgis/rest/services/Good/FeatureServer/0"
  urls <- c("http://example.org/FeatureServer/0",
            "https://localhost/FeatureServer/0",
            "https://127.0.0.1/FeatureServer/0",
            "https://example.org@localhost/FeatureServer/0",
            "https://example.org/FeatureServer/0?token=secret",
            "https://example.org/ImageServer/0", good)
  ids <- vapply(seq_along(urls), function(x) paste0(strrep("0", 31L), x),
                character(1))
  items <- unname(Map(discovery_test_item, ids, urls))
  pages <- list()
  pages[[paste0(city, "/search/1")]] <- list(total = length(items), start = 1L,
    num = 100L, nextStart = -1L, results = items)
  resources <- list()
  resources[[good]] <- list(id = 0L, name = "Good", type = "Feature Layer",
                            geometryType = "esriGeometryPoint", capabilities = "Query")
  transport <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  found <- .discover_arcgis(portals = "city")
  expect_identical(found$source_url, good)
  expect_length(attr(found, "discovery_issues"), 6L)
  requested <- vapply(transport$state$requests, function(x) x$url, character(1))
  expect_setequal(requested, c(paste0(city, "/search"), good))
})

test_that("one failed portal keeps the other provider and both failures are explicit", {
  regional <- "https://www.arcgis.com/sharing/rest"
  root <- "https://example.org/arcgis/rest/services/Region/FeatureServer/0"
  id <- strrep("e", 32L)
  pages <- list()
  pages[[paste0(regional, "/search/1")]] <- list(total = 1L, start = 1L,
    num = 100L, nextStart = -1L,
    results = list(discovery_test_item(id, root, org = "RgIBbQIF0Y6T3AX6")))
  resources <- list()
  resources[[root]] <- list(id = 0L, name = "Regional point",
    type = "Feature Layer", geometryType = "esriGeometryPoint")
  transport <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")

  expect_warning(found <- .discover_arcgis(portals = c("city", "tbrpc")),
                 "partial results.*city")
  expect_identical(found$id, paste0("arcgis:", id, ":0"))
  expect_identical(attr(found, "discovery_failed_portals"), "city")
  expect_true(any(grepl("Portal city", attr(found, "discovery_issues"),
                        fixed = TRUE)))

  local_mocked_bindings(arcgis_http = function(...) fixture_response(list(), 503L),
                        .package = "tampaBayOpenData")
  expect_error(.discover_arcgis(portals = "all"), "All selected ArcGIS portals failed",
               class = "tampa_discovery_error")
})

test_that("a later page failure retains rows already found from the only portal", {
  city <- .portal_registry()$city
  endpoint <- "https://example.org/arcgis/rest/services/Partial/FeatureServer/0"
  item_id <- strrep("f", 32L)
  pages <- list()
  pages[[paste0(city$root, "/search/1")]] <- list(
    total = 2L, start = 1L, nextStart = 2L,
    results = list(discovery_test_item(item_id, endpoint, org = city$org_id)))
  resources <- list()
  resources[[endpoint]] <- list(id = 0L, name = "Partial",
    type = "Feature Layer", geometryType = "esriGeometryPoint")
  transport <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = transport$http,
                        .package = "tampaBayOpenData")

  expect_warning(found <- .discover_arcgis(portals = "city"),
                 "partial results.*city")
  expect_identical(found$id, paste0("arcgis:", item_id, ":0"))
  expect_identical(attr(found, "discovery_scanned_items"), c(city = 1L))
  expect_identical(attr(found, "discovery_failed_portals"), "city")
  expect_false(attr(found, "discovery_complete"))
})

test_that("live City discovery returns an item with a stable service layer identity", {
  skip_if_not(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
              "Set TAMPA_OPEN_DATA_LIVE=true to opt into ArcGIS portal calls")
  found <- .discover_arcgis("permits", portals = "city", max_items = 10, timeout = 15)
  expect_gt(nrow(found), 0L)
  expect_true(all(grepl("^arcgis:[[:xdigit:]]{32}:[0-9]+$", found$id)))
  expect_true(all(grepl("^https://", found$source_url)))
  expect_true(all(found$validation_status == "discovered"))
})

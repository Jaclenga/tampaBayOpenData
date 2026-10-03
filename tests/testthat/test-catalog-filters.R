catalog_filter_fixture <- function() {
  parks <- dataset_info("parks")
  data <- tibble::tibble(
    id = paste0("arcgis:", vapply(letters[1:5], strrep, character(1), times = 32), ":0"),
    title = c("Portal parks", "County libraries", "County roads", "Budget table", "Unknown geometry"),
    description = rep("Synthetic catalog description", 5),
    jurisdiction = c("tampa", "hillsborough", "pinellas", "pinellas", "stpete"),
    publisher = c("City of Tampa", "Hillsborough County", "Pinellas County",
                  "Pinellas County", "City of St. Petersburg"),
    source_url = c(parks$source_url,
      paste0("https://example.org/arcgis/rest/services/Filter", 2:5, "/FeatureServer/0")),
    service_url = c(parks$service_url,
      paste0("https://example.org/arcgis/rest/services/Filter", 2:5, "/FeatureServer")),
    layer_id = rep(0L, 5),
    item_id = vapply(letters[1:5], strrep, character(1), times = 32),
    portal = c("https://tampa.maps.arcgis.com/sharing/rest",
      "https://hillsborough.maps.arcgis.com/sharing/rest",
      rep("https://pinellas-egis.maps.arcgis.com/sharing/rest", 2),
      "https://csp.maps.arcgis.com/sharing/rest"),
    geometry_type = c("esriGeometryPolygon", "esriGeometryPoint", "esriGeometryPolyline", "none", NA),
    tags = list("unique live tag", "libraries", c("roads", "route [A]"), "accounts", character()),
    categories = list("/Topics/Recreation", "/Topics/Education", "/Topics/Transportation",
                       "/Topics/Finance", NA_character_),
    modified = as.POSIXct(c("2026-01-01 12:00:00", "2026-01-03 10:00:00",
      "2026-01-02 23:59:59", "2026-01-03 00:00:00", NA), tz = "UTC"),
    service_type = c("MapServer", rep("FeatureServer", 4)),
    layer_type = c(rep("Feature Layer", 3), "Table", "Feature Layer"),
    validation_status = rep("discovered", 5),
    original_metadata = rep(list(list(item = list(title = "Synthetic"))), 5)
  )
  attr(data, "discovery_complete") <- FALSE
  attr(data, "discovery_truncated_portals") <- "pinellas"
  attr(data, "discovery_scanned_items") <- c(city = 1L, hillsborough = 1L, pinellas = 2L, stpete = 1L)
  attr(data, "discovery_issues") <- "synthetic skipped item"
  attr(data, "discovery_failed_portals") <- character()
  state <- new.env(parent = emptyenv())
  state$calls <- list()
  discover <- function(query, portals, max_items, timeout) {
    state$calls[[length(state$calls) + 1L]] <- list(query = query, portals = portals)
    data
  }
  list(data = data, state = state, discover = discover)
}

test_that("jurisdiction and publisher filter both catalogs and select the portal scan", {
  fixture <- catalog_filter_fixture()
  local_mocked_bindings(.discover_arcgis = fixture$discover)
  pinellas <- list_datasets(jurisdiction = "pinellas", source = "live")
  expect_identical(pinellas$title, c("County roads", "Budget table"))
  expect_identical(fixture$state$calls[[1]]$portals, "pinellas")
  hillsborough <- search_datasets("libraries", publisher = "HILLSBOROUGH COUNTY")
  expect_identical(hillsborough$title, "County libraries")
  expect_identical(fixture$state$calls[[2]]$portals, "hillsborough")
  both <- list_datasets(jurisdiction = c("hillsborough", "pinellas"),
                        publisher = c("Hillsborough County", "Pinellas County"))
  expect_setequal(both$title, c("County libraries", "County roads", "Budget table"))
  expect_identical(fixture$state$calls[[3]]$portals, c("hillsborough", "pinellas"))
  expect_identical(nrow(list_datasets(jurisdiction = "hillsborough", source = "checked")), 0L)
  expect_identical(nrow(list_datasets(jurisdiction = "tampa-bay", source = "checked")), 0L)
  expect_identical(nrow(list_datasets(source = "checked")), 26L)
  expect_identical(nrow(list_datasets(jurisdiction = "tampa", source = "checked")), 20L)
})

test_that("empty source intersections and unmatched publishers dispatch no HTTP", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"))
  incompatible <- list_datasets(jurisdiction = "pinellas", portals = "city", source = "live")
  expect_identical(nrow(incompatible), 0L)
  expect_true(attr(incompatible, "discovery_complete"))
  expect_length(attr(incompatible, "discovery_scanned_items"), 0L)
  expect_identical(nrow(search_datasets("roads", publisher = "Unknown publisher")), 0L)
  checked <- list_datasets(portals = "city", publisher = "City of St. Petersburg")
  expect_identical(nrow(checked), 3L)
  expect_true(all(checked$validation_status == "checked"))
})

test_that("status, geometry and thematic filters combine OR within and AND across facets", {
  fixture <- catalog_filter_fixture()
  local_mocked_bindings(.discover_arcgis = fixture$discover)
  checked <- list_datasets(source = "live", validation_status = "checked")
  expect_identical(checked$id, "parks")
  discovered <- list_datasets(source = "live", validation_status = "discovered")
  expect_identical(nrow(discovered), 4L)
  expect_true(all(discovered$validation_status == "discovered"))
  expect_identical(nrow(list_datasets(source = "checked", validation_status = "discovered")), 0L)
  spatial <- list_datasets(source = "live", spatial = TRUE)
  expect_setequal(spatial$title, c(dataset_info("parks")$title, "County libraries", "County roads"))
  tables <- list_datasets(source = "live", spatial = FALSE)
  expect_identical(tables$title, "Budget table")
  topic <- search_datasets("", source = "live", validation_status = "discovered",
    spatial = TRUE, topic = c("LIBRAR", "road"))
  expect_setequal(topic$title, c("County libraries", "County roads"))
  expect_identical(search_datasets("", source = "live", category = "TRANSPORTATION")$title, "County roads")
  expect_identical(list_datasets(source = "live", category = "/Topics/Transportation")$title, "County roads")
  expect_identical(list_datasets(source = "live", topic = "[A]")$title, "County roads")
  expect_identical(nrow(list_datasets(source = "live", topic = "road.*")), 0L)
  expect_identical(nrow(list_datasets(source = "live", jurisdiction = "stpete", topic = "na")), 0L)
  empty <- list_datasets(source = "live", spatial = FALSE, category = "Transportation")
  expect_identical(nrow(empty), 0L)
  expect_false(attr(empty, "discovery_complete"))
  expect_identical(attr(empty, "discovery_truncated_portals"), "pinellas")
  expect_identical(attr(empty, "discovery_issues"), "synthetic skipped item")
  expect_identical(attr(empty, "discovery_scanned_items"), attr(fixture$data, "discovery_scanned_items"))
})

test_that("modification dates include complete UTC days and honor exact zoned instants", {
  fixture <- catalog_filter_fixture()
  local_mocked_bindings(.discover_arcgis = fixture$discover)
  day <- list_datasets(source = "live", modified_after = "2026-01-02",
                        modified_before = as.Date("2026-01-02"))
  expect_identical(day$title, "County roads")
  through_midnight <- list_datasets(source = "live", modified_after = "2026-01-02",
    modified_before = as.POSIXct("2026-01-03 00:00:00", tz = "UTC"))
  expect_setequal(through_midnight$title, c("County roads", "Budget table"))
  instant <- as.POSIXct("2026-01-02 18:59:59", tz = "America/New_York")
  exact <- list_datasets(source = "live", modified_after = instant, modified_before = instant)
  expect_identical(exact$title, "County roads")
  expect_identical(nrow(list_datasets(source = "live", modified_after = "2026-01-04")), 0L)
  known <- list_datasets(source = "live", modified_before = "2026-01-03")
  expect_identical(nrow(known), 4L)
  expect_false(anyNA(known$modified))
  expect_identical(attr(known$modified, "tzone"), "UTC")
})

test_that("checked overlays retain live facets and modification origin without changing identity", {
  fixture <- catalog_filter_fixture()
  local_mocked_bindings(.discover_arcgis = fixture$discover)
  original <- list_datasets(source = "checked")
  original <- original[original$id == "parks", , drop = FALSE]
  live <- list_datasets(source = "live", validation_status = "checked",
    topic = "unique live tag", category = "Recreation", modified_before = "2026-01-01")
  expect_identical(live$id, "parks")
  for (field in c("title", "publisher", "jurisdiction", "source_url", "service_url",
                   "verified", "terms", "date_fields")) {
    expect_identical(live[[field]], original[[field]], info = field)
  }
  expect_identical(live$modified_source, "portal_item")
  expect_identical(live$modified, fixture$data$modified[1])
  expect_true(all(original$tags[[1]] %in% live$tags[[1]]))
  expect_true("unique live tag" %in% live$tags[[1]])
  expect_true("/Topics/Recreation" %in% live$categories[[1]])
  expect_identical(live$original_metadata[[1]]$discovery, fixture$data$original_metadata[[1]])
  expect_identical(dataset_info(live)$validation_status, "checked")
  expect_false(attr(live, "discovery_complete"))
})

test_that("unknown checked modification times do not inherit verification dates", {
  entries <- .read_registry()[1:2]
  entries[[1]]$upstream_modified <- NULL
  entries[[2]]$upstream_modified <- "2026-01-02T23:59:59+00:00"
  local_mocked_bindings(.read_registry = function() entries,
                        arcgis_http = function(...) stop("unexpected network"))
  all <- list_datasets(source = "checked")
  expect_true(is.na(all$modified[1]))
  expect_true(is.na(all$modified_source[1]))
  expect_identical(all$modified_source[2], "checked_snapshot")
  bounded <- list_datasets(source = "checked", modified_before = "2026-01-02")
  expect_identical(bounded$id, entries[[2]]$id)
  expect_identical(nrow(search_datasets("", source = "checked", modified_after = "2026-01-03")), 0L)
})

test_that("invalid catalog filters fail before network access", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"))
  for (name in c("publisher", "topic", "category", "validation_status", "jurisdiction")) {
    for (value in list(NA_character_, "", character(), 1, list("tampa"))) {
      args <- list(source = "live")
      args[[name]] <- value
      expect_error(do.call(list_datasets, args), class = "tampa_input_error")
    }
  }
  expect_error(list_datasets(jurisdiction = c("all", "tampa")), "Unsupported jurisdiction")
  expect_error(list_datasets(validation_status = "not_checked"), "validation_status")
  for (value in list(NA, "yes", c(TRUE, FALSE), 1)) {
    expect_error(list_datasets(spatial = value), class = "tampa_input_error")
  }
  for (value in list("2026-02-30", "2026-1-01", "2026-01-01T12:00:00Z", NA, Inf, 1,
                      c("2026-01-01", "2026-01-02"), as.Date(NA))) {
    expect_error(list_datasets(modified_after = value), "modified_after", class = "tampa_input_error")
    expect_error(list_datasets(modified_before = value), "modified_before", class = "tampa_input_error")
  }
  expect_error(list_datasets(modified_after = "2026-01-03", modified_before = "2026-01-02"),
               "modified_after.*modified_before")
})

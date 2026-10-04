test_that("live catalog rows share the checked schema and search provenance", {
  checked <- list_datasets(source = "checked")
  parks <- checked[checked$id == "parks", , drop = FALSE]
  live <- tibble::tibble(
    id = c(paste0("arcgis:", strrep("a", 32), ":0"),
           paste0("arcgis:", strrep("b", 32), ":4")),
    title = c("Portal parks", "Synthetic regional housing"),
    description = c("Portal duplicate", "A queryable synthetic layer"),
    jurisdiction = c("tampa", "tampa-bay"),
    publisher = c("City of Tampa", "Tampa Bay Regional Planning Council"),
    source_url = c(parks$source_url,
                   "https://example.org/arcgis/rest/services/Housing/FeatureServer/4"),
    service_url = c(parks$service_url,
                    "https://example.org/arcgis/rest/services/Housing/FeatureServer"),
    layer_id = c(0L, 4L),
    item_id = c(strrep("a", 32), strrep("b", 32)),
    portal = c("https://tampa.maps.arcgis.com/sharing/rest",
               "https://www.arcgis.com/sharing/rest"),
    geometry_type = c("esriGeometryPolygon", "esriGeometryPoint"),
    tags = list("parks", c("housing", "regional")),
    categories = list("Recreation", "Housing"),
    modified = as.POSIXct(c("2026-01-01", "2026-02-01"), tz = "UTC"),
    service_type = c("MapServer", "FeatureServer"),
    layer_type = c("Feature Layer", "Feature Layer"),
    validation_status = c("discovered", "discovered"),
    original_metadata = list(list(item = "parks"), list(item = "housing"))
  )
  attr(live, "discovery_issues") <- "one skipped portal item"
  attr(live, "discovery_failed_portals") <- "tbrpc"
  calls <- list()
  local_mocked_bindings(.discover_arcgis = function(query, portals, max_items, timeout) {
    calls[[length(calls) + 1L]] <<- list(query = query, portals = portals,
                                        max_items = max_items, timeout = as.numeric(timeout))
    if (identical(query, "housing")) return(live[2L, , drop = FALSE])
    if (identical(query, "zzportalonlyzz")) return(live[1L, , drop = FALSE])
    if (identical(query, "parks")) return(live[0L, , drop = FALSE])
    live
  }, .package = "tampaBayOpenData")

  catalog <- list_datasets(max_items = 3, timeout = 12)
  expect_identical(nrow(catalog), 36L)
  expect_identical(names(catalog), names(checked))
  expect_identical(attr(catalog, "discovery_issues"), "one skipped portal item")
  expect_identical(attr(catalog, "discovery_failed_portals"), "tbrpc")
  expect_identical(catalog$validation_status[catalog$id == "parks"], "checked")
  expect_identical(catalog$title[catalog$id == "parks"], parks$title)
  expect_identical(sum(catalog$source_url == parks$source_url), 1L)
  expect_identical(catalog$validation_status[catalog$layer_id == 4L &
                                              catalog$publisher == "Tampa Bay Regional Planning Council"],
                   "discovered")
  expect_identical(calls[[1L]], list(query = NULL, portals = "all",
                                     max_items = 3, timeout = 12))

  portal_only <- list_datasets(source = "live", portals = "all")
  expect_identical(nrow(portal_only), 2L)
  expect_setequal(portal_only$validation_status, c("checked", "discovered"))
  expect_identical(calls[[2L]]$portals, "all")

  results <- search_datasets("housing", portals = "tbrpc")
  expect_identical(results$id, paste0("arcgis:", strrep("b", 32), ":4"))
  expect_identical(calls[[3L]]$query, "housing")
  expect_identical(calls[[3L]]$portals, "tbrpc")
  expect_identical(results$jurisdiction, "tampa-bay")
  info <- dataset_info(results)
  expect_identical(info$validation_status, "discovered")
  expect_identical(info$item_id, strrep("b", 32))

  expect_identical(nrow(search_datasets("zzportalonlyzz", source = "checked")), 0L)
  for (source in c("live", "all")) {
    result <- search_datasets("zzportalonlyzz", source = source)
    expect_identical(result$id, "parks")
    expect_identical(result$validation_status, "checked")
    expect_identical(result$title, parks$title)
    expect_identical(result$service_url, parks$service_url)
    expect_identical(nrow(result), 1L)
  }
  expect_identical(nrow(search_datasets("parks", source = "live")), 0L)
  expect_identical(search_datasets("parks", jurisdiction = "tampa", source = "all")$id, "parks")
})

test_that("checked catalog stays available when live discovery fails", {
  local_mocked_bindings(.discover_arcgis = function(...) {
    .abort("The portal is unavailable.", subclass = "tampa_http_error")
  }, .package = "tampaBayOpenData")
  expect_warning(all <- list_datasets(), "returning checked datasets only")
  expect_identical(nrow(all), 35L)
  expect_true(all(all$validation_status == "checked"))
  expect_error(list_datasets(source = "live"), "portal is unavailable")
  expect_silent(checked <- list_datasets(source = "checked"))
  expect_identical(nrow(checked), 35L)
})

test_that("catalog source and portal options reject invalid values", {
  expect_error(list_datasets(source = "unknown"), "source")
  expect_error(list_datasets(portals = c("all", "city")), "portals")
  expect_error(list_datasets(portals = c("city", "city")), "portals")
  expect_error(list_datasets(max_items = 0), "max_items")
  expect_error(list_datasets(timeout = 0), "timeout")
})

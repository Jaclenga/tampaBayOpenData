test_that("default public discovery queries all six configured organizations with an item bound", {
  expected_orgs <- c(city = "IbNXlmt2RVVRCZ6M", tbrpc = "RgIBbQIF0Y6T3AX6",
                     stpete = "9qPLjNtocjo438CJ", clearwater = "3GsNorcb0Mn5rMt8",
                     hillsborough = "apTfC6SUmnNfnxuF", pinellas = "f5HgUpxURgEzTccH")
  registry <- .portal_registry()
  expect_identical(vapply(registry, `[[`, character(1), "org_id"),
                   expected_orgs)
  pages <- resources <- list()
  for (i in seq_along(registry)) {
    config <- registry[[i]]
    endpoint <- paste0("https://example.org/arcgis/rest/services/City", i,
                       "/FeatureServer/0")
    item <- discovery_test_item(strrep(as.character(i), 32), endpoint,
                                 org = config$org_id)
    pages[[paste0(config$root, "/search/1")]] <- list(
      total = 1L, start = 1L, nextStart = -1L, results = list(item))
    resources[[endpoint]] <- list(id = 0L, name = paste("City", i),
      type = "Feature Layer", geometryType = "esriGeometryPoint", capabilities = "Query")
  }
  transport <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = transport$http)
  found <- tbod_list_datasets(source = "live")
  expect_setequal(found$jurisdiction, vapply(registry, `[[`, character(1), "jurisdiction"))
  expect_setequal(found$publisher, vapply(registry, `[[`, character(1), "publisher"))
  expect_true(attr(found, "discovery_complete"))
  expect_identical(attr(found, "discovery_scanned_items"),
                   setNames(rep(1L, length(registry)), names(registry)))
  expect_length(attr(found, "discovery_truncated_portals"), 0L)
  searches <- Filter(function(request) grepl("/search$", request$url),
                      transport$state$requests)
  expect_length(searches, length(registry))
  for (i in seq_along(searches)) {
    expect_equal(searches[[i]]$params$num, 25)
    expect_match(searches[[i]]$params$q, paste0("orgid:", expected_orgs[[i]]), fixed = TRUE)
  }
})

test_that("finite portal scans expose truncation and exhaustive opt-in clears it", {
  portal <- .portal_registry()$stpete
  endpoints <- paste0("https://example.org/arcgis/rest/services/Bounded", 1:3,
                       "/FeatureServer/0")
  items <- lapply(seq_along(endpoints), function(i) {
    discovery_test_item(strrep(as.character(i), 32), endpoints[[i]], org = portal$org_id)
  })
  pages <- list()
  pages[[paste0(portal$root, "/search/1")]] <- list(
    total = 3L, start = 1L, nextStart = 3L, results = items[1:2])
  pages[[paste0(portal$root, "/search/3")]] <- list(
    total = 3L, start = 3L, nextStart = -1L, results = items[3])
  resources <- setNames(rep(list(list(id = 0L, name = "Synthetic point",
    type = "Feature Layer", geometryType = "esriGeometryPoint")), 3), endpoints)
  bounded <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = bounded$http)
  found <- tbod_list_datasets(portals = "stpete", max_items = 2)
  expect_false(attr(found, "discovery_complete"))
  expect_identical(attr(found, "discovery_scanned_items"), c(stpete = 2L))
  expect_identical(attr(found, "discovery_truncated_portals"), "stpete")
  expect_length(attr(found, "discovery_issues"), 0L)
  expect_false(endpoints[[3L]] %in% found$source_url)
  searches <- Filter(function(request) grepl("/search$", request$url), bounded$state$requests)
  expect_length(searches, 1L)
  expect_equal(searches[[1L]]$params$num, 2)

  exhaustive <- discovery_test_transport(pages, resources)
  local_mocked_bindings(arcgis_http = exhaustive$http)
  all <- tbod_list_datasets(source = "live", portals = "stpete", max_items = Inf)
  expect_setequal(all$source_url, endpoints)
  expect_true(attr(all, "discovery_complete"))
  expect_identical(attr(all, "discovery_scanned_items"), c(stpete = 3L))
  expect_length(attr(all, "discovery_truncated_portals"), 0L)
})

test_that("new municipal portal endpoints inherit checked IDs across catalog jurisdictions", {
  cases <- regional_source_cases()
  for (id in c("stpete-parks", "clearwater-zoning")) {
    case <- cases[[id]]
    config <- .portal_registry()[[case$jurisdiction]]
    info <- tbod_dataset_info(id)
    pages <- resources <- list()
    pages[[paste0(config$root, "/search/1")]] <- list(
      total = 1L, start = 1L, nextStart = -1L,
      results = list(discovery_test_item(info$item_id, case$metadata_url,
                                          title = "Portal title", org = config$org_id)))
    resources[[case$metadata_url]] <- case$metadata
    transport <- discovery_test_transport(pages, resources)
    local_mocked_bindings(arcgis_http = transport$http)
    found <- tbod_list_datasets(source = "live", portals = case$jurisdiction)
    expect_identical(found$id, id)
    expect_identical(found$jurisdiction, case$jurisdiction)
    expect_identical(found$validation_status, "checked")
    expect_identical(tbod_dataset_info(found)$publisher, case$publisher)
    expect_identical(found$portal, config$root)
    expect_true(attr(found, "discovery_complete"))
  }
})

test_that("global item lookup resolves the new supported municipal organizations", {
  for (key in c("stpete", "clearwater")) {
    config <- .portal_registry()[[key]]
    item_id <- strrep(if (key == "stpete") "e" else "f", 32)
    endpoint <- paste0("https://example.org/arcgis/rest/services/", key, "/FeatureServer/0")
    resources <- list()
    resources[[paste0("https://www.arcgis.com/sharing/rest/content/items/", item_id)]] <-
      discovery_test_item(item_id, endpoint, org = config$org_id)
    resources[[endpoint]] <- list(id = 0L, name = "Synthetic facility",
      type = "Feature Layer", geometryType = "esriGeometryPoint")
    transport <- discovery_test_transport(resources = resources)
    local_mocked_bindings(arcgis_http = transport$http)
    found <- .discover_arcgis_item(item_id, 0L)
    expect_identical(found$jurisdiction, key)
    expect_identical(found$publisher, config$publisher)
    expect_identical(found$portal, config$root)
    expect_identical(found$validation_status, "discovered")
    expect_identical(tbod_dataset_info(found$id, jurisdiction = "all")$jurisdiction, key)
  }
})

test_that("elapsed discovery budgets remain explicit errors instead of stale-item fallbacks", {
  local_mocked_bindings(.discovery_page = function(...) {
    .abort("Operation deadline expired.", subclass = "tampa_timeout_error")
  })
  expect_error(.discover_arcgis(portals = "all"), "deadline",
               class = "tampa_timeout_error")
  expect_error(tbod_list_datasets(source = "all"), "deadline",
               class = "tampa_timeout_error")
})

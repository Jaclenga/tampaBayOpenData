test_that("prefixed catalog functions retain the bundled catalog behavior", {
  expect_identical(tbod_list_datasets(source = "checked"),
                   list_datasets(source = "checked"))
  expect_identical(tbod_search_datasets("permit", source = "checked"),
                   search_datasets("permit", source = "checked"))
  expect_identical(tbod_list_portals(), list_portals())
  expect_identical(tbod_dataset_info("construction-permits"),
                   dataset_info("construction-permits"))
})

test_that("prefixed provenance reads existing retrieval attributes", {
  data <- tibble::tibble(id = 1L)
  attr(data, "source") <- list(dataset_id = "example", source_url = "https://example.org")
  expect_identical(tbod_provenance(data), dataset_provenance(data))
})

test_that("prefixed discovery passes through a custom portal and operation budget", {
  seen <- NULL
  expected <- tibble::tibble(id = "arcgis:abcdef0123456789abcdef0123456789:0")
  local_mocked_bindings(
    .discover_custom_portal = function(portal, query, max_items, timeout,
                                       org_id, publisher, jurisdiction) {
      seen <<- list(portal = portal, query = query, max_items = max_items,
                   timeout = timeout, org_id = org_id,
                   publisher = publisher, jurisdiction = jurisdiction)
      expected
    }, .package = "tampaBayOpenData")
  actual <- tbod_discover("https://other.example.org/sharing/rest", query = "parks",
                          max_items = 7, timeout = 4, total_timeout = 15,
                          org_id = "custom-org", publisher = "Other County",
                          jurisdiction = "other")
  expect_identical(actual, expected)
  expect_identical(seen$portal, "https://other.example.org/sharing/rest")
  expect_identical(seen$query, "parks")
  expect_identical(seen$max_items, 7)
  expect_identical(as.numeric(seen$timeout), 4)
  expect_true(is.finite(attr(seen$timeout, "tampa_deadline")))
  expect_identical(seen$org_id, "custom-org")
  expect_identical(seen$publisher, "Other County")
  expect_identical(seen$jurisdiction, "other")
})

test_that("prefixed discovery accepts direct service and layer URL inputs", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"),
                        .package = "tampaBayOpenData")
  root <- "https://services.example.org/arcgis/rest/services/Parks/FeatureServer"
  service <- tbod_discover(root, max_items = 0)
  layer <- tbod_discover(paste0(root, "/2"), max_items = 0)
  expect_s3_class(service, "tbl_df")
  expect_identical(nrow(service), 0L)
  expect_identical(attr(service, "discovery_scanned_items"), c(service = 0L))
  expect_identical(layer, service)
})

test_that("prefixed retrieval sends direct URLs through the ArcGIS layer path", {
  url <- "https://other.example.org/arcgis/rest/services/Parks/FeatureServer/2"
  seen <- NULL
  expected <- tibble::tibble(record = 1L)
  local_mocked_bindings(
    get_arcgis_layer = function(url, ...) {
      seen <<- list(url = url, options = list(...))
      expected
    },
    get_dataset = function(...) stop("should not use catalog retrieval"),
    .package = "tampaBayOpenData")
  actual <- tbod_get_dataset(url, fields = "NAME", limit = 5)
  expect_identical(actual, expected)
  expect_identical(seen$url, url)
  expect_identical(seen$options$fields, "NAME")
  expect_identical(seen$options$limit, 5)
  expect_error(tbod_get_dataset(url, portal = "https://other.example.org/sharing/rest"),
               "applies only to a stable", class = "tampa_input_error")
  expect_error(tbod_get_dataset(url, jurisdiction = "other"),
               "does not apply to a direct ArcGIS URL", class = "tampa_input_error")
})

test_that("prefixed retrieval resolves stable IDs in custom portals", {
  item_id <- "abcdef0123456789abcdef0123456789"
  id <- paste0("arcgis:", item_id, ":2")
  portal <- "https://other.example.org/sharing/rest"
  descriptor <- tibble::tibble(id = id, jurisdiction = "other")
  seen <- list()
  local_mocked_bindings(
    .discover_arcgis_item = function(item_id, layer_id, portal, timeout) {
      seen$lookup <<- list(item_id = item_id, layer_id = layer_id,
                          portal = portal, timeout = timeout)
      descriptor
    },
    get_dataset = function(id, jurisdiction, ...) {
      seen$retrieval <<- list(id = id, jurisdiction = jurisdiction,
                             options = list(...))
      "retrieved"
    }, .package = "tampaBayOpenData")
  expect_identical(tbod_get_dataset(id, portal = portal, limit = 3), "retrieved")
  expect_identical(seen$lookup$item_id, item_id)
  expect_identical(seen$lookup$layer_id, 2L)
  expect_identical(seen$lookup$portal, portal)
  expect_true(is.finite(attr(seen$lookup$timeout, "tampa_deadline")))
  expect_identical(seen$retrieval$id, descriptor)
  expect_null(seen$retrieval$jurisdiction)
  expect_identical(seen$retrieval$options$limit, 3)
})

test_that("prefixed information and download accept direct layer URLs", {
  url <- "https://other.example.org/arcgis/rest/services/Parks/FeatureServer/2"
  info <- tbod_dataset_info(url)
  expect_identical(info$source_url, url)
  expect_identical(info$validation_status, "not_checked")
  seen <- NULL
  local_mocked_bindings(
    download_arcgis_layer = function(url, path, ...) {
      seen <<- list(url = url, path = path, options = list(...))
      list(complete = TRUE)
    },
    download_dataset = function(...) stop("should not use catalog download"),
    .package = "tampaBayOpenData")
  expect_identical(tbod_download_dataset(url, "download-here")$complete, TRUE)
  expect_identical(seen$url, url)
  expect_identical(seen$path, "download-here")
  expect_error(tbod_download_dataset(url, "download-here", jurisdiction = "other"),
               "does not apply to a direct ArcGIS URL", class = "tampa_input_error")
  expect_error(tbod_dataset_info(url, jurisdiction = "other"),
               "does not apply to a direct ArcGIS URL", class = "tampa_input_error")
})

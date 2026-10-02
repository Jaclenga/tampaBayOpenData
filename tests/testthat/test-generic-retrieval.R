generic_layer_url <- "https://data.example.invalid/arcgis/rest/services/Public/Test/FeatureServer/0"
generic_item_id <- paste(rep("a", 32L), collapse = "")

generic_descriptor <- function() {
  tibble::tibble(
    id = paste0("arcgis:", generic_item_id, ":0"),
    title = "Synthetic example layer",
    description = "Offline fixture",
    publisher = "Example public agency",
    source_url = generic_layer_url,
    service_url = sub("/0$", "", generic_layer_url),
    layer_id = 0L,
    item_id = generic_item_id,
    portal = "https://example.invalid/sharing/rest",
    validation_status = "discovered",
    original_metadata = list(list(item_title = "Synthetic example layer"))
  )
}

test_that("a discovered row uses the checked query pipeline and preserves provenance", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  descriptor <- generic_descriptor()
  result <- get_dataset(descriptor, where = "PROJECTSTATUS = 'Issued'",
                        fields = c("RECORD_ID", "COST"), page_size = 1L)
  expect_s3_class(result, "tbl_df")
  expect_identical(result$RECORD_ID, paste0("synthetic-", 1:5))
  expect_setequal(names(result), c("RECORD_ID", "COST"))
  expect_length(fixture_queries(transport, "count"), 1L)
  expect_length(fixture_queries(transport, "ids"), 1L)
  expect_length(fixture_queries(transport, "features"), 5L)
  expect_true(all(vapply(transport$state$requests, function(x) {
    startsWith(x$url, generic_layer_url)
  }, logical(1))))
  source <- dataset_provenance(result)
  expect_identical(source$dataset_id, descriptor$id[[1L]])
  expect_identical(source$item_id, generic_item_id)
  expect_identical(source$portal, descriptor$portal[[1L]])
  expect_identical(source$validation_status, "discovered")
  expect_identical(source$original_metadata$item_title, "Synthetic example layer")
  expect_null(source$endpoint_verified)
  expect_true(source$complete)
  expect_identical(source$returned_rows, 5L)
})

test_that("a stable ArcGIS item identifier resolves one live descriptor", {
  descriptor <- generic_descriptor()
  calls <- list()
  local_mocked_bindings(
    .discover_arcgis_item = function(item_id, layer_id, timeout) {
      calls[[length(calls) + 1L]] <<- list(item_id, layer_id, timeout)
      descriptor
    },
    arcgis_http = fixture_transport()$http
  )
  result <- get_dataset(descriptor$id[[1L]], limit = 2, timeout = 7)
  expect_identical(result$OBJECTID, 1:2)
  expect_identical(calls[[1L]], list(generic_item_id, 0L, 7))
  expect_identical(dataset_provenance(result)$validation_status, "discovered")
  expect_false(dataset_provenance(result)$complete)
})

test_that("regional discovery rows retain their jurisdiction", {
  row <- generic_descriptor()
  row$jurisdiction <- "tampa-bay"
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  result <- get_dataset(row, limit = 1)
  expect_identical(dataset_provenance(result)$jurisdiction, "tampa-bay")
  expect_identical(attr(result, "jurisdiction"), "tampa-bay")
  expect_error(get_dataset(row, jurisdiction = "tampa", limit = 1),
               "jurisdiction differs", class = "tampa_input_error")
})

test_that("a stale or unsupported ArcGIS item fails with a searchable explanation", {
  local_mocked_bindings(.discover_arcgis_item = function(...) generic_descriptor()[0, ])
  expect_error(get_dataset(paste0("arcgis:", generic_item_id, ":0")),
               "unavailable or is not a supported query layer",
               class = "tampa_input_error")
})

test_that("direct layer URLs support full, subset, empty, and table retrieval", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  all <- get_arcgis_layer(generic_layer_url, page_size = 2)
  expect_identical(all$OBJECTID, 1:5)
  source <- dataset_provenance(all)
  expect_identical(source$validation_status, "not_checked")
  expect_identical(source$jurisdiction, "unspecified")
  expect_null(source$item_id)
  expect_null(source$portal)
  expect_identical(source$source_url, generic_layer_url)
  expect_true(source$complete)
  expect_identical(source$pagination, "object-id batches")

  subset <- get_arcgis_layer(generic_layer_url, limit = 2)
  expect_identical(subset$OBJECTID, 1:2)
  expect_false(dataset_provenance(subset)$complete)
  expect_equal(dataset_provenance(subset)$matched_rows, 5)

  zero <- get_arcgis_layer(generic_layer_url, limit = 0)
  expect_s3_class(zero, "tbl_df")
  expect_identical(nrow(zero), 0L)
  expect_false(dataset_provenance(zero)$complete)

  table_meta <- fixture_metadata()
  table_meta$type <- "Table"
  table_meta$geometryType <- NULL
  table_meta$extent <- NULL
  table_meta$sourceSpatialReference <- NULL
  table_transport <- fixture_transport(metadata = table_meta)
  local_mocked_bindings(arcgis_http = table_transport$http)
  table_url <- sub("/FeatureServer/0$", "/MapServer/2", generic_layer_url)
  table <- get_arcgis_layer(table_url, fields = "RECORD_ID", limit = 1)
  expect_s3_class(table, "tbl_df")
  expect_identical(names(table), "RECORD_ID")
  expect_identical(dataset_provenance(table)$layer_id, 2L)
  expect_true(all(vapply(fixture_queries(table_transport, "features"), function(x) {
    identical(x$params$returnGeometry, "false")
  }, logical(1))))
  if (arcgis_has_sf()) {
    expect_error(get_arcgis_layer(table_url, spatial = TRUE, limit = 1),
                 "no supported spatial geometry", class = "tampa_spatial_error")
  }
})

test_that("direct ArcGIS layers preserve ordered and spatial query options", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  ordered <- get_arcgis_layer(generic_layer_url, fields = "RECORD_ID",
                              order_by = "OBJECTID DESC", page_size = 1,
                              limit = 2)
  expect_identical(ordered$RECORD_ID, c("synthetic-5", "synthetic-4"))
  expect_identical(dataset_provenance(ordered)$pagination, "ordered offsets")
  expect_identical(length(fixture_queries(transport, "features")), 2L)

  skip_if_not_installed("sf")
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  spatial <- get_arcgis_layer(generic_layer_url, spatial = TRUE,
                              out_sr = 4326, limit = 2)
  expect_s3_class(spatial, "sf")
  expect_identical(sf::st_crs(spatial)$epsg, 4326L)
  expect_identical(dataset_provenance(spatial)$query$out_sr, 4326)
  expect_identical(dataset_provenance(spatial)$validation_status, "not_checked")
})

test_that("checked IDs and authenticated checked rows retain the curated path", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  by_id <- get_dataset("construction-permits", limit = 1)
  checked <- dataset_info("construction-permits")
  checked$validation_status <- "checked"
  by_row <- get_dataset(checked, limit = 1)
  expect_identical(by_id$OBJECTID, by_row$OBJECTID)
  expect_identical(dataset_provenance(by_id)$validation_status, "checked")
  expect_identical(dataset_provenance(by_row)$validation_status, "checked")
  expect_identical(dataset_provenance(by_id)$source_url, checked$source_url)
  expect_false(is.null(dataset_provenance(by_row)$original_metadata))
})

test_that("untrusted rows cannot claim checked status or mismatch item identity", {
  row <- generic_descriptor()
  row$validation_status <- "checked"
  row$id <- "construction-permits"
  expect_error(get_dataset(row), "Only a matching bundled registry entry",
               class = "tampa_input_error")
  row <- generic_descriptor()
  row$id <- paste0("arcgis:", generic_item_id, ":1")
  expect_error(get_dataset(row), "does not match its ArcGIS item and layer",
               class = "tampa_input_error")
  row <- generic_descriptor()
  row$source_url <- "https://other.example.invalid/FeatureServer/0"
  expect_error(get_dataset(row), "source URL must equal", class = "tampa_input_error")
  row <- generic_descriptor()
  row$portal <- NA_character_
  expect_error(get_dataset(row), "needs an ArcGIS item ID and portal",
               class = "tampa_input_error")
  expect_error(get_dataset(generic_descriptor()[0, ]), "exactly one row",
               class = "tampa_input_error")
  expect_error(get_dataset(generic_descriptor()[c(1, 1), ]), "exactly one row",
               class = "tampa_input_error")
})

test_that("direct URL validation blocks local endpoints and ambiguous URL forms", {
  invalid <- c(
    "http://example.invalid/FeatureServer/0",
    "https://example.invalid/FeatureServer",
    "https://example.invalid/FeatureServer/0/query",
    "https://user:pass@example.invalid/FeatureServer/0",
    "https://127.0.0.1/FeatureServer/0",
    "https://localhost/FeatureServer/0",
    "https://metadata.google.internal/FeatureServer/0",
    "https://example.invalid/FeatureServer/0?token=secret",
    "https://example.invalid/FeatureServer/0#fragment",
    "https://example.invalid/service/../FeatureServer/0",
    "https://example.invalid/service%2fother/FeatureServer/0"
  )
  for (url in invalid) {
    expect_error(get_arcgis_layer(url, limit = 0),
                 class = "tampa_input_error")
  }
})

test_that("malformed and nonquery layers fail through the shared metadata gate", {
  malformed <- fixture_metadata()
  malformed$fields <- list()
  transport <- fixture_transport(metadata = malformed)
  local_mocked_bindings(arcgis_http = transport$http)
  expect_error(get_arcgis_layer(generic_layer_url),
               "valid field schema", class = "tampa_response_error")

  unsupported <- fixture_metadata()
  unsupported$capabilities <- "Map"
  transport <- fixture_transport(metadata = unsupported)
  local_mocked_bindings(arcgis_http = transport$http)
  expect_error(get_arcgis_layer(generic_layer_url),
               "query support", class = "tampa_data_error")
})

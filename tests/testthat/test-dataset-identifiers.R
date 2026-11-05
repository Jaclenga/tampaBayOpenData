test_that("every checked canonical ID preserves its legacy target", {
  entries <- .read_registry()
  canonical <- vapply(entries, .canonical_dataset_id, character(1))
  expect_false(anyDuplicated(canonical) > 0L)
  for (entry in entries) {
    legacy <- tbod_dataset_info(entry$id)
    qualified <- tbod_dataset_info(entry$canonical_id)
    expect_identical(qualified, legacy)
    expect_identical(qualified$canonical_id, entry$canonical_id)
    expect_true(entry$id %in% qualified$aliases)
  }
  catalog <- tbod_list_datasets(source = "checked")
  expect_identical(catalog$canonical_id, canonical)
  expect_true(all(c("publisher", "aliases") %in% names(catalog)))
  expect_identical(tbod_search_datasets("tampa-bike-lanes", source = "checked")$id,
                   "bike-lanes")
  expect_identical(tbod_dataset_info("hillsborough-hart-routes")$publisher,
                   "Hillsborough County")
})

test_that("subjects shared by publishers honor legacy mappings", {
  first <- .read_registry()[[1L]]
  first$id <- first$canonical_id <- "tampa-bike-lanes"
  first$subject_id <- "bike-lanes"
  first$aliases <- list()
  second <- first
  second$id <- second$canonical_id <- "st-pete-bike-lanes"
  second$publisher <- "City of St. Petersburg"
  second$jurisdiction <- "stpete"
  second$service_url <- "https://example.org/arcgis/rest/services/Bikes/FeatureServer"
  expect_invisible(.validate_registry(list(first, second)))
  local_mocked_bindings(.read_registry = function() list(first, second),
                        .package = "tampaBayOpenData")
  expect_identical(.lookup_dataset(first$canonical_id)$publisher, first$publisher)
  expect_identical(.lookup_dataset(second$canonical_id)$publisher, second$publisher)
  expect_error(.lookup_dataset("bike-lanes"),
               "Ambiguous.*tampa-bike-lanes, st-pete-bike-lanes",
               class = "tampa_input_error")
  expect_error(.lookup_dataset("missing-subject"), "Unknown dataset",
               class = "tampa_input_error")
  first$aliases <- list("bike-lanes")
  expect_identical(.lookup_dataset("bike-lanes")$publisher, first$publisher)
  expect_error(.lookup_dataset("bike-lanes", "stpete"), "Unknown dataset")
  second$aliases <- list("bike-lanes")
  expect_error(.validate_registry(list(first, second)), "alias collision")
  second$aliases <- list(first$canonical_id)
  expect_error(.validate_registry(list(first, second)), "alias collision")
  second$canonical_id <- first$canonical_id
  expect_error(.validate_registry(list(first, second)), "globally unique")
})

test_that("retrieval accepts qualified IDs through the shared resolver", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http,
                        .package = "tampaBayOpenData")
  qualified <- tbod_get_dataset("tampa-construction-permits", limit = 2)
  legacy <- tbod_get_dataset("construction-permits", limit = 2)
  expect_identical(qualified$RECORD_ID, legacy$RECORD_ID)
  expect_identical(tbod_provenance(qualified)$source_url,
                   tbod_provenance(legacy)$source_url)
  expect_identical(tbod_provenance(qualified)$dataset_id, "construction-permits")
})

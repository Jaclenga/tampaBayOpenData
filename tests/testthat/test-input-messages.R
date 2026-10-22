test_that("unknown checked IDs point to offline catalog search without guessing an ID", {
  failure <- tryCatch(tbod_dataset_info("park"), error = identity)
  expect_s3_class(failure, "tampa_input_error")
  message <- conditionMessage(failure)
  expect_match(message, "Unknown dataset `park`.*checked catalog")
  expect_true(grepl('tbod_list_datasets(source = "checked")', message,
                    fixed = TRUE))
  expect_match(message, "tbod_search_datasets\\(")
  expect_match(message, "Possible matches:.*`parks`")

  wrong_scope <- tryCatch(
    tbod_dataset_info("construction-permits", jurisdiction = "pinellas"),
    error = identity
  )
  expect_s3_class(wrong_scope, "tampa_input_error")
  expect_match(conditionMessage(wrong_scope), "jurisdiction `pinellas`")
  expect_match(conditionMessage(wrong_scope), 'jurisdiction = "tampa"')

  sensitive <- tryCatch(tbod_dataset_info("park?token=do-not-show"), error = identity)
  expect_s3_class(sensitive, "tampa_input_error")
  expect_match(conditionMessage(sensitive), "Unknown dataset ID")
  expect_false(grepl("do-not-show", conditionMessage(sensitive), fixed = TRUE))
})

test_that("invalid numeric and conflicting retrieval options explain the repair", {
  limit_error <- tryCatch(
    tbod_search_datasets("permit", source = "checked", limit = -1),
    error = identity
  )
  expect_s3_class(limit_error, "tampa_input_error")
  expect_match(conditionMessage(limit_error), "limit.*whole number.*received -1")
  expect_error(tbod_search_datasets("permit", source = "checked", limit = NA_real_),
               "limit.*whole number", class = "tampa_input_error")

  spatial_error <- tryCatch(
    tbod_get_dataset("parks", out_sr = 4326), error = identity
  )
  expect_s3_class(spatial_error, "tampa_data_error")
  expect_match(conditionMessage(spatial_error), "spatial = TRUE or omit out_sr")

  url_error <- tryCatch(
    tbod_get_arcgis_layer("https://example.org/FeatureServer/0?token=do-not-show"),
    error = identity
  )
  expect_s3_class(url_error, "tampa_input_error")
  expect_match(conditionMessage(url_error), "public HTTPS URL")
  expect_match(conditionMessage(url_error), "tbod_discover\\(url\\)")
  expect_false(grepl("do-not-show", conditionMessage(url_error), fixed = TRUE))
})

test_that("error context redacts URL credentials, queries, and fragments", {
  private_url <- paste0("https://user:password@example.org/FeatureServer/0",
                        "?token=do-not-show#fragment")
  dataset <- list(id = private_url, publisher = "Example publisher",
                  source_url = private_url)
  failure <- tryCatch(.abort("Could not read the layer.", dataset, private_url,
                             subclass = "tampa_response_error"), error = identity)
  expect_s3_class(failure, "tampa_response_error")
  expect_identical(failure$url, "https://example.org/FeatureServer/0")
  expect_identical(failure$dataset_id, "https://example.org/FeatureServer/0")
  expect_match(conditionMessage(failure), "Endpoint: https://example.org/FeatureServer/0")
  expect_false(grepl("password|do-not-show|fragment", conditionMessage(failure)))

  dataset$publisher <- "Publisher?token=publisher-secret"
  publisher_failure <- tryCatch(.abort("Could not read the layer.", dataset),
                                error = identity)
  expect_match(conditionMessage(publisher_failure), "Publisher: \\[redacted\\]")
  expect_false(grepl("publisher-secret", conditionMessage(publisher_failure),
                     fixed = TRUE))

  no_dataset <- tryCatch(.abort("A plain failure."), error = identity)
  expect_null(no_dataset$dataset_id)
  expect_null(no_dataset$url)

  file_failure <- tryCatch(.abort("Could not save a chunk.",
                                  url = "C:/downloads/chunk#1.rds"), error = identity)
  expect_identical(file_failure$url, "C:/downloads/chunk#1.rds")
})

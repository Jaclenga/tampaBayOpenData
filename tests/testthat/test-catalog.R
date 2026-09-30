test_that("the bundled catalog is offline, verified, and City-only", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"),
                        .package = "tampaBayOpenData")
  entries <- .read_registry()
  expect_invisible(.validate_registry(entries))
  catalog <- list_datasets()
  expect_s3_class(catalog, "tbl_df")
  expect_equal(nrow(catalog), 8L)
  expect_setequal(catalog$id, c("construction-permits", "development-cases",
    "capital-projects", "city-boundary", "neighborhoods", "council-districts",
    "riverwalk", "parks"))
  expect_identical(unique(catalog$jurisdiction), "tampa")
  expect_identical(unique(catalog$publisher), "City of Tampa")
  expect_s3_class(catalog$verified, "Date")
  expect_true(all(grepl("^https://", catalog$source_url)))
  expect_true(all(grepl("/(FeatureServer|MapServer)$", catalog$service_url)))
  expect_true(all(vapply(catalog$date_fields, is.character, logical(1))))
  expect_true(all(vapply(catalog$tags, is.character, logical(1))))
  expect_true(all(nzchar(catalog$terms)))
  expect_match(dataset_info("city-boundary")$scope_note, "shoreline")
  expect_match(dataset_info("construction-permits")$description, "active")
})

test_that("invalid registry records fail before discovery", {
  entry <- .read_registry()[[1L]]
  invalid <- list(
    list(), list(entry[c("id", "title")]),
    list(within(entry, id <- "construction_permits")),
    list(within(entry, service_url <- paste0(service_url, "/0?f=json"))),
    list(within(entry, service_url <- "http://example.invalid/FeatureServer")),
    list(within(entry, source_url <- "ftp://example.invalid/data")),
    list(within(entry, layer_id <- 0.5)),
    list(within(entry, geometry_type <- "esriGeometryMultipatch")),
    list(within(entry, verified <- "2026-99-99")),
    list(within(entry, terms <- "")),
    list(within(entry, publisher <- NA_character_)),
    list(within(entry, date_fields <- list(12))),
    list(within(entry, tags <- list(NA_character_))),
    list(entry, entry)
  )
  for (records in invalid) {
    expect_error(.validate_registry(records), class = "tampa_data_error")
  }
  expect_error(.validate_registry(list(42)), "missing required metadata")
})

test_that("registry string arrays reject coercible and non-array values", {
  entry <- .read_registry()[[1L]]
  invalid_values <- list(
    list("DATE", 12), list(12, "DATE"), list("DATE", TRUE),
    list(NA_character_), list(""), list(list("DATE")),
    "DATE", c("DATE", "OTHER"), list(field = "DATE")
  )
  for (name in c("date_fields", "tags")) {
    for (value in invalid_values) {
      candidate <- entry
      candidate[[name]] <- value
      expect_error(.validate_registry(list(candidate)),
                   paste0("Registry `", name, "` must be an array"),
                   class = "tampa_data_error")
    }
  }
  entry$date_fields <- list()
  entry$tags <- list()
  expect_invisible(.validate_registry(list(entry)))
})

test_that("registry layer IDs stay within R's integer range", {
  entry <- .read_registry()[[1L]]
  entry$layer_id <- as.numeric(.Machine$integer.max)
  expect_invisible(.validate_registry(list(entry)))
  expect_identical(.catalog_table(list(entry))$layer_id, .Machine$integer.max)

  entry$layer_id <- as.numeric(.Machine$integer.max) + 1
  expect_error(.validate_registry(list(entry)), "must fit in an R integer",
               class = "tampa_data_error")
})

test_that("search matches literal words across metadata fields", {
  expect_identical(search_datasets(" ACTIVE permit ")$id, "construction-permits")
  expect_identical(search_datasets("CAPITAL projects")$id, "capital-projects")
  expect_identical(search_datasets("riverwalk infrastructure")$id, "riverwalk")
  expect_equal(nrow(search_datasets("per.*")), 0L)
  expect_equal(nrow(search_datasets("[")), 0L)
  expect_equal(nrow(search_datasets("a phrase with no matching dataset")), 0L)
  expect_equal(search_datasets(" \t\n "), list_datasets())
  expect_equal(search_datasets(""), list_datasets())
  expect_error(search_datasets(c("permit", "park")), "single nonmissing string")
  expect_error(search_datasets(NA_character_), "single nonmissing string")
})

test_that("lookup explains unsupported IDs and jurisdictions", {
  expect_equal(dataset_info("construction-permits")$layer_id, 0)
  expect_error(dataset_info("made-up"), "Unknown dataset.*list_datasets")
  expect_error(dataset_info("construction-permits", jurisdiction = "pinellas"),
               "Unsupported jurisdiction.*tampa")
  expect_error(list_datasets("hillsborough"), "v0.1 supports the City of Tampa")
  expect_error(dataset_info(c("parks", "riverwalk")), "single nonmissing string")
  expect_error(list_datasets(NA_character_), "single nonmissing string")
  expect_error(dataset_info("parks", refresh = NA), "TRUE or FALSE")
  expect_error(dataset_info("parks", timeout = 0), "timeout")
})

test_that("live inspection adds the actual schema without changing provenance", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  original <- dataset_info("construction-permits")
  expect_length(transport$state$requests, 0L)
  inspected <- dataset_info("construction-permits", refresh = TRUE, timeout = 11)
  expect_s3_class(inspected$fields, "tbl_df")
  expect_identical(inspected$fields$name, .field_names(fixture_metadata()))
  expect_identical(inspected$fields$alias[2L], "Record ID")
  expect_identical(inspected$fields$type[4L], "esriFieldTypeDate")
  expect_s3_class(inspected$inspected_at, "POSIXct")
  expect_identical(inspected$source_url, original$source_url)
  expect_identical(inspected$verified, original$verified)
  expect_identical(inspected$metadata$maxRecordCount, 2L)
  expect_length(transport$state$requests, 1L)
  expect_equal(transport$state$requests[[1L]]$timeout, 11)
})

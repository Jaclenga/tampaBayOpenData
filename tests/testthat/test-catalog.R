test_that("the bundled catalog is offline, verified, and City-published", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"),
                        .package = "tampaBayOpenData")
  entries <- .read_registry()
  expect_invisible(.validate_registry(entries))
  catalog <- list_datasets(jurisdiction = "tampa", source = "checked")
  expect_s3_class(catalog, "tbl_df")
  expect_equal(nrow(catalog), 20L)
  expect_setequal(catalog$id, c("construction-permits", "development-cases",
    "capital-projects", "city-boundary", "neighborhoods", "council-districts",
    "riverwalk", "parks", "fire-stations", "bike-lanes", "recycling-pickup",
    "community-redevelopment", "high-injury-network", "historic-district-local",
    "historic-landmarks-local", "police-districts", "street-speed-reductions",
    "truck-routes", "water-service-area", "zoning-districts"))
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

test_that("registry validation distinguishes valid boundaries from malformed records", {
  entry <- .read_registry()[[1L]]
  entry$description <- ""
  entry$layer_id <- 0L
  expect_invisible(.validate_registry(list(entry)))

  invalid <- list(
    id = c("Construction-permits", "construction--permits", "construction-permits-"),
    title = c("", "  ", NA_character_),
    layer_id = list(-1L, Inf, NA_real_, "1", c(1L, 2L)),
    service_url = c(paste0(entry$service_url, "/"),
                    paste0(entry$service_url, "?f=json"),
                    "https://example.invalid/FeatureServer/0"),
    source_url = c("http://example.invalid/item", "ftp://example.invalid/item"),
    verified = c("2026-2-1", "2026-02-30", NA_character_),
    terms = c("", "  ")
  )
  for (name in names(invalid)) {
    for (value in invalid[[name]]) {
      candidate <- entry
      candidate[[name]] <- value
      expect_error(.validate_registry(list(candidate)), class = "tampa_data_error",
                   info = paste(name, paste(value, collapse = ", ")))
    }
  }
})

test_that("dataset IDs are unique within a jurisdiction", {
  entry <- .read_registry()[[1L]]
  second <- entry
  second$jurisdiction <- "neighboring-city"
  expect_invisible(.validate_registry(list(entry, second)))
  expect_identical(.jurisdiction_entries("neighboring-city", list(entry, second)),
                   list(second))
  expect_error(.validate_registry(list(entry, entry)),
               "unique within each jurisdiction", class = "tampa_data_error")
})

test_that("search matches literal words across metadata fields", {
  expect_identical(search_datasets(" ACTIVE permit ", source = "checked")$id, "construction-permits")
  expect_identical(search_datasets("CAPITAL projects", source = "checked")$id, "capital-projects")
  expect_identical(search_datasets("riverwalk infrastructure", source = "checked")$id, "riverwalk")
  expect_equal(nrow(search_datasets("per.*", source = "checked")), 0L)
  expect_equal(nrow(search_datasets("[", source = "checked")), 0L)
  expect_equal(nrow(search_datasets("a phrase with no matching dataset", source = "checked")), 0L)
  expect_equal(search_datasets(" \t\n ", source = "checked"), list_datasets(source = "checked"))
  expect_equal(search_datasets("", source = "checked"), list_datasets(source = "checked"))
  expect_error(search_datasets(c("permit", "park"), source = "checked"), "single nonmissing string")
  expect_error(search_datasets(NA_character_, source = "checked"), "single nonmissing string")
})

test_that("search combines category, tags, and title without changing catalog rows", {
  catalog <- list_datasets(source = "checked")
  cases <- list(
    c("transportation trails", "bike-lanes"),
    c("public safety facilities", "fire-stations"),
    c("solid waste collection", "recycling-pickup"),
    c("infrastructure recreation", "riverwalk"),
    c("bike-lanes", "bike-lanes")
  )
  for (case in cases) {
    actual <- search_datasets(case[[1L]], source = "checked")
    expect_identical(actual$id, case[[2L]])
    expect_identical(actual, catalog[catalog$id == case[[2L]], , drop = FALSE])
  }
  expect_identical(search_datasets("  PUBLIC   safety\tFACILITIES  ", source = "checked")$id,
                   "fire-stations")
  expect_equal(nrow(search_datasets("CC0", source = "checked")), 0L)
  empty <- search_datasets("no-such-category", source = "checked")
  expect_s3_class(empty, "tbl_df")
  expect_identical(names(empty), names(catalog))
  expect_identical(vapply(empty, typeof, character(1)),
                   vapply(catalog, typeof, character(1)))
})

test_that("offline dataset lookups retain the registry metadata for every layer", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"),
                        .package = "tampaBayOpenData")
  entries <- .read_registry()
  for (entry in entries) {
    info <- dataset_info(entry$id)
    expect_identical(info$id, entry$id)
    expect_identical(info$source_url, entry$source_url)
    expect_identical(info$service_url, entry$service_url)
    expect_identical(info$layer_id, entry$layer_id)
    expect_identical(info$verified, entry$verified)
    expect_identical(info$terms, entry$terms)
    expect_identical(info$tags, unlist(entry$tags, use.names = FALSE))
    expect_identical(info$date_fields,
                     unlist(entry$date_fields, use.names = FALSE) %||% character())
    expect_null(info$fields)
    expect_null(info$inspected_at)
  }
})

test_that("lookup explains unsupported IDs and jurisdictions", {
  expect_equal(dataset_info("construction-permits")$layer_id, 0)
  expect_error(dataset_info("made-up"), "Unknown dataset.*list_datasets")
  expect_error(dataset_info("construction-permits", jurisdiction = "pinellas"),
               "Unknown dataset.*pinellas")
  expect_identical(nrow(list_datasets("hillsborough", source = "checked")), 3L)
  expect_error(dataset_info(c("parks", "riverwalk")), "single nonmissing string")
  expect_error(list_datasets(NA_character_, source = "checked"), "nonmissing strings")
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
  expect_equal(as.numeric(transport$state$requests[[1L]]$timeout), 11)
})

test_that("refresh inspects each layer's own endpoint and field aliases", {
  snapshots <- source_schema_fixtures()
  by_url <- setNames(snapshots, vapply(snapshots, `[[`, character(1), "metadata_url"))
  requests <- list()
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    requests[[length(requests) + 1L]] <<- list(url = url, params = params,
                                               timeout = timeout)
    if (!url %in% names(by_url)) stop("unexpected metadata endpoint")
    fixture_response(by_url[[url]]$metadata)
  }, .package = "tampaBayOpenData")

  for (id in names(snapshots)) {
    offline <- dataset_info(id)
    expect_length(requests, match(id, names(snapshots)) - 1L)
    refreshed <- dataset_info(id, refresh = TRUE, timeout = 7)
    schema <- snapshots[[id]]$metadata$fields
    expect_identical(refreshed$fields$name,
                     vapply(schema, `[[`, character(1), "name"))
    expect_identical(refreshed$fields$type,
                     vapply(schema, `[[`, character(1), "type"))
    expect_identical(refreshed$fields$alias,
                     vapply(schema, function(field) field$alias %||% field$name,
                            character(1)))
    expect_identical(refreshed$metadata$objectIdField,
                     offline$object_id_field)
    expect_identical(refreshed$source_url, offline$source_url)
    expect_identical(refreshed$verified, offline$verified)
    expect_s3_class(refreshed$inspected_at, "POSIXct")
    request <- requests[[length(requests)]]
    expect_identical(request$url, snapshots[[id]]$metadata_url)
    expect_identical(request$params$f, "json")
    expect_identical(as.numeric(request$timeout), 7)
  }
  expect_length(requests, length(snapshots))
})

test_that("refresh falls back to the field name when an alias is absent", {
  metadata <- fixture_metadata()
  metadata$fields[[2L]]$alias <- NULL
  transport <- fixture_transport(metadata = metadata)
  local_mocked_bindings(arcgis_http = transport$http,
                        .package = "tampaBayOpenData")
  inspected <- dataset_info("construction-permits", refresh = TRUE)
  expect_identical(inspected$fields$alias[[2L]], "RECORD_ID")
  expect_length(transport$state$requests, 1L)
})

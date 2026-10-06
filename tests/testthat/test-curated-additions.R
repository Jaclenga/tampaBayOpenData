curated_test_field <- function(metadata, types, excluded = character()) {
  matches <- Filter(function(field) field$type %in% types &&
                      !field$name %in% excluded &&
                      !grepl("^(Shape|SHAPE)[_.]", field$name),
                    metadata$fields)
  if (length(matches)) matches[[1L]]$name else NULL
}

curated_test_oid <- function(metadata) {
  oid <- Filter(function(field) identical(field$type, "esriFieldTypeOID"),
                metadata$fields)
  stopifnot(length(oid) == 1L)
  oid[[1L]]$name
}

curated_test_features <- function(case, fields) {
  oid <- curated_test_oid(case$metadata)
  date <- curated_test_field(case$metadata, "esriFieldTypeDate", fields[1:2])
  numeric <- curated_test_field(case$metadata,
                                c("esriFieldTypeInteger", "esriFieldTypeSmallInteger",
                                  "esriFieldTypeDouble", "esriFieldTypeSingle"),
                                fields[1:2])
  lapply(c(12L, 3L, 8L), function(id) {
    attributes <- list(id, paste0("synthetic-", id))
    names(attributes) <- c(oid, case$label_field)
    if (!is.null(date)) attributes[[date]] <- 1704153600000 + id * 86400000
    if (!is.null(numeric)) {
      type <- case$metadata$fields[[match(numeric,
        vapply(case$metadata$fields, `[[`, character(1), "name"))]]$type
      attributes[[numeric]] <- if (type %in% c("esriFieldTypeDouble", "esriFieldTypeSingle"))
        as.double(id) + 0.5 else id
    }
    list(attributes = attributes, geometry = NULL)
  })
}

test_that("all new checked layers have matching offline and current schema fixtures", {
  additions <- curated_addition_cases()
  expect_length(additions, 17L)
  expect_setequal(names(additions),
                  setdiff(vapply(.read_registry(), `[[`, character(1), "id"),
                          names(c(jsonlite::fromJSON(
                            test_path("fixtures", "tampa-layer-schemas.json"),
                            simplifyVector = FALSE), regional_source_cases()))))
  for (id in names(additions)) {
    case <- additions[[id]]
    transport <- fixture_transport(metadata = case$metadata, features = list())
    local_mocked_bindings(arcgis_http = transport$http)

    expected <- tbod_schema(id)
    expect_identical(expected$endpoint, case$metadata_url)
    expect_length(transport$state$requests, 0L)
    current <- tbod_schema(id, refresh = TRUE)
    expect_identical(current$fields$name, expected$fields$name)
    expect_identical(current$fields$type, expected$fields$type)
    report <- tbod_check_schema(id)
    expect_identical(report$status, "unchanged")
    expect_equal(nrow(report$issues), 0L)
    expect_true(all(vapply(transport$state$requests, function(request) {
      identical(request$url, case$metadata_url)
    }, logical(1))))
  }
})

test_that("all new checked layers route paged data with typed fields and provenance", {
  for (id in names(curated_addition_cases())) {
    case <- curated_addition_cases()[[id]]
    oid <- curated_test_oid(case$metadata)
    fields <- c(oid, case$label_field)
    date <- curated_test_field(case$metadata, "esriFieldTypeDate", fields)
    numeric <- curated_test_field(case$metadata,
                                  c("esriFieldTypeInteger", "esriFieldTypeSmallInteger",
                                    "esriFieldTypeDouble", "esriFieldTypeSingle"), fields)
    fields <- c(fields, date, numeric)
    transport <- fixture_transport(metadata = case$metadata,
                                   features = curated_test_features(case, fields))
    local_mocked_bindings(arcgis_http = transport$http)

    result <- tbod_get_dataset(id, fields = fields, page_size = 1)
    expect_s3_class(result, "tbl_df")
    expect_identical(names(result), fields)
    expect_identical(result[[oid]], c(3L, 8L, 12L))
    expect_identical(result[[case$label_field]],
                     paste0("synthetic-", c(3L, 8L, 12L)))
    if (!is.null(date)) expect_s3_class(result[[date]], "POSIXct")
    if (!is.null(numeric)) {
      numeric_type <- case$metadata$fields[[match(numeric,
        vapply(case$metadata$fields, `[[`, character(1), "name"))]]$type
      expect_type(result[[numeric]], if (numeric_type %in% c(
        "esriFieldTypeDouble", "esriFieldTypeSingle")) "double" else "integer")
    }
    source <- tbod_provenance(result)
    expect_identical(source$dataset_id, id)
    expect_identical(source$jurisdiction, case$jurisdiction)
    expect_identical(source$publisher, case$publisher)
    expect_identical(source$validation_status, "checked")
    expect_identical(source$endpoint, paste0(case$metadata_url, "/query"))
    expect_true(source$complete)
    expect_identical(source$returned_rows, 3L)
    expect_length(fixture_queries(transport, "features"), 3L)
    expect_true(all(vapply(transport$state$requests, function(request) {
      request$url %in% c(case$metadata_url, paste0(case$metadata_url, "/query"))
    }, logical(1))))
  }
})

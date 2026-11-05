test_that("bundled checked records meet editorial invariants without HTTP", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"))
  entries <- .read_registry()
  portals <- .portal_registry()
  expect_invisible(.validate_checked_catalog(entries, portals))
  expect_setequal(unique(vapply(entries, `[[`, character(1), "jurisdiction")),
                  vapply(portals, `[[`, character(1), "jurisdiction"))
  expect_identical(anyDuplicated(vapply(entries, function(x) {
    paste(x$jurisdiction, x$id, sep = "/")
  }, character(1))), 0L)
  expect_identical(anyDuplicated(vapply(entries, function(x) {
    paste(tolower(x$service_url), x$layer_id, sep = "/")
  }, character(1))), 0L)
  for (entry in entries) {
    expect_true(entry$category %in% .checked_categories(), info = entry$id)
    expect_true(nzchar(trimws(entry$title)), info = entry$id)
    expect_true(nzchar(trimws(entry$scope_note)), info = entry$id)
    expect_true(nzchar(trimws(entry$terms)), info = entry$id)
    expect_true(nzchar(trimws(entry$terms_url)), info = entry$id)
    expect_true(length(entry$publisher_evidence) > 0L, info = entry$id)
    expect_identical(entry$expected_schema$geometry_type, entry$geometry_type,
                     info = entry$id)
    expect_identical(entry$expected_schema$object_id_field,
                     entry$object_id_field, info = entry$id)
    expect_identical(entry$expected_schema$endpoint,
                     paste0(entry$service_url, "/", entry$layer_id),
                     info = entry$id)
  }
})

test_that("checked quality checks reject undocumented and mismatched records", {
  entry <- .read_registry()[[1L]]
  invalid <- list(
    list(field = "jurisdiction", value = "neighboring-city",
         pattern = "configured portal"),
    list(field = "publisher", value = "Unrelated publisher",
         pattern = "configured portal"),
    list(field = "category", value = "Miscellaneous",
         pattern = "unrecognized category"),
    list(field = "service_url",
         value = "https://user:secret@publisher.example.org/arcgis/rest/services/X/FeatureServer",
         pattern = "valid public ArcGIS service URL"),
    list(field = "source_url", value = "https://",
         pattern = "valid HTTPS source URL"),
    list(field = "scope_note", value = " ", pattern = "checked.scope_note"),
    list(field = "terms_url", value = "http://example.org/terms",
         pattern = "HTTPS terms URL"),
    list(field = "publisher_evidence", value = list(),
         pattern = "publisher evidence"),
    list(field = "publisher_evidence", value = list("http://example.org/gis"),
         pattern = "publisher evidence"),
    list(field = "object_id_field", value = "",
         pattern = "checked.object_id_field"),
    list(field = "spatial_reference", value = NULL,
         pattern = "record its CRS"),
    list(field = "max_record_count", value = 0,
         pattern = "checked.max_record_count")
  )
  for (case in invalid) {
    candidate <- entry
    candidate[case$field] <- list(case$value)
    expect_error(.validate_checked_catalog(list(candidate)), case$pattern,
                 class = "tampa_data_error", info = case$field)
  }
  duplicate <- entry
  duplicate$id <- paste0(entry$id, "-copy")
  expect_error(.validate_checked_catalog(list(entry, duplicate)),
               "duplicate a service and layer", class = "tampa_data_error")
  housing <- entry
  housing$category <- "Housing"
  expect_invisible(.validate_checked_catalog(list(housing)))
  environment <- entry
  environment$category <- "Environment"
  expect_invisible(.validate_checked_catalog(list(environment)))
})

test_that("generic registry validation still accepts other publisher fixtures", {
  entry <- .read_registry()[[1L]]
  neighboring <- entry
  neighboring$jurisdiction <- "neighboring-city"
  neighboring$publisher <- "Neighboring city"
  neighboring$service_url <- "https://neighbor.example.org/arcgis/rest/services/Permits/FeatureServer"
  expect_invisible(.validate_registry(list(entry, neighboring)))
  expect_error(.validate_checked_catalog(list(entry, neighboring)),
               "configured portal", class = "tampa_data_error")
})

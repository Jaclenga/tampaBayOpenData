# These tests are intentionally disabled during ordinary local and CRAN checks.
# Run explicitly with TAMPA_OPEN_DATA_LIVE=true from an allowed network.
test_that("live permits retrieve the complete multi-page source view", {
  skip_if_not(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
              "Set TAMPA_OPEN_DATA_LIVE=true to opt into City API calls")
  result <- get_dataset("construction-permits",
    fields = c("OBJECTID", "RECORD_ID", "PROJECTSTATUS", "LASTUPDATE"), page_size = 500)
  provenance <- dataset_provenance(result)
  expect_s3_class(result, "tbl_df")
  expect_true(provenance$complete)
  expect_equal(provenance$matched_rows, nrow(result))
  expect_equal(provenance$returned_rows, nrow(result))
  expect_equal(anyDuplicated(result$OBJECTID), 0L)
  expect_s3_class(result$LASTUPDATE, "POSIXct")
  expect_identical(provenance$publisher, "City of Tampa")
  # This source exceeded 2,000 at verification; no fixed live row count is assumed.
  expect_gt(nrow(result), 0L)
})

test_that("live spatial samples confirm projected and native CRS handling", {
  skip_if_not(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
              "Set TAMPA_OPEN_DATA_LIVE=true to opt into City API calls")
  skip_if_not_installed("sf")
  capital <- get_dataset("capital-projects", spatial = TRUE, limit = 2,
                         fields = c("OBJECTID", "projid"))
  expect_s3_class(capital, "sf")
  expect_equal(sf::st_crs(capital)$epsg, 6443)
  capital_wgs84 <- get_dataset("capital-projects", spatial = TRUE, out_sr = 4326,
                               limit = 2, fields = c("OBJECTID", "projid"))
  expect_equal(sf::st_crs(capital_wgs84)$epsg, 4326)
  expect_equal(sf::st_coordinates(sf::st_transform(capital, 4326)),
               sf::st_coordinates(capital_wgs84), tolerance = 1e-5)
  riverwalk <- get_dataset("riverwalk", spatial = TRUE, out_sr = 4326, limit = 2)
  expect_s3_class(riverwalk, "sf")
  expect_true(all(as.character(sf::st_geometry_type(riverwalk)) %in%
                    c("LINESTRING", "MULTILINESTRING")))
  boundary <- get_dataset("city-boundary", spatial = TRUE, out_sr = 4326)
  expect_s3_class(boundary, "sf")
  expect_true(all(as.character(sf::st_geometry_type(boundary)) %in%
                    c("POLYGON", "MULTIPOLYGON")))
  for (sample in list(capital, capital_wgs84, riverwalk, boundary)) {
    expect_equal(dataset_provenance(sample)$returned_rows, nrow(sample))
    expect_identical(dataset_provenance(sample)$publisher, "City of Tampa")
    expect_false(is.na(sf::st_crs(sample)))
  }
})

test_that("live checked regional sources return bounded typed rows", {
  skip_if_not(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
              "Set TAMPA_OPEN_DATA_LIVE=true to opt into municipal API calls")
  for (id in names(regional_source_cases())) {
    case <- regional_source_cases()[[id]]
    oid <- regional_oid_field(case)
    fields <- unlist(case$fields, use.names = FALSE)
    data <- tbod_get_dataset(id, fields = fields, limit = 2, page_size = 1,
                        timeout = 15, total_timeout = 45)
    expect_s3_class(data, "tbl_df")
    expect_identical(names(data), fields)
    expect_gt(nrow(data), 0L)
    expect_lte(nrow(data), 2L)
    expect_equal(anyDuplicated(data[[oid]]), 0L)
    expect_type(data[[case$label_field]], "character")
    source <- tbod_provenance(data)
    expect_identical(source$dataset_id, id)
    expect_identical(source$publisher, case$publisher)
    expect_identical(source$jurisdiction, case$jurisdiction)
    expect_identical(source$validation_status, "checked")
    expect_equal(source$returned_rows, nrow(data))
    expect_gte(source$matched_rows, nrow(data))
    expect_identical(source$complete, source$matched_rows == nrow(data))
  }
})

test_that("live checked regional point, line, and polygon sources project to WGS 84", {
  skip_if_not(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
              "Set TAMPA_OPEN_DATA_LIVE=true to opt into municipal API calls")
  skip_if_not_installed("sf")
  for (id in names(regional_source_cases())) {
    case <- regional_source_cases()[[id]]
    oid <- regional_oid_field(case)
    data <- tbod_get_dataset(id, fields = c(oid, case$label_field),
                        spatial = TRUE, out_sr = 4326, limit = 2, page_size = 1,
                        timeout = 15, total_timeout = 45)
    expect_s3_class(data, "sf")
    expect_gt(nrow(data), 0L)
    expect_lte(nrow(data), 2L)
    expect_equal(anyDuplicated(data[[oid]]), 0L)
    expect_equal(sf::st_crs(data)$epsg, 4326)
    pattern <- switch(case$metadata$geometryType,
      esriGeometryPoint = "^POINT$", esriGeometryPolyline = "^(MULTI)?LINESTRING$",
      esriGeometryPolygon = "^(MULTI)?POLYGON$")
    expect_true(all(sf::st_is_empty(data) |
      grepl(pattern, as.character(sf::st_geometry_type(data)))))
    expect_identical(tbod_provenance(data)$validation_status, "checked")
    expect_identical(tbod_provenance(data)$jurisdiction, case$jurisdiction)
  }
})

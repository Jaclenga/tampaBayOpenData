test_that("new source schemas retrieve point, line, and polygon geometry with missing rows", {
  skip_if_not_installed("sf")
  snapshots <- jsonlite::fromJSON(test_path("fixtures", "tampa-layer-schemas.json"),
                                  simplifyVector = FALSE)
  cases <- list(
    list(id = "fire-stations", field = "GIS.FacilitySitePoint.NAME",
         geometry = list(x = -9180000, y = 3220000), type = "POINT"),
    list(id = "bike-lanes", field = "ROADWAY",
         geometry = list(paths = list(list(c(0, 0), c(10, 10)))),
         type = "LINESTRING"),
    list(id = "recycling-pickup", field = "SCHEDULE",
         geometry = list(rings = list(list(c(0, 0), c(0, 10), c(10, 10),
                                           c(10, 0), c(0, 0)))),
         type = "POLYGON")
  )

  for (case in cases) {
    metadata <- snapshots[[case$id]]$metadata
    oid <- dataset_info(case$id)$object_id_field
    features <- list(
      list(attributes = setNames(list(14L, "synthetic-present"), c(oid, case$field)),
           geometry = case$geometry),
      list(attributes = setNames(list(2L, "synthetic-missing"), c(oid, case$field)),
           geometry = NULL)
    )
    transport <- fixture_transport(features = features, metadata = metadata)
    local_mocked_bindings(arcgis_http = transport$http,
                          .package = "tampaBayOpenData")

    result <- get_dataset(case$id, fields = case$field, spatial = TRUE,
                          page_size = 1)
    expect_s3_class(result, "sf")
    expect_identical(names(sf::st_drop_geometry(result)), case$field)
    expect_identical(result[[case$field]],
                     c("synthetic-missing", "synthetic-present"))
    expect_identical(sf::st_is_empty(result), c(TRUE, FALSE))
    expect_identical(as.character(sf::st_geometry_type(result)[2L]), case$type)
    expect_equal(sf::st_crs(result)$epsg, 3857)

    provenance <- dataset_provenance(result)
    expect_identical(provenance$dataset_id, case$id)
    expect_identical(provenance$matched_rows, 2L)
    expect_identical(provenance$returned_rows, 2L)
    expect_true(provenance$complete)
    expect_identical(provenance$pagination, "object-id batches")

    pages <- fixture_queries(transport, "features")
    expect_length(pages, 2L)
    expect_identical(vapply(pages, function(x) x$params$objectIds,
                            character(1)), c("2", "14"))
    expect_true(all(vapply(pages, function(x)
      identical(x$params$returnGeometry, "true") &&
        identical(x$params$outFields, paste(case$field, oid, sep = ",")),
      logical(1))))
  }
})

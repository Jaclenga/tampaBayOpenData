test_that("other cities' MapServer schemas infer IDs and retrieve every page", {
  for (case in other_city_cases()) {
    # Both real MapServer schemas omit these members, requiring OID inference.
    expect_null(case$metadata[["objectIdField", exact = TRUE]])
    expect_null(case$metadata[["objectIdFieldName", exact = TRUE]])
    transport <- fixture_transport(features = other_city_features(case),
                                   metadata = case$metadata)
    local_mocked_bindings(arcgis_http = transport$http)
    fields <- other_city_fields(case)
    result <- get_arcgis_layer(case$metadata_url, fields = fields, page_size = 1)

    expect_s3_class(result, "tbl_df")
    expect_identical(names(result), fields)
    expect_identical(result[[case$object_id_field]], c(2L, 8L, 14L))
    expect_identical(result[[case$label_field]],
                     paste0("synthetic-", c(2L, 8L, 14L), " O'Brien & \u00e9"))
    expect_identical(result[[case$integer_field]], c(33002L, NA_integer_, 33014L))
    if (!is.null(case$double_field)) {
      expect_identical(result[[case$double_field]], c(0.5, NA_real_, 3.5))
    }
    expect_identical(result[[case$date_field]],
                     as.POSIXct(c("2024-01-03", NA_character_, "2024-01-15"),
                                tz = "UTC"))

    source <- dataset_provenance(result)
    expect_identical(source$dataset_id, case$metadata_url)
    expect_identical(source$source_url, case$metadata_url)
    expect_identical(source$endpoint, paste0(case$metadata_url, "/query"))
    expect_identical(source$layer_id,
                     as.integer(sub(".*/", "", case$metadata_url)))
    expect_identical(source$validation_status, "not_checked")
    expect_identical(source$publisher, "Unknown ArcGIS publisher")
    expect_identical(source$jurisdiction, "unspecified")
    expect_null(source$item_id)
    expect_null(source$portal)
    expect_null(source$endpoint_verified)
    expect_true(source$complete)
    expect_identical(source$matched_rows, 3L)
    expect_identical(source$returned_rows, 3L)
    expect_identical(source$pagination, "object-id batches")
    expect_length(fixture_queries(transport, "count"), 1L)
    expect_length(fixture_queries(transport, "ids"), 1L)
    pages <- fixture_queries(transport, "features")
    expect_identical(vapply(pages, function(x) x$params$objectIds, character(1)),
                     c("2", "8", "14"))
    expect_true(all(vapply(transport$state$requests, function(x) {
      x$url %in% c(case$metadata_url, paste0(case$metadata_url, "/query"))
    }, logical(1))))
    expect_true(all(vapply(pages, function(x) {
      identical(x$params$outFields, paste(fields, collapse = ",")) &&
        identical(x$params$returnGeometry, "false")
    }, logical(1))))
  }
})

test_that("other cities' ordered samples and zero limits retain types and counts", {
  for (case in other_city_cases()) {
    transport <- fixture_transport(features = other_city_features(case),
                                   metadata = case$metadata)
    local_mocked_bindings(arcgis_http = transport$http)
    fields <- other_city_fields(case)
    result <- get_arcgis_layer(case$metadata_url, fields = fields, limit = 2,
                               page_size = 1,
                               order_by = paste(case$object_id_field, "DESC"))
    expect_identical(result[[case$object_id_field]], c(14L, 8L))
    source <- dataset_provenance(result)
    expect_false(source$complete)
    expect_identical(source$matched_rows, 3L)
    expect_identical(source$returned_rows, 2L)
    expect_identical(source$pagination, "ordered offsets")
    pages <- fixture_queries(transport, "features")
    expect_length(pages, 2L)
    expect_equal(vapply(pages, function(x) x$params$resultOffset, numeric(1)),
                 c(0, 1))

    transport <- fixture_transport(features = other_city_features(case),
                                   metadata = case$metadata)
    local_mocked_bindings(arcgis_http = transport$http)
    zero <- get_arcgis_layer(case$metadata_url, fields = fields, limit = 0)
    expect_identical(nrow(zero), 0L)
    expect_identical(names(zero), fields)
    expect_type(zero[[case$object_id_field]], "integer")
    expect_type(zero[[case$label_field]], "character")
    expect_type(zero[[case$integer_field]], "integer")
    expect_s3_class(zero[[case$date_field]], "POSIXct")
    expect_false(dataset_provenance(zero)$complete)
    expect_identical(dataset_provenance(zero)$matched_rows, 3L)
    expect_length(fixture_queries(transport, "features"), 0L)
  }
})

test_that("other cities' empty filters produce complete results without feature requests", {
  for (case in other_city_cases()) {
    transport <- fixture_transport(features = list(), metadata = case$metadata)
    local_mocked_bindings(arcgis_http = transport$http)
    fields <- other_city_fields(case)
    result <- get_arcgis_layer(case$metadata_url, fields = fields, where = "1=0")
    expect_s3_class(result, "tbl_df")
    expect_identical(nrow(result), 0L)
    expect_identical(names(result), fields)
    expect_s3_class(result[[case$date_field]], "POSIXct")
    source <- dataset_provenance(result)
    expect_true(source$complete)
    expect_identical(source$matched_rows, 0L)
    expect_identical(source$returned_rows, 0L)
    expect_identical(source$query$where, "1=0")
    expect_identical(fixture_queries(transport, "count")[[1L]]$params$where, "1=0")
    expect_length(fixture_queries(transport, "features"), 0L)
  }
})

test_that("other cities' native point and polygon results handle missing geometry", {
  skip_if_not_installed("sf")
  for (case in other_city_cases()) {
    transport <- fixture_transport(features = other_city_features(case),
                                   metadata = case$metadata)
    local_mocked_bindings(arcgis_http = transport$http)
    fields <- other_city_fields(case)
    result <- get_arcgis_layer(case$metadata_url, fields = fields, spatial = TRUE,
                               page_size = 1)
    expect_s3_class(result, "sf")
    expect_identical(names(sf::st_drop_geometry(result)), fields)
    expect_identical(result[[case$object_id_field]], c(2L, 8L, 14L))
    expect_identical(sf::st_is_empty(result), c(TRUE, FALSE, FALSE))
    expect_true(all(grepl(case$geometry_pattern,
                          as.character(sf::st_geometry_type(result)))))
    expect_equal(sf::st_crs(result)$epsg, case$native_epsg)
    expect_true(all(sf::st_is_valid(result)))
    source <- dataset_provenance(result)
    expect_true(source$complete)
    expect_identical(source$spatial_reference$wkid, case$native_epsg)
    expect_identical(source$validation_status, "not_checked")
    expect_identical(source$returned_rows, 3L)
    expect_true(all(vapply(fixture_queries(transport, "features"), function(x) {
      identical(x$params$returnGeometry, "true") && is.null(x$params$outSR)
    }, logical(1))))

    zero <- get_arcgis_layer(case$metadata_url, fields = fields, spatial = TRUE,
                             out_sr = 4326, limit = 0)
    expect_s3_class(zero, "sf")
    expect_identical(nrow(zero), 0L)
    expect_identical(names(sf::st_drop_geometry(zero)), fields)
    expect_equal(sf::st_crs(zero)$epsg, 4326)
    expect_equal(dataset_provenance(zero)$spatial_reference$wkid, 4326)
  }
})

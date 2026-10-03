# These bounded checks run only when explicitly enabled from an allowed network.
# They exercise direct URLs; they do not add these cities to portal discovery.
expect_live_other_city_provenance <- function(data, case, where = "1=1") {
  source <- dataset_provenance(data)
  expect_identical(source$validation_status, "not_checked")
  expect_identical(source$publisher, "Unknown ArcGIS publisher")
  expect_identical(source$jurisdiction, "unspecified")
  expect_identical(source$source_url, case$metadata_url)
  expect_identical(source$endpoint, paste0(case$metadata_url, "/query"))
  expect_null(source$item_id)
  expect_null(source$portal)
  expect_identical(source$pagination, "object-id batches")
  expect_identical(source$query$where, where)
  expect_equal(source$returned_rows, nrow(data))
  expect_gte(source$matched_rows, nrow(data))
  expect_identical(source$complete, source$matched_rows == nrow(data))
  source
}

other_city_live_where <- function(case, ids) {
  paste0(case$object_id_field, " IN (",
         paste(format(ids, scientific = FALSE, trim = TRUE), collapse = ","),
         ")")
}

for (case in other_city_cases()) {
  test_that(paste("live", case$city, "direct URLs return typed and filtered rows"), {
    skip_if_not(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
                "Set TAMPA_OPEN_DATA_LIVE=true to opt into municipal API calls")
    fields <- other_city_fields(case)
    sample <- get_arcgis_layer(case$metadata_url, fields = fields,
                               limit = 2, page_size = 1, timeout = 15)
    expect_s3_class(sample, "tbl_df")
    expect_identical(names(sample), fields)
    expect_gt(nrow(sample), 0L)
    expect_lte(nrow(sample), 2L)
    expect_type(sample[[case$object_id_field]], "integer")
    expect_type(sample[[case$label_field]], "character")
    expect_type(sample[[case$integer_field]], "integer")
    if (!is.null(case$double_field)) {
      expect_type(sample[[case$double_field]], "double")
    }
    expect_s3_class(sample[[case$date_field]], "POSIXct")
    expect_identical(attr(sample[[case$date_field]], "tzone"), "UTC")
    ids <- sample[[case$object_id_field]]
    expect_equal(anyDuplicated(ids), 0L)
    source <- expect_live_other_city_provenance(sample, case)
    expect_identical(source$query$fields, fields)
    expect_false(source$query$spatial)

    # Select IDs from this run so changing upstream counts never become fixtures.
    where <- other_city_live_where(case, ids)
    filtered <- get_arcgis_layer(case$metadata_url, where = where, fields = fields,
                                 limit = 2, page_size = 1, timeout = 15)
    expect_s3_class(filtered, "tbl_df")
    expect_identical(names(filtered), fields)
    expect_setequal(filtered[[case$object_id_field]], ids)
    expect_equal(anyDuplicated(filtered[[case$object_id_field]]), 0L)
    source <- expect_live_other_city_provenance(filtered, case, where)
    expect_true(source$complete)
    expect_equal(source$matched_rows, length(ids))
    expect_equal(source$returned_rows, length(ids))
    expect_identical(source$query$fields, fields)
  })

  test_that(paste("live", case$city, "native and projected geometries agree"), {
    skip_if_not(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
                "Set TAMPA_OPEN_DATA_LIVE=true to opt into municipal API calls")
    skip_if_not_installed("sf")
    fields <- other_city_fields(case)
    sample <- get_arcgis_layer(case$metadata_url, fields = case$object_id_field,
                               limit = 2, page_size = 1, timeout = 15)
    expect_gt(nrow(sample), 0L)
    expect_lte(nrow(sample), 2L)
    ids <- sample[[case$object_id_field]]
    expect_equal(anyDuplicated(ids), 0L)
    where <- other_city_live_where(case, ids)
    native <- get_arcgis_layer(case$metadata_url, where = where, fields = fields,
                               spatial = TRUE, limit = 2, page_size = 1,
                               timeout = 15)
    projected <- get_arcgis_layer(case$metadata_url, where = where, fields = fields,
                                  spatial = TRUE, out_sr = 4326, limit = 2,
                                  page_size = 1, timeout = 15)

    for (data in list(native, projected)) {
      expect_s3_class(data, "sf")
      expect_identical(names(sf::st_drop_geometry(data)), fields)
      expect_gt(nrow(data), 0L)
      expect_lte(nrow(data), 2L)
      expect_setequal(data[[case$object_id_field]], ids)
      expect_equal(anyDuplicated(data[[case$object_id_field]]), 0L)
      expect_false(any(sf::st_is_empty(data)))
      expect_true(all(grepl(case$geometry_pattern,
                            as.character(sf::st_geometry_type(data)))))
      source <- expect_live_other_city_provenance(data, case, where)
      expect_true(source$complete)
      expect_equal(source$matched_rows, length(ids))
      expect_equal(source$returned_rows, length(ids))
      expect_identical(source$query$fields, fields)
      expect_true(source$query$spatial)
    }
    expect_equal(sf::st_crs(native)$epsg, case$native_epsg)
    expect_equal(sf::st_crs(projected)$epsg, 4326)
    expect_null(dataset_provenance(native)$query$out_sr)
    expect_equal(dataset_provenance(projected)$query$out_sr, 4326)

    # Align by object ID before comparing attributes and coordinates.
    projected <- projected[match(native[[case$object_id_field]],
                                 projected[[case$object_id_field]]), ]
    for (field in fields) {
      expect_equal(native[[field]], projected[[field]])
    }
    expect_equal(sf::st_coordinates(sf::st_transform(native, 4326)),
                 sf::st_coordinates(projected), tolerance = 1e-5)
  })
}

spatial_metadata <- function(type = "esriGeometryPoint", wkid = 4326) {
  list(geometryType = type,
       extent = list(spatialReference = list(wkid = wkid)))
}

spatial_features <- function(...) {
  lapply(list(...), function(geometry) list(geometry = geometry))
}

test_that("spatial retrieval explains the optional sf dependency", {
  local_mocked_bindings(arcgis_has_sf = function() FALSE)
  expect_error(arcgis_as_sf(tibble::tibble(), list(), spatial_metadata()),
               "optional 'sf' package")
})

test_that("point geometry preserves parsed columns, missing rows, and ordering", {
  skip_if_not_installed("sf")
  data <- tibble::tibble(
    OBJECTID = c(30L, 10L, 20L),
    inspected = as.POSIXct(c(0, 1, NA), origin = "1970-01-01", tz = "UTC"),
    literal = c("2026-01-01", "", NA_character_),
    geometry = c("source geometry field", "B", "C"),
    .geometry = c("also a source field", "D", "E"),
    details = list(list(x = 1), NULL, c(3, 4))
  )
  features <- spatial_features(list(x = -82.4, y = 28.1, z = 9, m = 2),
                               NULL, list(x = -82.5, y = 28.2))
  result <- arcgis_as_sf(data, features, spatial_metadata())
  expect_s3_class(result, "sf")
  expect_identical(sf::st_drop_geometry(result), data)
  expect_identical(attr(result, "sf_column"), "..geometry")
  expect_equal(sf::st_crs(result)$epsg, 4326)
  expect_identical(sf::st_is_empty(result), c(FALSE, TRUE, FALSE))
  expect_equal(unname(sf::st_coordinates(result)[, c("X", "Y")]),
               matrix(c(-82.4, NA, -82.5, 28.1, NA, 28.2), ncol = 2))
  expect_false(any(c("Z", "M") %in% colnames(sf::st_coordinates(result))))
})

test_that("multipoints and multipart lines retain every part in two dimensions", {
  skip_if_not_installed("sf")
  multipoint <- arcgis_as_sf(
    tibble::tibble(id = 1L),
    spatial_features(list(points = list(c(0, 1, 8, 9), c(2, 3, 7, 6)),
                          hasZ = TRUE, hasM = TRUE)),
    spatial_metadata("esriGeometryMultipoint", 3857)
  )
  expect_equal(as.character(sf::st_geometry_type(multipoint)), "MULTIPOINT")
  expect_equal(unname(sf::st_coordinates(multipoint)[, c("X", "Y")]),
               matrix(c(0, 2, 1, 3), ncol = 2))
  expect_false(any(c("Z", "M") %in% colnames(sf::st_coordinates(multipoint))))

  partially_empty <- arcgis_as_sf(
    tibble::tibble(id = 1L),
    spatial_features(list(points = list(list(NULL, NULL), c(2, 3)))),
    spatial_metadata("esriGeometryMultipoint", 3857)
  )
  expect_equal(unname(sf::st_coordinates(partially_empty)[, c("X", "Y"), drop = FALSE]),
               matrix(c(2, 3), ncol = 2))

  lines <- arcgis_as_sf(
    tibble::tibble(id = c(1L, 2L)),
    spatial_features(list(paths = list(list(c(0, 0), c(1, 1)),
                                        list(c(3, 3), c(4, 4), c(5, 5)))),
                     NULL),
    spatial_metadata("esriGeometryPolyline", 3857)
  )
  expect_equal(as.character(sf::st_geometry_type(lines)),
               c("MULTILINESTRING", "MULTILINESTRING"))
  expect_length(sf::st_geometry(lines)[[1L]], 2L)
  expect_equal(unname(sf::st_geometry(lines)[[1L]][[2L]]),
               matrix(c(3, 4, 5, 3, 4, 5), ncol = 2))
  expect_identical(sf::st_is_empty(lines), c(FALSE, TRUE))
})

test_that("GDAL preserves polygon holes and separate exterior rings", {
  skip_if_not_installed("sf")
  exterior <- list(c(0, 0), c(0, 10), c(10, 10), c(10, 0), c(0, 0))
  hole <- list(c(2, 2), c(8, 2), c(8, 8), c(2, 8), c(2, 2))
  separate <- list(c(20, 0), c(20, 5), c(25, 5), c(25, 0), c(20, 0))
  result <- arcgis_as_sf(
    tibble::tibble(id = 7L),
    spatial_features(list(rings = list(hole, separate, exterior))),
    spatial_metadata("esriGeometryPolygon", 3857)
  )
  expect_equal(as.character(sf::st_geometry_type(result)), "MULTIPOLYGON")
  expect_length(sf::st_geometry(result)[[1L]], 2L)
  expect_equal(sort(lengths(sf::st_geometry(result)[[1L]])), c(1L, 2L))
  expect_equal(as.numeric(sf::st_area(result)), 89)
})

test_that("empty and entirely missing results retain schema and known CRS", {
  skip_if_not_installed("sf")
  for (type in c("esriGeometryPoint", "esriGeometryMultipoint",
                 "esriGeometryPolyline", "esriGeometryPolygon")) {
    data <- tibble::tibble(id = c(1L, 2L), label = c("a", "b"))
    result <- arcgis_as_sf(data, spatial_features(NULL, NULL),
                          spatial_metadata(type, 3857))
    expect_identical(sf::st_drop_geometry(result), data)
    expect_true(all(sf::st_is_empty(result)))
    expect_equal(sf::st_crs(result)$epsg, 3857)
    empty_data <- data[integer(), ]
    empty <- arcgis_as_sf(empty_data, list(), spatial_metadata(type, 3857))
    expect_s3_class(empty, "sf")
    expect_identical(sf::st_drop_geometry(empty), empty_data)
    expect_equal(sf::st_crs(empty)$epsg, 3857)
  }
})

test_that("ArcGIS empty geometry objects become empty features", {
  skip_if_not_installed("sf")
  objects <- list(list(x = NULL), list(points = list()),
                  list(paths = list()), list(rings = list()))
  types <- c("esriGeometryPoint", "esriGeometryMultipoint",
             "esriGeometryPolyline", "esriGeometryPolygon")
  for (i in seq_along(types)) {
    result <- arcgis_as_sf(tibble::tibble(id = 1L),
                          spatial_features(objects[[i]]),
                          spatial_metadata(types[[i]]))
    expect_identical(sf::st_is_empty(result), TRUE)
  }
})

test_that("zero-row results have a typed requested CRS without invented coordinates", {
  skip_if_not_installed("sf")
  data <- tibble::tibble(id = integer(),
                         inspected = as.POSIXct(numeric(), origin = "1970-01-01", tz = "UTC"))
  types <- c("esriGeometryPoint", "esriGeometryMultipoint",
             "esriGeometryPolyline", "esriGeometryPolygon")
  sfc_classes <- c("sfc_POINT", "sfc_MULTIPOINT",
                   "sfc_MULTILINESTRING", "sfc_MULTIPOLYGON")
  for (i in seq_along(types)) {
    # This metadata deliberately provides no native SR. The requested reference
    # can describe an empty schema without claiming where coordinates came from.
    result <- arcgis_as_sf(data, list(), list(geometryType = types[[i]]),
                          out_sr = 4326)
    expect_identical(sf::st_drop_geometry(result), data)
    expect_equal(sf::st_crs(result)$epsg, 4326)
    expect_s3_class(sf::st_geometry(result), sfc_classes[[i]])
    expect_length(sf::st_geometry(result), 0L)
  }
  # A missing geometry still belongs to a real response row, so its CRS must be
  # evidenced by the response when projection was requested.
  expect_error(arcgis_as_sf(tibble::tibble(id = 1L), spatial_features(NULL),
                           spatial_metadata(), out_sr = 4326),
               "response must identify")
})

test_that("response CRS, latest WKIDs, ArcGIS aliases, and WKT are respected", {
  skip_if_not_installed("sf")
  data <- tibble::tibble(id = 1L)
  features <- spatial_features(list(x = 1, y = 2))
  metadata <- spatial_metadata(wkid = 102100)
  result <- arcgis_as_sf(data, features, metadata)
  expect_equal(sf::st_crs(result)$epsg, 3857)
  latest <- arcgis_as_sf(data, features, metadata,
                         spatial_reference = list(wkid = 999999, latestWkid = 4326),
                         out_sr = 4326)
  expect_equal(sf::st_crs(latest)$epsg, 4326)
  capital <- arcgis_as_sf(data, features, spatial_metadata(wkid = 103023))
  expect_equal(sf::st_crs(capital)$epsg, 6443)
  capital_latest <- arcgis_as_sf(data, features, metadata,
                                list(wkid = 103023, latestWkid = 6443))
  expect_equal(sf::st_crs(capital_latest)$epsg, 6443)
  wkt <- arcgis_as_sf(data, features, metadata,
                      list(wkt = sf::st_crs(4326)$wkt))
  expect_equal(sf::st_crs(wkt)$epsg, 4326)
  direct <- metadata
  direct$extent <- NULL
  direct$spatialReference <- list(wkid = 4326)
  expect_equal(sf::st_crs(arcgis_as_sf(data, features, direct))$epsg, 4326)
})

test_that("unknown or contradictory CRS cannot be inferred from out_sr", {
  skip_if_not_installed("sf")
  data <- tibble::tibble(id = 1L)
  features <- spatial_features(list(x = 1, y = 2))
  unknown <- list(geometryType = "esriGeometryPoint")
  expect_error(arcgis_as_sf(data, features, unknown), "no known spatial reference")
  expect_error(arcgis_as_sf(data, features, spatial_metadata(), out_sr = 4326),
               "response must identify")
  expect_error(arcgis_as_sf(data, features, spatial_metadata(),
                           list(wkid = 3857), out_sr = 4326),
               "differs from the requested")
  expect_error(arcgis_as_sf(data, features, spatial_metadata(), list(wkid = "4326")),
               "malformed WKID")
  expect_error(arcgis_as_sf(data, features, spatial_metadata(), list(wkid = 999999)),
               "could not be resolved")
  expect_error(arcgis_as_sf(data, spatial_features(list(x = 1, y = 2,
                                                       spatialReference = list(wkid = 3857))),
                           spatial_metadata()), "different CRS")
})

test_that("malformed geometry and unexpected layer types fail explicitly", {
  skip_if_not_installed("sf")
  data <- tibble::tibble(id = 1L)
  for (geometry in list(list(x = "1", y = 2), list(x = Inf, y = 2),
                        list(y = 2), list(paths = list()), 7)) {
    expect_error(arcgis_as_sf(data, spatial_features(geometry), spatial_metadata()),
                 "Malformed ArcGIS geometry")
  }
  expect_error(arcgis_as_sf(data, spatial_features(list(points = list(c(1)))),
                           spatial_metadata("esriGeometryMultipoint")),
               "coordinate arrays")
  expect_error(arcgis_as_sf(data, spatial_features(list(paths = list(list(c(0, 0))))),
                           spatial_metadata("esriGeometryPolyline")),
               "enough coordinate")
  expect_error(arcgis_as_sf(data, spatial_features(list(rings = list(
    list(c(0, 0), c(0, 1), c(1, 1), c(1, 0))))),
    spatial_metadata("esriGeometryPolygon")), "must.*be closed")
  expect_error(arcgis_as_sf(data, spatial_features(list(curvePaths = list())),
                           spatial_metadata("esriGeometryPolyline")), "unsupported curves")
  expect_error(arcgis_as_sf(data, spatial_features(NULL),
                           spatial_metadata("esriGeometryEnvelope")), "no supported")
  expect_error(arcgis_as_sf(data, list(), spatial_metadata()), "different row counts")
  expect_error(arcgis_as_sf(data, list(7), spatial_metadata()), "Malformed ArcGIS feature")
})

test_that("spatial conversion detects GDAL row loss and geometry loss", {
  skip_if_not_installed("sf")
  data <- tibble::tibble(id = c(1L, 2L))
  features <- spatial_features(list(x = 1, y = 2), list(x = 3, y = 4))
  local_mocked_bindings(arcgis_read_esrijson = function(path) {
    sf::st_sf(tampa_row_id = 1L, geometry = sf::st_sfc(sf::st_point(c(1, 2)),
                                                     crs = 4326))
  })
  expect_error(arcgis_as_sf(data, features, spatial_metadata()), "GDAL dropped")
})

test_that("GDAL geometry types and synthetic row IDs are verified", {
  skip_if_not_installed("sf")
  data <- tibble::tibble(id = c(1L, 2L))
  features <- spatial_features(list(x = 1, y = 2), list(x = 3, y = 4))
  local_mocked_bindings(arcgis_read_esrijson = function(path) {
    sf::st_sf(tampa_row_id = c(1L, 2L), geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(1, 2, 3, 4), ncol = 2)),
      sf::st_linestring(matrix(c(1, 2, 3, 4), ncol = 2)), crs = 4326))
  })
  expect_error(arcgis_as_sf(data, features, spatial_metadata()), "unexpected type")
})

test_that("GDAL row order is restored before attaching parsed attributes", {
  skip_if_not_installed("sf")
  data <- tibble::tibble(id = c(1L, 2L))
  features <- spatial_features(list(x = 1, y = 2), list(x = 3, y = 4))
  local_mocked_bindings(arcgis_read_esrijson = function(path) {
    sf::st_sf(tampa_row_id = c(2L, 1L), geometry = sf::st_sfc(
      sf::st_point(c(3, 4)), sf::st_point(c(1, 2)), crs = 4326))
  })
  result <- arcgis_as_sf(data, features, spatial_metadata())
  expect_identical(sf::st_drop_geometry(result), data)
  expect_equal(unname(sf::st_coordinates(result)),
               matrix(c(1, 3, 2, 4), ncol = 2))
})

test_that("invalid polygon topology is returned without silent repair", {
  skip_if_not_installed("sf")
  ring <- list(c(0, 0), c(2, 2), c(0, 2), c(2, 0), c(0, 0))
  result <- arcgis_as_sf(tibble::tibble(id = 1L),
                        spatial_features(list(rings = list(ring))),
                        spatial_metadata("esriGeometryPolygon", 3857))
  expect_identical(sf::st_is_valid(result), FALSE)
  expect_equal(unname(sf::st_coordinates(result)[, c("X", "Y")]),
               do.call(rbind, ring))
})

test_that("nonempty geometries cannot be silently lost by GDAL", {
  skip_if_not_installed("sf")
  local_mocked_bindings(arcgis_read_esrijson = function(path) {
    sf::st_sf(tampa_row_id = 1L, geometry = sf::st_sfc(
      sf::st_point(c(NA_real_, NA_real_)), crs = 4326))
  })
  expect_error(arcgis_as_sf(tibble::tibble(id = 1L),
                           spatial_features(list(x = 1, y = 2)),
                           spatial_metadata()), "empty or unexpected")
})

test_that("duplicate driver row IDs cannot duplicate parsed attributes", {
  skip_if_not_installed("sf")
  local_mocked_bindings(arcgis_read_esrijson = function(path) {
    sf::st_sf(tampa_row_id = c(1L, 1L), geometry = sf::st_sfc(
      sf::st_point(c(1, 2)), sf::st_point(c(3, 4)), crs = 4326))
  })
  expect_error(arcgis_as_sf(tibble::tibble(id = c(1L, 2L)),
                           spatial_features(list(x = 1, y = 2), list(x = 3, y = 4)),
                           spatial_metadata()), "GDAL dropped, duplicated")
})

test_that("the driver must retain the verified CRS", {
  skip_if_not_installed("sf")
  local_mocked_bindings(arcgis_read_esrijson = function(path) {
    sf::st_sf(tampa_row_id = 1L, geometry = sf::st_sfc(sf::st_point(c(1, 2))))
  })
  expect_error(arcgis_as_sf(tibble::tibble(id = 1L),
                           spatial_features(list(x = 1, y = 2)),
                           spatial_metadata()), "did not retain")
})

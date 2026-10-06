bug_spatial_result <- function(json, type) {
  geometry <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  arcgis_as_sf(
    tibble::tibble(id = 1L), list(list(geometry = geometry)),
    list(geometryType = type, spatialReference = list(wkid = 3857L))
  )
}

test_that("closed polygon rings compare numeric coordinates across JSON types", {
  skip_if_not_installed("sf")
  rings <- c(
    '{"rings":[[[0,0],[0,1],[1,1],[1,0],[0.0,0.0]]]}',
    '{"rings":[[[0.0,0.0],[0,1],[1,1],[1,0],[0,0]]]}',
    '{"rings":[[[0,0.0],[0,1],[1,1],[1,0],[0.0,0]]]}',
    '{"rings":[[[0,0,9,1],[0,1,9,1],[1,1,9,1],[1,0,9,1],[0.0,0.0,8,2]]]}'
  )
  expected <- matrix(c(0, 0, 1, 1, 0, 0, 1, 1, 0, 0), ncol = 2L)
  for (ring in rings) {
    result <- bug_spatial_result(ring, "esriGeometryPolygon")
    expect_identical(sf::st_drop_geometry(result), tibble::tibble(id = 1L))
    expect_identical(as.character(sf::st_geometry_type(result)), "POLYGON")
    expect_equal(unname(sf::st_coordinates(result)[, c("X", "Y")]), expected)
    expect_equal(as.numeric(sf::st_area(result)), 1)
  }
})

test_that("named coordinate objects cannot be interpreted as positional XY arrays", {
  skip_if_not_installed("sf")
  cases <- list(
    list(type = "esriGeometryMultipoint",
         json = '{"points":[{"y":10,"x":20}]}'),
    list(type = "esriGeometryMultipoint",
         json = '{"points":[{"x":null,"y":null}]}'),
    list(type = "esriGeometryPolyline",
         json = '{"paths":[[{"y":0,"x":0},[1,1]]]}'),
    list(type = "esriGeometryPolyline",
         json = '{"paths":[[{"x":null,"y":null},[1,1]]]}'),
    list(type = "esriGeometryPolygon",
         json = '{"rings":[[{"y":0,"x":0},[0,1],[1,1],[1,0],[0,0]]]}'),
    list(type = "esriGeometryPolygon",
         json = '{"rings":[[{"x":null,"y":null},[0,1],[1,1],[1,0],[0,0]]]}')
  )
  for (case in cases) {
    expect_error(bug_spatial_result(case$json, case$type), "coordinate arrays",
                 class = "tampa_spatial_error")
  }
})

test_that("numeric ring closure still rejects different endpoint coordinates", {
  skip_if_not_installed("sf")
  for (ring in c(
    '{"rings":[[[0,0],[0,1],[1,1],[1,0],[0.0,0.001]]]}',
    '{"rings":[[[0,0],[0,1],[1,1],[1,0]]]}'
  )) {
    expect_error(bug_spatial_result(ring, "esriGeometryPolygon"),
                 "must.*be closed", class = "tampa_spatial_error")
  }
})

test_that("valid XY and ZM coordinate arrays retain their two dimensional geometry", {
  skip_if_not_installed("sf")
  multipoint <- bug_spatial_result(
    '{"points":[[null,null],[0,1],[2,3,8,9]]}', "esriGeometryMultipoint"
  )
  expect_identical(as.character(sf::st_geometry_type(multipoint)), "MULTIPOINT")
  expect_equal(unname(sf::st_coordinates(multipoint)[, c("X", "Y")]),
               matrix(c(0, 2, 1, 3), ncol = 2L))
  expect_false(any(c("Z", "M") %in% colnames(sf::st_coordinates(multipoint))))

  line <- bug_spatial_result(
    '{"paths":[[[0,1],[2,3,8,9]]]}', "esriGeometryPolyline"
  )
  expect_identical(as.character(sf::st_geometry_type(line)), "LINESTRING")
  expect_equal(unname(sf::st_coordinates(line)[, c("X", "Y")]),
               matrix(c(0, 2, 1, 3), ncol = 2L))
  expect_false(any(c("Z", "M") %in% colnames(sf::st_coordinates(line))))
})

test_that("partially null XY coordinates cannot become empty geometry", {
  skip_if_not_installed("sf")
  for (json in c('{"x":null,"y":3}', '{"x":3,"y":null}')) {
    expect_error(bug_spatial_result(json, "esriGeometryPoint"),
                 "point coordinates must be finite", class = "tampa_spatial_error")
  }
  for (json in c('{"points":[[null,3]]}', '{"points":[[3,null]]}',
                 '{"points":[[null]]}')) {
    expect_error(bug_spatial_result(json, "esriGeometryMultipoint"),
                 "coordinate arrays must contain finite", class = "tampa_spatial_error")
  }
  empty <- bug_spatial_result('{"x":null,"y":null}', "esriGeometryPoint")
  expect_identical(sf::st_is_empty(empty), TRUE)
})

test_that("spatial response keys require exact names", {
  skip_if_not_installed("sf")
  data <- tibble::tibble(id = 1L)
  metadata <- list(geometryType = "esriGeometryPoint",
                   spatialReference = list(wkid = 4326L))
  extra_geometry <- arcgis_as_sf(
    data, list(list(geometryExtra = list(x = 1, y = 2))), metadata
  )
  expect_identical(sf::st_is_empty(extra_geometry), TRUE)

  feature <- list(list(geometry = list(x = 1, y = 2,
                                       spatialReferenceExtra = list(wkid = 3857L))))
  result <- arcgis_as_sf(data, feature, metadata)
  expect_equal(unname(sf::st_coordinates(result)), matrix(c(1, 2), nrow = 1L))

  for (source in list(
    list(spatialReferenceExtra = list(wkid = 4326L)),
    list(extent = list(spatialReferenceExtra = list(wkid = 4326L))),
    list(sourceSpatialReferenceExtra = list(wkid = 4326L))
  )) {
    expect_error(arcgis_as_sf(data, feature,
                              c(list(geometryType = "esriGeometryPoint"), source)),
                 "no known spatial reference", class = "tampa_spatial_error")
  }
  expect_error(arcgis_as_sf(data, feature,
                            list(geometryTypeExtra = "esriGeometryPoint",
                                 spatialReference = list(wkid = 4326L))),
               "no supported spatial geometry type", class = "tampa_spatial_error")
  expect_error(bug_spatial_result('{"x":1,"yExtra":2}', "esriGeometryPoint"),
               "point coordinates must be finite", class = "tampa_spatial_error")
  expect_error(arcgis_spatial_crs(list(wktExtra = sf::st_crs(4326)$wkt)),
               "could not be resolved", class = "tampa_spatial_error")
})

test_that("resolvable WKID identifiers cannot disagree within one spatial reference", {
  skip_if_not_installed("sf")
  for (reference in list(list(wkid = 3857L, latestWkid = 4326L),
                         list(wkid = 4326L, latestWkid = 3857L))) {
    expect_error(arcgis_spatial_crs(reference), "conflicting WKID",
                 class = "tampa_spatial_error")
    transport <- fixture_transport(
      features = fixture_features(1L),
      transform = function(payload, params, url, request_number) {
        if (!is.null(payload$features)) payload$spatialReference <- reference
        payload
      }
    )
    local_mocked_bindings(arcgis_http = transport$http,
                          .package = "tampaBayOpenData")
    error <- tryCatch(tbod_get_dataset("construction-permits", spatial = TRUE),
                       error = identity)
    expect_s3_class(error, "tampa_spatial_error")
    expect_match(conditionMessage(error), "conflicting WKID")
    expect_identical(error$dataset_id, "construction-permits")
    entry <- tbod_dataset_info("construction-permits")
    expect_match(conditionMessage(error), entry$source_url, fixed = TRUE)
    expect_match(conditionMessage(error), "Publisher: City of Tampa", fixed = TRUE)
  }
})

test_that("matching WKID aliases remain valid in either field order", {
  skip_if_not_installed("sf")
  pairs <- list(c(102100L, 3857L), c(102113L, 3857L),
                c(102659L, 2237L), c(103023L, 6443L))
  for (pair in pairs) {
    for (codes in list(pair, rev(pair))) {
      result <- arcgis_as_sf(
        tibble::tibble(id = 1L), list(list(geometry = list(x = 100, y = 200))),
        list(geometryType = "esriGeometryPoint"),
        spatial_reference = list(wkid = codes[[1L]], latestWkid = codes[[2L]])
      )
      expect_equal(sf::st_crs(result)$epsg, pair[[2L]])
      expect_equal(unname(sf::st_coordinates(result)), matrix(c(100, 200), nrow = 1L))
    }
  }
})

test_that("an unresolved historical WKID does not defeat a known identifier", {
  skip_if_not_installed("sf")
  for (reference in list(list(wkid = 999999L, latestWkid = 4326L),
                         list(wkid = 4326L, latestWkid = 999999L))) {
    result <- arcgis_as_sf(
      tibble::tibble(id = 1L), list(list(geometry = list(x = 1, y = 2))),
      list(geometryType = "esriGeometryPoint"), spatial_reference = reference
    )
    expect_equal(sf::st_crs(result)$epsg, 4326L)
    expect_equal(unname(sf::st_coordinates(result)), matrix(c(1, 2), nrow = 1L))
  }
})

test_that("explicit WKT keeps precedence over internally consistent WKID identifiers", {
  skip_if_not_installed("sf")
  wgs84 <- sf::st_crs(4326)
  mercator <- sf::st_crs(3857)
  expect_true(isTRUE(arcgis_spatial_crs(list(wkt = wgs84$wkt)) == wgs84))
  expect_true(isTRUE(arcgis_spatial_crs(
    list(wkt = mercator$wkt, wkid = 4326L, latestWkid = 4326L)
  ) == mercator))
})

test_that("compound WKT remains usable alongside horizontal WKID identifiers", {
  skip_if_not_installed("sf")
  compound <- sf::st_crs(7405)
  skip_if(is.na(compound), "The local CRS database does not contain EPSG:7405.")
  # The WKT includes a vertical component; the two WKIDs identify its horizontal
  # British National Grid component and should only be compared with each other.
  expect_true(isTRUE(arcgis_spatial_crs(
    list(wkt = compound$wkt, wkid = 27700L, latestWkid = 27700L)
  ) == compound))
})

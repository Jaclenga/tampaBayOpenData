review_metadata <- function() {
  list(
    fields = list(
      list(name = "OBJECTID", type = "esriFieldTypeOID"),
      list(name = "VALUE", type = "esriFieldTypeString")
    ),
    objectIdField = "OBJECTID", maxRecordCount = 1L,
    capabilities = "Query", geometryType = "esriGeometryPoint",
    extent = list(spatialReference = list(wkid = 3857L)),
    advancedQueryCapabilities = list(supportsOrderBy = TRUE,
                                     supportsPagination = TRUE)
  )
}

review_response <- function(payload) {
  list(status = 200L,
       body = as.character(jsonlite::toJSON(payload, auto_unbox = TRUE,
                                           null = "null", digits = NA)))
}

review_transport <- function(references = list(NULL, list(wkid = 4326L)),
                             matched = 2L) {
  force(references)
  force(matched)
  function(url, params, timeout) {
    if (!grepl("/query$", url)) return(review_response(review_metadata()))
    if (identical(params$returnCountOnly, "true")) {
      return(review_response(list(count = matched)))
    }
    if (identical(params$returnIdsOnly, "true")) {
      return(review_response(list(objectIds = as.list(seq_len(matched)),
                                  objectIdFieldName = "OBJECTID")))
    }
    id <- as.integer(params$objectIds)
    stopifnot(length(id) == 1L, !is.na(id))
    payload <- list(features = list(list(
      attributes = list(OBJECTID = id, VALUE = paste0("value-", id)),
      geometry = if (id == 1L) list(x = -9180000, y = 3220000) else
        list(x = -82.4, y = 27.9)
    )))
    if (!is.null(references[[id]])) payload$spatialReference <- references[[id]]
    review_response(payload)
  }
}

test_that("JSON-style spatial query values retain numeric precision", {
  geometry <- list(x = -82.4581234567, y = 27.9471234567,
                   spatialReference = list(wkid = 4326L))
  params <- .query_params(list(geometry = geometry))
  actual <- jsonlite::fromJSON(params$geometry)
  expect_equal(actual$x, geometry$x, tolerance = 0)
  expect_equal(actual$y, geometry$y, tolerance = 0)
  expect_equal(actual$spatialReference$wkid, 4326L)
})

test_that("date-only parsing rejects trailing text and invalid calendar dates", {
  metadata <- list(fields = list(list(name = "DATE", type = "esriFieldTypeDateOnly")))
  for (value in c("2026-01-01garbage", "2026-02-30", "2026-1-1")) {
    expect_error(arcgis_parse(list(list(attributes = list(DATE = value))),
                             metadata, "DATE"),
                 "Invalid date-only", class = "tampa_data_error")
  }
  result <- arcgis_parse(list(list(attributes = list(DATE = "2026-01-01")),
                             list(attributes = list(DATE = NULL))), metadata, "DATE")
  expect_identical(result$DATE, as.Date(c("2026-01-01", NA_character_)))
})

test_that("ordinary integer fields cannot silently exceed exact numeric precision", {
  metadata <- list(fields = list(list(name = "INTEGER", type = "esriFieldTypeInteger")))
  rounded <- jsonlite::fromJSON("9007199254740993")
  expect_error(arcgis_parse(list(list(attributes = list(INTEGER = rounded))),
                           metadata, "INTEGER"),
               "exact JSON/R integer precision", class = "tampa_data_error")
  safe <- arcgis_parse(list(list(attributes = list(INTEGER = 9007199254740991))),
                       metadata, "INTEGER")
  expect_identical(safe$INTEGER, 9007199254740991)
})

test_that("malformed ArcGIS error payloads retain source context", {
  local_mocked_bindings(arcgis_http = function(...) {
    list(status = 200L, body = '{"error":"bad"}')
  })
  dataset <- .lookup_dataset("construction-permits")
  error <- tryCatch(arcgis_request(paste0(dataset$service_url, "/0/query"),
                                  dataset = dataset), error = identity)
  expect_s3_class(error, "tampa_response_error")
  expect_identical(error$dataset_id, "construction-permits")
  expect_match(conditionMessage(error), "malformed ArcGIS error object")
  expect_match(conditionMessage(error), dataset$source_url, fixed = TRUE)
})

test_that("duplicate JSON keys and nonscalar feature IDs fail explicitly", {
  local_mocked_bindings(arcgis_http = function(...) {
    list(status = 200L, body = '{"count":0,"count":100}')
  })
  expect_error(arcgis_request("https://example.org/query"),
               "duplicate JSON object keys", class = "tampa_response_error")
  duplicate <- jsonlite::fromJSON(
    '{"features":[{"attributes":{"OBJECTID":1,"VALUE":"old","VALUE":"new"}}]}',
    simplifyVector = FALSE)
  expect_error(.page_features(duplicate, review_metadata(), NULL, "probe"),
               class = "tampa_response_error")
  expect_error(.page_features(
    list(features = list(list(attributes = list(OBJECTID = list(1))))),
    review_metadata(), NULL, "probe"), class = "tampa_response_error")
})

test_that("ordering rejects empty strings and empty comma-separated terms", {
  for (value in c("", " ", "OBJECTID,", ",OBJECTID", "OBJECTID,,VALUE")) {
    expect_error(.ordering(value, review_metadata()), class = "tampa_data_error")
  }
  expect_identical(.ordering("VALUE DESC", review_metadata()),
                   "VALUE DESC,OBJECTID ASC")
})

test_that("a later page cannot confirm an earlier projected page's missing CRS", {
  skip_if_not_installed("sf")
  local_mocked_bindings(arcgis_http = review_transport())
  expect_error(get_dataset("construction-permits", fields = "VALUE",
                           spatial = TRUE, out_sr = 4326, page_size = 1),
               "projected spatial page did not identify", class = "tampa_spatial_error")
})

test_that("native metadata fallback cannot hide a CRS change on a later page", {
  skip_if_not_installed("sf")
  local_mocked_bindings(arcgis_http = review_transport())
  expect_error(get_dataset("construction-permits", fields = "VALUE",
                           spatial = TRUE, page_size = 1),
               "CRS changed between pages", class = "tampa_integrity_error")
})

test_that("empty projected results retain the requested CRS in provenance", {
  skip_if_not_installed("sf")
  local_mocked_bindings(arcgis_http = review_transport())
  result <- get_dataset("construction-permits", fields = "VALUE", spatial = TRUE,
                        out_sr = 4326, limit = 0)
  expect_s3_class(result, "sf")
  expect_identical(nrow(result), 0L)
  expect_identical(result$VALUE, character())
  expect_equal(sf::st_crs(result)$epsg, 4326L)
  provenance <- dataset_provenance(result)
  expect_equal(provenance$spatial_reference$wkid, 4326L)
  expect_equal(provenance$matched_rows, 2L)
  expect_identical(provenance$complete, FALSE)
})

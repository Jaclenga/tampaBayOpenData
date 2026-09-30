# A response failure must identify the dataset, source, and precise endpoint.
bug_response_error <- function(expr, endpoint, class = "tampa_response_error") {
  failure <- tryCatch(force(expr), error = identity)
  expect_s3_class(failure, class)
  if (inherits(failure, "error")) {
    entry <- dataset_info("construction-permits")
    expect_identical(failure$dataset_id, entry$id)
    expect_identical(failure$url, endpoint)
    expect_match(conditionMessage(failure), entry$source_url, fixed = TRUE)
  }
  failure
}

test_that("duplicate nested metadata keys fail during live schema inspection", {
  transport <- fixture_transport(features = fixture_features(1L))
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    response <- transport$http(url, params, timeout)
    if (!grepl("/query$", url)) {
      response$body <- sub(
        '"type":"esriFieldTypeDate"',
        '"type":"esriFieldTypeDate","type":"esriFieldTypeString"',
        response$body, fixed = TRUE)
    }
    response
  }, .package = "tampaBayOpenData")
  entry <- dataset_info("construction-permits")
  endpoint <- paste0(entry$service_url, "/", entry$layer_id)

  failure <- bug_response_error(
    dataset_info(entry$id, refresh = TRUE), endpoint)
  if (inherits(failure, "error")) {
    expect_match(conditionMessage(failure), "duplicate JSON object keys")
  }
  expect_length(fixture_queries(transport), 0L)
})

test_that("duplicate nested feature and spatial keys cannot select one interpretation", {
  # Deliberately raw JSON preserves duplicate keys that ordinary list fixtures
  # would normalize. Validation applies before optional geometry conversion.
  bodies <- c(
    '{"features":[{"attributes":{"OBJECTID":1,"RECORD_ID":"old"},"attributes":{"OBJECTID":1,"RECORD_ID":"new"}}]}',
    '{"features":[{"attributes":{"OBJECTID":1,"RECORD_ID":"synthetic-1"},"geometry":{"x":-9170000,"x":-82.4,"y":3250000}}]}',
    '{"features":[{"attributes":{"OBJECTID":1,"RECORD_ID":"synthetic-1"}}],"spatialReference":{"wkid":3857,"wkid":4326}}'
  )
  entry <- dataset_info("construction-permits")
  endpoint <- paste0(entry$service_url, "/", entry$layer_id, "/query")
  for (body in bodies) {
    transport <- fixture_transport(features = fixture_features(1L))
    local_mocked_bindings(arcgis_http = function(url, params, timeout) {
      response <- transport$http(url, params, timeout)
      if (!is.null(params$objectIds)) response$body <- body
      response
    }, .package = "tampaBayOpenData")

    failure <- bug_response_error(
      get_dataset(entry$id, fields = c("OBJECTID", "RECORD_ID")), endpoint)
    if (inherits(failure, "error")) {
      expect_match(conditionMessage(failure), "duplicate JSON object keys")
    }
    expect_length(fixture_queries(transport, "features"), 1L)
  }
})

test_that("object-valued layer metadata cannot be a nonempty JSON array", {
  properties <- c("advancedQueryCapabilities", "dateFieldsTimeReference", "extent",
                  "spatialReference", "sourceSpatialReference")
  entry <- dataset_info("construction-permits")
  endpoint <- paste0(entry$service_url, "/", entry$layer_id)
  for (property in properties) {
    metadata <- fixture_metadata()
    metadata[[property]] <- list("Unknown")
    transport <- fixture_transport(metadata = metadata)
    local_mocked_bindings(arcgis_http = transport$http,
                          .package = "tampaBayOpenData")

    failure <- bug_response_error(
      get_dataset(entry$id, fields = "LASTUPDATE"), endpoint)
    if (inherits(failure, "error")) {
      expect_match(conditionMessage(failure), property, fixed = TRUE)
    }
    # In particular, malformed date metadata must fail before dates can be
    # fetched and assigned UTC instants without timezone evidence.
    expect_length(fixture_queries(transport), 0L)
  }
})

test_that("empty optional metadata containers retain table retrieval compatibility", {
  metadata <- fixture_metadata()
  for (property in c("advancedQueryCapabilities", "dateFieldsTimeReference", "extent",
                     "spatialReference", "sourceSpatialReference")) {
    metadata[[property]] <- list()
  }
  transport <- fixture_transport(metadata = metadata)
  local_mocked_bindings(arcgis_http = transport$http,
                        .package = "tampaBayOpenData")
  result <- get_dataset("construction-permits", fields = "OBJECTID")
  expect_identical(result$OBJECTID, 1:5)
  expect_true(dataset_provenance(result)$complete)
})

test_that("manifest transfer-limit flags obey the same contract as feature pages", {
  entry <- dataset_info("construction-permits")
  endpoint <- paste0(entry$service_url, "/", entry$layer_id, "/query")
  for (flag in list("true", "false", 1L, list(TRUE), list(TRUE, FALSE))) {
    transport <- fixture_transport(transform = function(payload, params, ...) {
      if (identical(params$returnIdsOnly, "true")) {
        payload$exceededTransferLimit <- flag
      }
      payload
    })
    local_mocked_bindings(arcgis_http = transport$http,
                          .package = "tampaBayOpenData")

    failure <- bug_response_error(get_dataset(entry$id), endpoint)
    if (inherits(failure, "error")) {
      expect_match(conditionMessage(failure), "transfer-limit flag")
    }
    expect_length(fixture_queries(transport, "features"), 0L)
  }
})

test_that("a changed feature-page OID declaration cannot claim complete retrieval", {
  transport <- fixture_transport(transform = function(payload, params, ...) {
    if (!is.null(params$objectIds)) payload$objectIdFieldName <- "OTHER_ID"
    payload
  })
  local_mocked_bindings(arcgis_http = transport$http,
                        .package = "tampaBayOpenData")
  entry <- dataset_info("construction-permits")
  endpoint <- paste0(entry$service_url, "/", entry$layer_id, "/query")

  failure <- bug_response_error(get_dataset(entry$id), endpoint,
                                class = "tampa_integrity_error")
  if (inherits(failure, "error")) {
    expect_match(conditionMessage(failure), "object-ID field changed")
  }
  expect_length(fixture_queries(transport, "features"), 1L)
})

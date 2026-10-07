test_that("unordered retrieval validates and reorders several service-sized batches", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  result <- tbod_get_dataset("construction-permits", page_size = 20)
  expect_identical(result$OBJECTID, 1:5)
  expect_identical(result$RECORD_ID, paste0("synthetic-", 1:5))
  expect_false("SHAPE" %in% names(result))
  requests <- fixture_queries(transport, "features")
  expect_length(requests, 3L)
  expect_identical(vapply(requests, function(x) x$params$objectIds, character(1)),
                   c("1,2", "3,4", "5"))
  expect_true(all(vapply(requests, function(x) identical(x$params$returnGeometry, "false"),
                        logical(1))))
  expect_true(all(vapply(requests, function(x) is.null(x$params$resultOffset), logical(1))))
  expect_identical(tbod_provenance(result)$pagination, "object-id batches")
  expect_true(tbod_provenance(result)$complete)
})

test_that("field selection requests a hidden OID then returns only selected attributes", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  result <- tbod_get_dataset("construction-permits", fields = c("RECORD_ID", "LASTUPDATE"))
  expect_identical(names(result), c("RECORD_ID", "LASTUPDATE"))
  expect_s3_class(result$LASTUPDATE, "POSIXct")
  requests <- fixture_queries(transport, "features")
  expect_true(all(vapply(requests, function(x)
    identical(x$params$outFields, "RECORD_ID,LASTUPDATE,OBJECTID"), logical(1))))
  expect_identical(tbod_provenance(result)$query$fields, c("RECORD_ID", "LASTUPDATE"))
  expect_error(tbod_get_dataset("construction-permits", fields = "made_up"), "Unknown source field")
  expect_error(tbod_get_dataset("construction-permits", fields = c("RECORD_ID", "RECORD_ID")),
               "unique source field")
  expect_error(tbod_get_dataset("construction-permits", fields = character()), "nonempty vector")
  expect_error(tbod_get_dataset("construction-permits", fields = NA_character_), "unique source field")
})

test_that("ID batching works on services without offset or ordering capability", {
  transport <- fixture_transport(metadata = fixture_metadata(pagination = FALSE, ordering = FALSE))
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  expect_identical(tbod_get_dataset("construction-permits")$OBJECTID, 1:5)
  expect_error(tbod_get_dataset("construction-permits", order_by = "LASTUPDATE DESC"),
               "reliable server-side ordering")
})

test_that("transfer-limited ID batches split until every requested record is present", {
  transport <- fixture_transport(metadata = fixture_metadata(max_records = 10L),
    transform = function(payload, params, ...) {
      if (!is.null(params$objectIds) && grepl(",", params$objectIds, fixed = TRUE)) {
        payload$features <- payload$features[1L]
        payload$exceededTransferLimit <- TRUE
      }
      payload
    })
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  result <- tbod_get_dataset("construction-permits", page_size = 4)
  expect_identical(result$OBJECTID, 1:5)
  batches <- vapply(fixture_queries(transport, "features"),
                    function(x) x$params$objectIds, character(1))
  expect_identical(batches, c("1,2,3,4", "1,2", "1", "2", "3,4", "3", "4", "5"))
  expect_true(tbod_provenance(result)$complete)
})

test_that("a truncated singleton or missing batch record cannot look complete", {
  transport <- fixture_transport(transform = function(payload, params, ...) {
    if (!is.null(params$objectIds)) payload$exceededTransferLimit <- TRUE
    payload
  })
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), "truncated a single-record batch",
               class = "tampa_integrity_error")
  missing <- fixture_transport(transform = function(payload, params, ...) {
    if (!is.null(params$objectIds)) payload$features <- payload$features[-1L]
    payload
  })
  local_mocked_bindings(arcgis_http = missing$http, .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), "missing requested records",
               class = "tampa_integrity_error")
})

test_that("unexpected and duplicate IDs in batches fail integrity checks", {
  unexpected <- fixture_transport(transform = function(payload, params, ...) {
    if (!is.null(params$objectIds)) payload$features[[1L]]$attributes$OBJECTID <- 999L
    payload
  })
  local_mocked_bindings(arcgis_http = unexpected$http, .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), "unexpected object IDs",
               class = "tampa_integrity_error")
  duplicate <- fixture_transport(transform = function(payload, params, ...) {
    if (!is.null(params$objectIds)) payload$features <- rep(payload$features[1L], 2L)
    payload
  })
  local_mocked_bindings(arcgis_http = duplicate$http, .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), "duplicate object IDs",
               class = "tampa_integrity_error")
})

test_that("counts and complete ID manifests must agree before feature retrieval", {
  disagreement <- fixture_transport(count = 6L)
  local_mocked_bindings(arcgis_http = disagreement$http, .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), "count and object-ID manifest disagree",
               class = "tampa_integrity_error")
  expect_length(fixture_queries(disagreement, "features"), 0L)
  truncated <- fixture_transport(transform = function(payload, params, ...) {
    if (identical(params$returnIdsOnly, "true")) payload$exceededTransferLimit <- TRUE
    payload
  })
  local_mocked_bindings(arcgis_http = truncated$http, .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), "complete object-ID manifest",
               class = "tampa_integrity_error")
  changed_oid <- fixture_transport(transform = function(payload, params, ...) {
    if (identical(params$returnIdsOnly, "true")) payload$objectIdFieldName <- "NEWOID"
    payload
  })
  local_mocked_bindings(arcgis_http = changed_oid$http, .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), "object-ID field changed",
               class = "tampa_integrity_error")
})

test_that("malformed counts and object-ID manifests fail explicitly", {
  for (value in list(-1L, 1.5, "five", NULL)) {
    transport <- fixture_transport(count = value)
    local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
    expect_error(tbod_get_dataset("construction-permits"), "invalid matching-record count",
                 class = "tampa_response_error")
  }
  for (ids in list(c(1, 1, 2, 3, 4), c(1, 2, 3, 4, 5.5),
                   as.character(1:5), c(1, 2, 3, 4, 1e20))) {
    transport <- fixture_transport(ids = ids)
    local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
    expect_error(tbod_get_dataset("construction-permits"), "(malformed|duplicate).*object IDs",
                 class = "tampa_integrity_error")
  }
  missing_manifest <- fixture_transport(transform = function(payload, params, ...) {
    if (identical(params$returnIdsOnly, "true")) payload$objectIds <- NULL
    payload
  })
  local_mocked_bindings(arcgis_http = missing_manifest$http, .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), "complete object-ID manifest",
               class = "tampa_integrity_error")
})

test_that("oversized manifests are rejected before attempting IDs or feature downloads", {
  transport <- fixture_transport(count = 1000001L)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), "one million.*Narrow",
               class = "tampa_integrity_error")
  expect_length(fixture_queries(transport, "ids"), 0L)
  expect_length(fixture_queries(transport, "features"), 0L)
})

test_that("empty matches and deliberate zero limits retain a typed schema", {
  empty <- fixture_transport(features = list())
  local_mocked_bindings(arcgis_http = empty$http, .package = "tampaBayOpenData")
  result <- tbod_get_dataset("construction-permits")
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_type(result$OBJECTID, "integer")
  expect_type(result$RECORD_ID, "character")
  expect_type(result$NEWCONSTRUCTIONSF, "integer")
  expect_s3_class(result$LASTUPDATE, "POSIXct")
  expect_false("SHAPE" %in% names(result))
  expect_true(tbod_provenance(result)$complete)
  expect_length(fixture_queries(empty, "features"), 0L)
  zero <- fixture_transport()
  local_mocked_bindings(arcgis_http = zero$http, .package = "tampaBayOpenData")
  result <- tbod_get_dataset("construction-permits", limit = 0)
  expect_equal(nrow(result), 0L)
  expect_false(tbod_provenance(result)$complete)
  expect_equal(tbod_provenance(result)$matched_rows, 5)
  expect_length(fixture_queries(zero, "features"), 0L)
})

test_that("ordered offsets add an OID tie breaker and honor source ordering", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  result <- tbod_get_dataset("construction-permits", order_by = "PROJECTSTATUS DESC", page_size = 2)
  expect_identical(result$OBJECTID, c(2L, 4L, 1L, 3L, 5L))
  requests <- fixture_queries(transport, "features")
  expect_identical(vapply(requests, function(x) x$params$orderByFields, character(1)),
                   rep("PROJECTSTATUS DESC,OBJECTID ASC", 3L))
  expect_equal(vapply(requests, function(x) x$params$resultOffset, numeric(1)), c(0, 2, 4))
  expect_equal(vapply(requests, function(x) x$params$resultRecordCount, numeric(1)), c(2, 2, 1))
  expect_identical(tbod_provenance(result)$pagination, "ordered offsets")
  expect_true(tbod_provenance(result)$complete)
})

test_that("an explicit OID ordering is preserved and invalid ordering is refused", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  expect_identical(tbod_get_dataset("construction-permits", order_by = "OBJECTID DESC")$OBJECTID,
                   5:1)
  requests <- fixture_queries(transport, "features")
  expect_true(all(vapply(requests, function(x) identical(x$params$orderByFields, "OBJECTID DESC"),
                        logical(1))))
  for (value in list("badfield DESC", c("OBJECTID", "OBJECTID DESC"),
                     "OBJECTID;DROP TABLE permits", NA_character_, 1)) {
    expect_error(tbod_get_dataset("construction-permits", order_by = value), "order_by")
  }
})

test_that("stalled, repeated, oversized, and unexpected ordered pages are errors", {
  transforms <- list(
    function(payload, params, ...) {
      if (!is.null(params$resultOffset) && params$resultOffset > 0) payload$features <- list()
      payload
    },
    function(payload, params, ...) {
      if (!is.null(params$resultOffset) && params$resultOffset > 0) {
        payload$features <- fixture_features(c(1L, 2L))
      }
      payload
    },
    function(payload, params, ...) {
      if (!is.null(params$resultOffset)) payload$features <- fixture_features(c(1L, 2L, 3L))
      payload
    },
    function(payload, params, ...) {
      if (!is.null(params$resultOffset)) payload$features[[1L]]$attributes$OBJECTID <- 999L
      payload
    }
  )
  for (transform in transforms) {
    transport <- fixture_transport(transform = transform)
    local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
    expect_error(tbod_get_dataset("construction-permits", order_by = "OBJECTID", page_size = 2),
                 "empty, repeated, oversized, or unexpected page", class = "tampa_integrity_error")
  }
})

test_that("ordered short pages only continue when the service declares truncation", {
  early_stop <- fixture_transport(transform = function(payload, params, ...) {
    if (!is.null(params$resultOffset)) {
      payload$features <- payload$features[1L]
      payload$exceededTransferLimit <- FALSE
    }
    payload
  })
  local_mocked_bindings(arcgis_http = early_stop$http, .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits", order_by = "OBJECTID"),
               "stopped before all requested records", class = "tampa_integrity_error")
  short_page <- fixture_transport(transform = function(payload, params, ...) {
    if (!is.null(params$resultOffset) && length(payload$features) > 1L) {
      payload$features <- payload$features[1L]
      payload$exceededTransferLimit <- TRUE
    }
    payload
  })
  local_mocked_bindings(arcgis_http = short_page$http, .package = "tampaBayOpenData")
  expect_identical(tbod_get_dataset("construction-permits", order_by = "OBJECTID")$OBJECTID, 1:5)
  expect_equal(vapply(fixture_queries(short_page, "features"),
                     function(x) x$params$resultOffset, numeric(1)), 0:4)
})

test_that("filters and advanced geometry parameters reach every stage unchanged", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  geometry <- list(xmin = -83, ymin = 27, xmax = -82, ymax = 29)
  tbod_get_dataset("construction-permits", where = "PROJECTSTATUS = 'Issued'",
    query = list(geometry = geometry, geometryType = "esriGeometryEnvelope",
                 inSR = 4326, spatialRel = "esriSpatialRelIntersects", time = "0,10000"),
    timeout = 17)
  requests <- fixture_queries(transport)
  expect_true(all(vapply(requests, function(x) identical(x$params$where,
      "PROJECTSTATUS = 'Issued'"), logical(1))))
  expect_true(all(vapply(requests, function(x) identical(x$params$inSR, "4326"), logical(1))))
  expect_true(all(vapply(requests, function(x) identical(x$params$time, "0,10000"), logical(1))))
  expect_true(all(vapply(requests, function(x) identical(x$params$geometryType,
      "esriGeometryEnvelope"), logical(1))))
  for (request in requests) {
    expect_equal(jsonlite::fromJSON(request$params$geometry), geometry)
    expect_equal(request$timeout, 17)
    expect_identical(request$params$f, "json")
  }
})

test_that("protected query arguments and invalid scalar inputs fail before HTTP", {
  called <- FALSE
  local_mocked_bindings(arcgis_http = function(...) {
    called <<- TRUE
    stop("unexpected network")
  }, .package = "tampaBayOpenData")
  for (name in c("f", "outFields", "returnGeometry", "objectIds", "resultOffset",
                 "resultRecordCount", "returnCountOnly", "outStatistics", "geometryPrecision")) {
    query <- setNames(list("override"), name)
    expect_error(tbod_get_dataset("construction-permits", query = query), "protected.*query.*parameter")
  }
  for (query in list(1, list(1), list(time = c(1, 2)), list(time = NA),
                     structure(list(1, 2), names = c("time", "time")))) {
    expect_error(tbod_get_dataset("construction-permits", query = query), "query")
  }
  for (args in list(list(where = ""), list(where = NA_character_), list(spatial = "yes"),
                    list(limit = -1), list(limit = 1.5), list(page_size = 0),
                    list(page_size = 1.2), list(timeout = 0), list(timeout = Inf),
                    list(out_sr = 4326), list(out_sr = -1, spatial = TRUE))) {
    expect_error(do.call(tbod_get_dataset, c(list(id = "construction-permits"), args)),
                 class = "tampa_data_error")
  }
  expect_false(called)
})

test_that("HTTP, network, ArcGIS, and malformed-body errors expose the source", {
  entry <- tbod_dataset_info("construction-permits")
  local_mocked_bindings(arcgis_http = function(...) fixture_response(list(), 404L),
                        .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), "endpoint_disappeared",
               class = "tampa_schema_error")
  error <- tryCatch(tbod_get_dataset("construction-permits"), error = identity)
  expect_identical(error$dataset_id, entry$id)
  expect_match(conditionMessage(error), entry$source_url, fixed = TRUE)
  local_mocked_bindings(arcgis_http = function(...) stop("connection refused"),
                        .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), "could not be reached.*connection refused",
               class = "tampa_http_error")
  local_mocked_bindings(arcgis_http = function(...) fixture_response(
    list(error = list(code = 400L, message = "Invalid SQL", details = list("Unknown field")))),
    .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), "ArcGIS error 400.*Invalid SQL.*Unknown field",
               class = "tampa_arcgis_error")
  for (body in c("<html>Outside the United States</html>", "not JSON", "[]", "null", "42")) {
    local_mocked_bindings(arcgis_http = function(...) list(status = 200L, body = body),
                          .package = "tampaBayOpenData")
    expect_error(tbod_get_dataset("construction-permits"), class = "tampa_response_error")
  }
  local_mocked_bindings(arcgis_http = function(...) fixture_response(list(error = "broken")),
                        .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), class = "tampa_response_error")
})

test_that("layer metadata must provide a schema, an OID, and a usable record cap", {
  invalid <- list(
    list(),
    within(fixture_metadata(), fields <- list(list(name = "x"))),
    within(fixture_metadata(), fields <- c(fields, fields[1L])),
    within(fixture_metadata(), objectIdField <- "NO_SUCH_FIELD"),
    within(fixture_metadata(), maxRecordCount <- NULL),
    within(fixture_metadata(), maxRecordCount <- 0),
    within(fixture_metadata(), maxRecordCount <- 1.5),
    within(fixture_metadata(), capabilities <- "Map")
  )
  for (metadata in invalid) {
    transport <- fixture_transport(metadata = metadata)
    local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
    expect_error(tbod_get_dataset("construction-permits"), class = "tampa_data_error")
  }
  metadata <- fixture_metadata()
  metadata$objectIdField <- NULL
  transport <- fixture_transport(metadata = metadata)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  expect_identical(tbod_get_dataset("construction-permits")$OBJECTID, 1:5)
})

test_that("malformed feature arrays or absent IDs are never silently dropped", {
  transforms <- list(
    function(payload, params, ...) {
      if (!is.null(params$objectIds)) payload$features <- NULL
      payload
    },
    function(payload, params, ...) {
      if (!is.null(params$objectIds)) names(payload$features) <- paste0("row", seq_along(payload$features))
      payload
    },
    function(payload, params, ...) {
      if (!is.null(params$objectIds)) payload$features[[1L]]$attributes <- NULL
      payload
    },
    function(payload, params, ...) {
      if (!is.null(params$objectIds)) payload$features[[1L]]$attributes$OBJECTID <- NULL
      payload
    }
  )
  for (transform in transforms) {
    transport <- fixture_transport(transform = transform)
    local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
    expect_error(tbod_get_dataset("construction-permits"), class = "tampa_response_error")
  }
  null_oid <- fixture_transport(transform = function(payload, params, ...) {
    if (!is.null(params$objectIds)) payload$features[[1L]]$attributes["OBJECTID"] <- list(NULL)
    payload
  })
  local_mocked_bindings(arcgis_http = null_oid$http, .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits"), "null object ID",
               class = "tampa_integrity_error")
})

test_that("malformed per-page flags, geometry types, and spatial references fail clearly", {
  transforms <- list(
    function(payload, params, ...) {
      if (!is.null(params$objectIds)) payload$exceededTransferLimit <- "true"
      payload
    },
    function(payload, params, ...) {
      if (!is.null(params$objectIds)) payload$geometryType <- "esriGeometryPolygon"
      payload
    },
    function(payload, params, ...) {
      if (!is.null(params$objectIds)) payload$spatialReference <- "EPSG:3857"
      payload
    }
  )
  for (transform in transforms) {
    transport <- fixture_transport(transform = transform)
    local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
    expect_error(tbod_get_dataset("construction-permits"), class = "tampa_response_error")
  }
})

test_that("spatial pages cannot change CRS or contradict a requested projection", {
  skip_if_not_installed("sf")
  changed <- fixture_transport(transform = function(payload, params, ...) {
    if (!is.null(params$objectIds) && identical(params$objectIds, "3,4")) {
      payload$spatialReference <- list(wkid = 4326)
    }
    payload
  })
  local_mocked_bindings(arcgis_http = changed$http, .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits", spatial = TRUE), "CRS changed between pages",
               class = "tampa_integrity_error")
  wrong_projection <- fixture_transport(transform = function(payload, params, ...) {
    if (!is.null(params$objectIds)) payload$spatialReference <- list(wkid = 3857)
    payload
  })
  local_mocked_bindings(arcgis_http = wrong_projection$http, .package = "tampaBayOpenData")
  expect_error(tbod_get_dataset("construction-permits", spatial = TRUE, out_sr = 4326),
               "projection|spatial reference|CRS", class = "tampa_spatial_error")
})

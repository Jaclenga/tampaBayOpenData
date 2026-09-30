test_that("declared source types preserve strings and produce typed missing values", {
  features <- fixture_features(1:3)
  features[[1L]]$attributes$RECORD_ID <- ""
  features[[1L]]$attributes$PROJECTSTATUS <- " source spelling "
  features[[2L]]$attributes$RECORD_ID <- NULL
  features[[2L]]$attributes["NEWCONSTRUCTIONSF"] <- list(NULL)
  features[[2L]]$attributes$COST <- NULL
  features[[3L]]$attributes$LASTUPDATE <- NULL
  transport <- fixture_transport(features = features)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  result <- get_dataset("construction-permits")
  expect_identical(result$RECORD_ID, c("", NA_character_, "synthetic-3"))
  expect_identical(result$PROJECTSTATUS[1L], " source spelling ")
  expect_identical(result$NEWCONSTRUCTIONSF, c(101L, NA_integer_, 103L))
  expect_identical(result$COST, c(10.5, NA_real_, 31.5))
  expect_identical(result$GlobalID, paste0("synthetic-guid-", 1:3))
  expect_identical(result$TENTATIVEHEARING, rep("09/29/2026", 3L))
  expect_s3_class(result$CREATEDDATE, "POSIXct")
  expect_true(all(is.na(result$CREATEDDATE)))
  expect_true(is.na(result$LASTUPDATE[3L]))
})

test_that("epoch milliseconds become UTC instants without a second local-zone shift", {
  features <- fixture_features(1:3)
  epochs <- c(0, 1559016000000, -1500)
  for (i in seq_along(features)) features[[i]]$attributes$LASTUPDATE <- epochs[i]
  transport <- fixture_transport(features = features)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  result <- get_dataset("construction-permits", fields = "LASTUPDATE")
  expect_identical(attr(result$LASTUPDATE, "tzone"), "UTC")
  expect_equal(as.numeric(result$LASTUPDATE), epochs / 1000)
  expect_identical(format(result$LASTUPDATE[2L], tz = "UTC", usetz = FALSE),
                   "2019-05-28 04:00:00")
  expect_identical(dataset_provenance(result)$date_fields_time_reference$timeZoneIANA,
                   "America/New_York")
})

test_that("unknown date zones remain raw with one clear warning", {
  for (metadata in list(
    within(fixture_metadata(), datesInUnknownTimezone <- TRUE),
    within(fixture_metadata(), dateFieldsTimeReference <- list(timeZone = "Unknown")),
    within(fixture_metadata(), dateFieldsTimeReference <- list(timeZone = "unspecified")))) {
    transport <- fixture_transport(metadata = metadata)
    local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
    expect_warning(result <- get_dataset("construction-permits",
      fields = c("LASTUPDATE", "CREATEDDATE", "TENTATIVEHEARING")),
      "unknown date time zone.*raw epoch milliseconds")
    expect_type(result$LASTUPDATE, "double")
    expect_identical(result$LASTUPDATE, as.numeric(1:5) * 1000)
    expect_identical(result$CREATEDDATE, rep(NA_real_, 5L))
    expect_identical(result$TENTATIVEHEARING, rep("09/29/2026", 5L))
    expect_true(dataset_provenance(result)$dates_in_unknown_timezone)
  }
  metadata <- fixture_metadata()
  metadata$datesInUnknownTimezone <- TRUE
  transport <- fixture_transport(metadata = metadata)
  local_mocked_bindings(arcgis_http = transport$http, .package = "tampaBayOpenData")
  expect_no_warning(get_dataset("construction-permits", fields = "RECORD_ID"))
})

test_that("editor tracking dates stay UTC when other date zones are unknown", {
  features <- fixture_features(1:2)
  features[[1L]]$attributes$CREATEDDATE <- 0
  features[[1L]]$attributes$EDITDATE <- 1559016000000
  features[[2L]]$attributes$EDITDATE <- -1500

  for (zone_source in c("flag", "reference")) {
    metadata <- fixture_metadata()
    if (zone_source == "flag") {
      metadata$datesInUnknownTimezone <- TRUE
    } else {
      metadata$dateFieldsTimeReference <- list(timeZone = "Unknown")
    }
    metadata$editFieldsInfo <- list(creationDateField = "CREATEDDATE",
                                    editDateField = "EDITDATE")
    metadata$fields[[length(metadata$fields) + 1L]] <-
      fixture_field("EDITDATE", "esriFieldTypeDate")

    expect_warning(result <- arcgis_parse(features, metadata,
      c("LASTUPDATE", "CREATEDDATE", "EDITDATE")),
      "unknown date time zone.*raw epoch milliseconds")
    expect_identical(result$LASTUPDATE, c(1000, 2000))
    expect_s3_class(result$CREATEDDATE, "POSIXct")
    expect_s3_class(result$EDITDATE, "POSIXct")
    expect_identical(attr(result$CREATEDDATE, "tzone"), "UTC")
    expect_identical(attr(result$EDITDATE, "tzone"), "UTC")
    expect_equal(as.numeric(result$CREATEDDATE), c(0, NA_real_))
    expect_equal(as.numeric(result$EDITDATE), c(1559016000, -1.5))
    expect_no_warning(arcgis_parse(features, metadata, c("CREATEDDATE", "EDITDATE")))

    metadata$editFieldsInfo <- NULL
    expect_warning(raw <- arcgis_parse(features, metadata, "EDITDATE"),
                   "unknown date time zone.*raw epoch milliseconds")
    expect_identical(raw$EDITDATE, c(1559016000000, -1500))

    metadata$editFieldsInfo <- list(editDateFieldExtra = "EDITDATE")
    expect_warning(raw <- arcgis_parse(features, metadata, "EDITDATE"),
                   "unknown date time zone.*raw epoch milliseconds")
    expect_identical(raw$EDITDATE, c(1559016000000, -1500))

    metadata$editFieldsInfo <- "malformed"
    expect_warning(raw <- arcgis_parse(features, metadata, "EDITDATE"),
                   "unknown date time zone.*raw epoch milliseconds")
    expect_identical(raw$EDITDATE, c(1559016000000, -1500))
  }
})

test_that("attribute parsing uses the exact attributes key", {
  feature <- list(attributesExtra = list(LASTUPDATE = 1704067200000))
  parsed <- arcgis_parse(list(feature), fixture_metadata(), "LASTUPDATE")
  expect_s3_class(parsed$LASTUPDATE, "POSIXct")
  expect_true(is.na(parsed$LASTUPDATE[[1L]]))
})

test_that("integer overflow is handled without losing exact source values", {
  metadata <- fixture_metadata()
  features <- fixture_features(1:2)
  features[[1L]]$attributes$NEWCONSTRUCTIONSF <- 2147483648
  features[[2L]]$attributes$NEWCONSTRUCTIONSF <- -2147483648
  result <- arcgis_parse(features, metadata, "NEWCONSTRUCTIONSF")
  expect_type(result$NEWCONSTRUCTIONSF, "double")
  expect_identical(result$NEWCONSTRUCTIONSF, c(2147483648, -2147483648))
  features[[1L]]$attributes$NEWCONSTRUCTIONSF <- 1.5
  expect_error(arcgis_parse(features, metadata, "NEWCONSTRUCTIONSF"), "fractional integers")
  features[[1L]]$attributes$NEWCONSTRUCTIONSF <- 2^53
  expect_error(arcgis_parse(features, metadata, "NEWCONSTRUCTIONSF"), "integer precision")
})

test_that("schema violations fail instead of silently coercing attributes", {
  metadata <- fixture_metadata()
  for (case in list(
    list(field = "RECORD_ID", value = 10),
    list(field = "COST", value = "10.50"),
    list(field = "LASTUPDATE", value = "2026-09-29"),
    list(field = "PROJECTSTATUS", value = list("Issued", "Review")),
    list(field = "NEWCONSTRUCTIONSF", value = c(1L, 2L)))) {
    features <- fixture_features(1L)
    features[[1L]]$attributes[[case$field]] <- case$value
    expect_error(arcgis_parse(features, metadata, case$field),
                 "declared|nonscalar", class = "tampa_response_error")
  }
  features <- fixture_features(1L)
  features[[1L]]$attributes$COST <- Inf
  expect_error(arcgis_parse(features, metadata, "COST"), "nonfinite")
})

test_that("newer ArcGIS date and integer types retain their intended representations", {
  metadata <- list(fields = list(
    fixture_field("large", "esriFieldTypeBigInteger"),
    fixture_field("day", "esriFieldTypeDateOnly"),
    fixture_field("clock", "esriFieldTypeTimeOnly"),
    fixture_field("offset", "esriFieldTypeTimestampOffset"),
    fixture_field("guid", "esriFieldTypeGUID")
  ))
  features <- list(
    list(attributes = list(large = "9007199254740993", day = "2026-09-29",
      clock = "12:34:56.789", offset = "2026-09-29T12:34:56-04:00", guid = "{KEEP-CASE}")),
    list(attributes = list(large = -12345, day = NULL, clock = NULL, offset = NULL, guid = NULL))
  )
  result <- arcgis_parse(features, metadata, .field_names(metadata))
  expect_identical(result$large, c("9007199254740993", "-12345"))
  expect_identical(result$day, as.Date(c("2026-09-29", NA)))
  expect_identical(result$clock, c("12:34:56.789", NA_character_))
  expect_identical(result$offset, c("2026-09-29T12:34:56-04:00", NA_character_))
  expect_identical(result$guid, c("{KEEP-CASE}", NA_character_))
  features[[1L]]$attributes$large <- 2^53
  expect_error(arcgis_parse(features, metadata, "large"), "numeric precision")
  features[[1L]]$attributes$large <- "123.5"
  expect_error(arcgis_parse(features, metadata, "large"), "Invalid big-integer")
  for (day in c("2026-02-31", "2026-09-29extra", "09/29/2026")) {
    features[[1L]]$attributes$day <- day
    expect_error(arcgis_parse(features, metadata, "day"), "Invalid date-only")
  }
})

test_that("binary attributes and unfamiliar scalar types survive as list columns", {
  metadata <- list(fields = list(fixture_field("payload", "esriFieldTypeBlob"),
                                 fixture_field("other", "futureArcGISType")))
  features <- list(list(attributes = list(payload = list(1L, 2L), other = "untouched")),
                   list(attributes = list(payload = NULL, other = 12)))
  result <- arcgis_parse(features, metadata, .field_names(metadata))
  expect_identical(result$payload, list(list(1L, 2L), NULL))
  expect_identical(result$other, list("untouched", 12))
  empty <- arcgis_parse(list(), metadata, .field_names(metadata))
  expect_equal(nrow(empty), 0L)
  expect_type(empty$payload, "list")
  expect_type(empty$other, "list")
})

test_that("malformed timezone and capability metadata cannot change parsing silently", {
  changes <- list(
    function(metadata) {
      metadata$datesInUnknownTimezone <- "true"
      metadata
    },
    function(metadata) {
      metadata$datesInUnknownTimezone <- list(TRUE, FALSE)
      metadata
    },
    function(metadata) {
      metadata$capabilities <- list("Map", "Query")
      metadata
    },
    function(metadata) {
      metadata$capabilities <- 42
      metadata
    },
    function(metadata) {
      metadata$dateFieldsTimeReference$timeZone <- list("Unknown", "UTC")
      metadata
    }
  )
  for (change in changes) {
    transport <- fixture_transport(metadata = change(fixture_metadata()))
    local_mocked_bindings(arcgis_http = transport$http,
                          .package = "tampaBayOpenData")
    failure <- tryCatch(get_dataset("construction-permits"), error = identity)
    expect_s3_class(failure, "tampa_response_error")
    if (inherits(failure, "error")) {
      expect_identical(failure$dataset_id, "construction-permits")
      expect_match(conditionMessage(failure), "metadata|time zone")
      expect_match(conditionMessage(failure),
                    dataset_info("construction-permits")$source_url, fixed = TRUE)
    }
    expect_length(fixture_queries(transport), 0L)
  }
})

test_that("a missing optional spatial dependency fails before contacting a source", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_has_sf = function() FALSE,
                        arcgis_http = transport$http,
                        .package = "tampaBayOpenData")
  expect_error(get_dataset("construction-permits", spatial = TRUE),
               "requires the sf package.*install.packages", class = "tampa_data_error")
  expect_length(transport$state$requests, 0L)
  attributes <- get_dataset("construction-permits", fields = "RECORD_ID")
  expect_s3_class(attributes, "tbl_df")
  expect_identical(attributes$RECORD_ID, paste0("synthetic-", 1:5))
})

test_that("the ordinary suite blocks an unmocked live request immediately", {
  skip_if(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
          "The explicitly enabled live suite uses the real HTTP transport")
  # The reserved invalid domain is never resolved: setup-offline blocks dispatch.
  expect_error(arcgis_http("https://offline-tests.invalid/FeatureServer/0",
                           list(f = "json"), timeout = 1),
               "Live HTTP is disabled in the offline test suite")
})

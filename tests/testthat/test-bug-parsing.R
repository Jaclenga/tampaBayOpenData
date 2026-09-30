bug_with_digits <- function(digits, code) {
  previous <- options(digits = digits)
  on.exit(options(previous), add = TRUE)
  force(code)
}

test_that("numeric big integers cannot be rounded into valid-looking integers", {
  metadata <- list(fields = list(fixture_field("VALUE", "esriFieldTypeBigInteger")))
  fractions <- c(123456789.5, 1.0000001, -123456789.5, -1.0000001)
  for (digits in c(1L, 7L, 15L)) {
    bug_with_digits(digits, {
      for (value in fractions) {
        features <- list(list(attributes = list(VALUE = value)))
        expect_error(arcgis_parse(features, metadata, "VALUE"),
                     "Invalid big-integer", class = "tampa_data_error")
      }
    })
  }
})

test_that("exact big integers are independent of the user's display precision", {
  metadata <- list(fields = list(fixture_field("VALUE", "esriFieldTypeBigInteger")))
  values <- list(0, -12345, 1234567890123456, 9007199254740991,
                 -9007199254740991, "9007199254740993", "-9007199254740993",
                 "000123", NULL)
  features <- lapply(values, function(value) list(attributes = list(VALUE = value)))
  expected <- c("0", "-12345", "1234567890123456", "9007199254740991",
                "-9007199254740991", "9007199254740993", "-9007199254740993",
                "000123", NA_character_)
  for (digits in c(1L, 7L, 15L)) {
    bug_with_digits(digits, {
      expect_identical(arcgis_parse(features, metadata, "VALUE")$VALUE, expected)
    })
  }
})

test_that("invalid numeric big integers raise package errors consistently", {
  metadata <- list(fields = list(fixture_field("VALUE", "esriFieldTypeBigInteger")))
  for (value in list(NA_real_, NaN, Inf, -Inf)) {
    features <- list(list(attributes = list(VALUE = value)))
    expect_error(arcgis_parse(features, metadata, "VALUE"),
                 class = "tampa_data_error")
  }
  for (value in c(2^53, -2^53)) {
    features <- list(list(attributes = list(VALUE = value)))
    expect_error(arcgis_parse(features, metadata, "VALUE"),
                 "exact JSON/R numeric precision", class = "tampa_data_error")
  }
})

test_that("malformed field aliases fail metadata inspection with source context", {
  entry <- dataset_info("construction-permits")
  endpoint <- paste0(entry$service_url, "/", entry$layer_id)
  for (alias in list(42, c("one", "two"), list("one"), list("one", "two"),
                     NA_character_, NA_real_)) {
    metadata <- fixture_metadata()
    metadata$fields[[2L]]$alias <- alias
    # Preserve malformed NA values here; JSON null is a valid absent alias.
    local_mocked_bindings(arcgis_request = function(...) metadata,
                          .package = "tampaBayOpenData")
    failure <- tryCatch(dataset_info(entry$id, refresh = TRUE), error = identity)
    expect_s3_class(failure, "tampa_response_error")
    if (inherits(failure, "error")) {
      expect_identical(failure$dataset_id, entry$id)
      expect_match(conditionMessage(failure), "field schema|alias")
      expect_match(conditionMessage(failure), entry$source_url, fixed = TRUE)
      expect_match(conditionMessage(failure), endpoint, fixed = TRUE)
    }
  }
})

test_that("metadata inspection preserves valid aliases and absent-alias fallback", {
  for (kind in c("valid", "missing", "null")) {
    metadata <- fixture_metadata()
    if (kind == "valid") metadata$fields[[2L]]$alias <- "Source Alias"
    if (kind == "missing") metadata$fields[[2L]]$alias <- NULL
    if (kind == "null") metadata$fields[[2L]]["alias"] <- list(NULL)
    transport <- fixture_transport(metadata = metadata)
    local_mocked_bindings(arcgis_http = transport$http,
                          .package = "tampaBayOpenData")
    inspected <- dataset_info("construction-permits", refresh = TRUE)
    expected <- if (kind == "valid") "Source Alias" else "RECORD_ID"
    expect_identical(inspected$fields$alias[2L], expected)
    expect_identical(inspected$fields$name[2L], "RECORD_ID")
    expect_length(transport$state$requests, 1L)
  }
})

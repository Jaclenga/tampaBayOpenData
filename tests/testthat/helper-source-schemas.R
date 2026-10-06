source_schema_fixtures <- function() {
  tampa <- jsonlite::fromJSON(test_path("fixtures", "tampa-layer-schemas.json"),
                              simplifyVector = FALSE)
  c(tampa, regional_source_cases(), curated_addition_cases())
}

curated_addition_cases <- function() {
  jsonlite::fromJSON(
    test_path("fixtures", "curated-additions-layer-schemas.json"),
    simplifyVector = FALSE
  )
}

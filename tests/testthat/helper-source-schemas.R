source_schema_fixtures <- function() {
  tampa <- jsonlite::fromJSON(test_path("fixtures", "tampa-layer-schemas.json"),
                              simplifyVector = FALSE)
  c(tampa, regional_source_cases())
}

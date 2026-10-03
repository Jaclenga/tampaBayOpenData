# Verified source schemas are shared by offline and opt-in live tests.
# Every offline record and coordinate below is synthetic.
other_city_cases <- function() {
  jsonlite::fromJSON(test_path("fixtures", "tampa-bay-city-layer-schemas.json"),
                     simplifyVector = FALSE)
}

other_city_fields <- function(case) {
  c(case$object_id_field, case$label_field, case$integer_field,
    case$double_field, case$date_field)
}

other_city_features <- function(case) {
  lapply(c(8L, 2L, 14L), function(id) {
    attributes <- list()
    attributes[[case$object_id_field]] <- id
    attributes[[case$label_field]] <- paste0("synthetic-", id, " O'Brien & \u00e9")
    attributes[case$integer_field] <- list(if (id == 8L) NULL else 33000L + id)
    if (!is.null(case$double_field)) {
      attributes[case$double_field] <- list(if (id == 8L) NULL else id / 4)
    }
    attributes[case$date_field] <- list(if (id == 8L) NULL else
      1704067200000 + as.numeric(id) * 86400000)
    geometry <- if (id == 2L) NULL else if (
      case$metadata$geometryType == "esriGeometryPoint") {
      list(x = 430000 + id, y = 1280000 + id)
    } else {
      list(rings = list(list(c(430000, 1280000), c(430000, 1280020),
                              c(430020, 1280020), c(430020, 1280000),
                              c(430000, 1280000))))
    }
    list(attributes = attributes, geometry = geometry)
  })
}

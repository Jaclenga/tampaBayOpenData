regional_source_cases <- function() {
  jsonlite::fromJSON(test_path("fixtures", "regional-layer-schemas.json"),
                     simplifyVector = FALSE)
}

regional_source_features <- function(case) {
  ids <- c(14L, 2L, 8L)
  schema <- case$metadata$fields
  origin <- if (case$native_epsg == 2882) c(430000, 1280000) else c(-9180000, 3240000)
  lapply(seq_along(ids), function(i) {
    attributes <- lapply(case$fields, function(name) {
      field <- schema[[match(name, vapply(schema, `[[`, character(1), "name"))]]
      if (field$type == "esriFieldTypeOID") return(ids[[i]])
      if (i == 2L && !identical(name, case$label_field)) return(NULL)
      if (field$type == "esriFieldTypeDate") return(1704153600000 + i * 86400000)
      if (field$type %in% c("esriFieldTypeInteger", "esriFieldTypeSmallInteger")) return(i + 3L)
      if (field$type %in% c("esriFieldTypeDouble", "esriFieldTypeSingle")) return(i + 0.5)
      paste0("synthetic-", ids[[i]], " O'Brien & \u00e9")
    })
    names(attributes) <- unlist(case$fields, use.names = FALSE)
    xy <- origin + i * 20
    geometry <- if (i == 2L) NULL else switch(case$metadata$geometryType,
      esriGeometryPoint = list(x = xy[[1L]], y = xy[[2L]]),
      esriGeometryPolyline = list(paths = list(list(xy, xy + c(10, 10)))),
      esriGeometryPolygon = list(rings = list(list(
        xy, xy + c(0, 10), xy + c(10, 10), xy + c(10, 0), xy)))
    )
    list(attributes = attributes, geometry = geometry)
  })
}

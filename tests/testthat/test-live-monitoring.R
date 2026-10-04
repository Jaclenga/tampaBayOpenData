# Scheduled smoke checks use the public API and fetch at most two rows per call.
# Ordinary tests and package checks skip before any metadata or network access.
test_that("live monitoring samples every checked publisher's source identity and geometry", {
  skip_if_not(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
              "Set TAMPA_OPEN_DATA_LIVE=true to opt into scheduled source checks")
  skip_if_not_installed("sf")
  checked <- list_datasets(source = "checked", jurisdiction = "all")
  expect_setequal(checked$jurisdiction,
                  c("tampa", "stpete", "clearwater", "hillsborough", "pinellas", "tampa-bay"))
  selected <- list(
    "construction-permits" = c("OBJECTID", "RECORD_ID", "PROJECTSTATUS", "LASTUPDATE"),
    "stpete-parks" = c("OBJECTID", "NAME"),
    "clearwater-libraries" = c("OBJECTID", "NAME", "FACILITYID")
  )
  for (id in checked$id) {
    entry <- dataset_info(id, jurisdiction = "all")
    fields <- selected[[id]] %||% entry$object_id_field
    data <- get_dataset(id, jurisdiction = "all", fields = fields,
                        spatial = TRUE, out_sr = 4326, limit = 2, page_size = 1,
                        timeout = 15, total_timeout = 45)
    source <- dataset_provenance(data)
    expect_s3_class(data, "sf")
    expect_identical(names(sf::st_drop_geometry(data)), fields, info = id)
    expect_gt(nrow(data), 0L)
    expect_lte(nrow(data), 2L)
    expect_equal(anyDuplicated(data[[entry$object_id_field]]), 0L, info = id)
    expect_equal(sf::st_crs(data)$epsg, 4326, info = id)
    pattern <- switch(entry$geometry_type,
      esriGeometryPoint = "^POINT$", esriGeometryMultipoint = "^MULTIPOINT$",
      esriGeometryPolyline = "^(LINESTRING|MULTILINESTRING)$",
      esriGeometryPolygon = "^(POLYGON|MULTIPOLYGON)$")
    expect_true(all(sf::st_is_empty(data) |
      grepl(pattern, as.character(sf::st_geometry_type(data)))), info = id)
    expect_identical(source$dataset_id, id)
    expect_identical(source$validation_status, "checked")
    expect_identical(source$publisher, entry$publisher)
    expect_identical(source$jurisdiction, entry$jurisdiction)
    expect_identical(source$source_url, entry$source_url)
    expect_equal(source$returned_rows, nrow(data))
    expect_gte(source$matched_rows, nrow(data))
    expect_identical(source$complete, source$matched_rows == nrow(data))
    if (id == "construction-permits") {
      expect_type(data$RECORD_ID, "character")
      expect_type(data$PROJECTSTATUS, "character")
      expect_s3_class(data$LASTUPDATE, "POSIXct")
      expect_identical(attr(data$LASTUPDATE, "tzone"), "UTC")
    } else if (id %in% c("stpete-parks", "clearwater-libraries")) {
      expect_type(data$NAME, "character")
    }
  }
})

test_that("live monitoring checks bounded portal discovery and regional retrieval", {
  skip_if_not(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
              "Set TAMPA_OPEN_DATA_LIVE=true to opt into scheduled portal checks")
  for (portal in list_portals()$id) {
    found <- list_datasets(source = "live", portals = portal, max_items = 1,
                          timeout = 15, total_timeout = 45)
    expect_s3_class(found, "tbl_df")
    expect_length(attr(found, "discovery_failed_portals"), 0L)
    expect_lte(sum(attr(found, "discovery_scanned_items")), 1)
    if (portal == "tbrpc") {
      expect_gt(nrow(found), 0L)
      descriptor <- found[1, , drop = FALSE]
      info <- dataset_info(descriptor, refresh = TRUE, timeout = 15,
                           total_timeout = 45)
      oid <- info$metadata$objectIdField
      data <- get_dataset(descriptor, fields = oid, limit = 2, page_size = 1,
                          timeout = 15, total_timeout = 45)
      source <- dataset_provenance(data)
      expect_s3_class(data, "tbl_df")
      expect_identical(names(data), oid)
      expect_lte(nrow(data), 2L)
      expect_equal(anyDuplicated(data[[oid]]), 0L)
      expect_identical(source$publisher, "Tampa Bay Regional Planning Council")
      expect_identical(source$jurisdiction, "tampa-bay")
      expect_identical(source$source_url, descriptor$source_url[[1L]])
      expect_equal(source$returned_rows, nrow(data))
      expect_gte(source$matched_rows, nrow(data))
      expect_identical(source$complete, source$matched_rows == nrow(data))
    }
  }
})

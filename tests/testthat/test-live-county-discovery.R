# These public facility queries were verified against the official county
# organizations. Item IDs, counts and records remain live, not fixture values.
for (case in list(
  list(portal = "hillsborough", query = "Public Libraries"),
  list(portal = "pinellas", query = "PSSFireStation")
)) {
  local({
    county <- case
    test_that(paste(county$portal, "live discovery retrieves bounded county data"), {
      skip_if_not(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
                  "Set TAMPA_OPEN_DATA_LIVE=true to opt into county ArcGIS calls")
      config <- .portal_registry()[[county$portal]]
      found <- search_datasets(county$query, jurisdiction = config$jurisdiction,
        source = "live", portals = county$portal, max_items = 1,
        timeout = 15, total_timeout = 45)
      expect_gt(nrow(found), 0L)
      expect_identical(attr(found, "discovery_scanned_items"),
                       setNames(1L, county$portal))
      expect_length(attr(found, "discovery_issues"), 0L)
      expect_identical(unique(found$publisher), config$publisher)
      expect_identical(unique(found$jurisdiction), config$jurisdiction)
      expect_true(all(found$validation_status == "discovered"))
      row <- found[1L, ]
      expect_match(row$id, "^arcgis:[[:xdigit:]]{32}:[0-9]+$")
      modified_day <- as.Date(row$modified, tz = "UTC")
      expect_false(is.na(modified_day))
      tags <- row$tags[[1L]]
      tags <- tags[!is.na(tags) & nzchar(trimws(tags))]
      categories <- row$categories[[1L]]
      categories <- categories[!is.na(categories) & nzchar(trimws(categories))]
      filtered <- search_datasets(county$query, jurisdiction = config$jurisdiction,
        source = "live", portals = county$portal, publisher = config$publisher,
        validation_status = "discovered", spatial = TRUE,
        modified_after = modified_day, modified_before = modified_day,
        topic = if (length(tags)) tags[[1L]] else NULL,
        category = if (length(categories)) categories[[1L]] else NULL,
        max_items = 1, timeout = 15, total_timeout = 45)
      expect_true(row$source_url %in% filtered$source_url)
      expect_true(all(filtered$modified_source == "portal_item"))
      expect_identical(attr(filtered, "discovery_scanned_items"),
                       setNames(1L, county$portal))
      expect_true(all(!is.na(filtered$geometry_type) &
                        filtered$geometry_type != "none"))
      info <- dataset_info(row, refresh = TRUE, timeout = 15, total_timeout = 45)
      oid <- info$metadata$objectIdField
      expect_true(is.character(oid) && length(oid) == 1L && nzchar(oid))
      descriptor <- get_dataset(row, fields = oid, limit = 2, page_size = 1,
                                timeout = 15, total_timeout = 45)
      stable <- get_dataset(row$id, fields = oid, limit = 2, page_size = 1,
                            timeout = 15, total_timeout = 45)
      expect_s3_class(descriptor, "tbl_df")
      expect_identical(names(descriptor), oid)
      expect_gt(nrow(descriptor), 0L)
      expect_lte(nrow(descriptor), 2L)
      expect_false(anyNA(descriptor[[oid]]))
      expect_identical(anyDuplicated(descriptor[[oid]]), 0L)
      expect_identical(stable[[oid]], descriptor[[oid]])
      for (result in list(descriptor, stable)) {
        source <- dataset_provenance(result)
        expect_identical(source$publisher, config$publisher)
        expect_identical(source$jurisdiction, config$jurisdiction)
        expect_identical(source$validation_status, "discovered")
        expect_identical(source$source_url, row$source_url)
        expect_identical(source$returned_rows, nrow(result))
        expect_gte(source$matched_rows, nrow(result))
        expect_identical(source$complete, source$matched_rows == source$returned_rows)
      }
    })

    test_that(paste(county$portal, "live discovered facilities retain projected geometry"), {
      skip_if_not(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
                  "Set TAMPA_OPEN_DATA_LIVE=true to opt into county ArcGIS calls")
      skip_if_not_installed("sf")
      config <- .portal_registry()[[county$portal]]
      found <- search_datasets(county$query, jurisdiction = config$jurisdiction,
        source = "live", portals = county$portal, max_items = 1,
        timeout = 15, total_timeout = 45)
      expect_gt(nrow(found), 0L)
      row <- found[1L, ]
      info <- dataset_info(row, refresh = TRUE, timeout = 15, total_timeout = 45)
      oid <- info$metadata$objectIdField
      spatial <- get_dataset(row$id, fields = oid, spatial = TRUE, out_sr = 4326,
        limit = 2, page_size = 1, timeout = 15, total_timeout = 45)
      expect_s3_class(spatial, "sf")
      expect_identical(names(sf::st_drop_geometry(spatial)), oid)
      expect_gt(nrow(spatial), 0L)
      expect_lte(nrow(spatial), 2L)
      expect_identical(sf::st_crs(spatial)$epsg, 4326L)
      expect_true(all(as.character(sf::st_geometry_type(spatial)) == "POINT"))
      expect_false(any(sf::st_is_empty(spatial)))
      expect_true(all(is.finite(sf::st_coordinates(spatial))))
      expect_identical(anyDuplicated(spatial[[oid]]), 0L)
      source <- dataset_provenance(spatial)
      expect_identical(source$publisher, config$publisher)
      expect_identical(source$jurisdiction, config$jurisdiction)
      expect_identical(source$validation_status, "discovered")
      expect_identical(source$source_url, row$source_url)
      expect_identical(source$query$out_sr, 4326)
      expect_identical(source$returned_rows, nrow(spatial))
      expect_identical(source$complete, source$matched_rows == source$returned_rows)
    })
  })
}

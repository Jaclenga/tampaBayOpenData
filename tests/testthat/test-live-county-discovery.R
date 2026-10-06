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
      found <- tbod_search_datasets(county$query, jurisdiction = config$jurisdiction,
        source = "live", portals = county$portal, max_items = 1,
        timeout = 15, total_timeout = 45)
      expect_gt(nrow(found), 0L)
      expect_identical(attr(found, "discovery_scanned_items"),
                       setNames(1L, county$portal))
      expect_length(attr(found, "discovery_issues"), 0L)
      expect_identical(unique(found$publisher), config$publisher)
      expect_identical(unique(found$jurisdiction), config$jurisdiction)
      expect_true(all(found$validation_status %in% c("checked", "discovered")))
      row <- found[1L, ]
      checked <- tbod_list_datasets(jurisdiction = config$jurisdiction,
                               source = "checked")
      matching <- checked[
        tolower(sub("/+$", "", checked$service_url)) ==
          tolower(sub("/+$", "", row$service_url[[1L]])) &
          checked$layer_id == row$layer_id[[1L]], , drop = FALSE]
      expect_lte(nrow(matching), 1L)
      if (nrow(matching)) {
        expect_identical(row$validation_status[[1L]], "checked")
        expect_identical(row$id[[1L]], matching$id[[1L]])
      } else {
        expect_identical(row$validation_status[[1L]], "discovered")
        expect_match(row$id, "^arcgis:[[:xdigit:]]{32}:[0-9]+$")
      }
      modified_day <- as.Date(row$modified, tz = "UTC")
      expect_false(is.na(modified_day))
      tags <- row$tags[[1L]]
      tags <- tags[!is.na(tags) & nzchar(trimws(tags))]
      categories <- row$categories[[1L]]
      categories <- categories[!is.na(categories) & nzchar(trimws(categories))]
      filtered <- tbod_search_datasets(county$query, jurisdiction = config$jurisdiction,
        source = "live", portals = county$portal, publisher = config$publisher,
        validation_status = row$validation_status[[1L]], spatial = TRUE,
        modified_after = modified_day, modified_before = modified_day,
        topic = if (length(tags)) tags[[1L]] else NULL,
        category = if (length(categories)) categories[[1L]] else NULL,
        max_items = 1, timeout = 15, total_timeout = 45)
      expect_true(row$id %in% filtered$id)
      expect_true(all(filtered$modified_source == "portal_item"))
      expect_identical(attr(filtered, "discovery_scanned_items"),
                       setNames(1L, county$portal))
      expect_true(all(!is.na(filtered$geometry_type) &
                        filtered$geometry_type != "none"))
      info <- tbod_dataset_info(row, refresh = TRUE, timeout = 15, total_timeout = 45)
      oid <- info$metadata$objectIdField
      expect_true(is.character(oid) && length(oid) == 1L && nzchar(oid))
      descriptor <- tbod_get_dataset(row, fields = oid, limit = 2, page_size = 1,
                                timeout = 15, total_timeout = 45)
      stable <- tbod_get_dataset(row$id, fields = oid, limit = 2, page_size = 1,
                            timeout = 15, total_timeout = 45)
      expect_s3_class(descriptor, "tbl_df")
      expect_identical(names(descriptor), oid)
      expect_gt(nrow(descriptor), 0L)
      expect_lte(nrow(descriptor), 2L)
      expect_false(anyNA(descriptor[[oid]]))
      expect_identical(anyDuplicated(descriptor[[oid]]), 0L)
      expect_identical(stable[[oid]], descriptor[[oid]])
      for (result in list(descriptor, stable)) {
        source <- tbod_provenance(result)
        expect_identical(source$publisher, config$publisher)
        expect_identical(source$jurisdiction, config$jurisdiction)
        expect_identical(source$validation_status, row$validation_status[[1L]])
        expect_identical(source$dataset_id, row$id[[1L]])
        expect_identical(source$source_url, row$source_url)
        expect_identical(source$returned_rows, nrow(result))
        expect_gte(source$matched_rows, nrow(result))
        expect_identical(source$complete, source$matched_rows == source$returned_rows)
      }
    })

    test_that(paste(county$portal, "live county facilities retain projected geometry"), {
      skip_if_not(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
                  "Set TAMPA_OPEN_DATA_LIVE=true to opt into county ArcGIS calls")
      skip_if_not_installed("sf")
      config <- .portal_registry()[[county$portal]]
      found <- tbod_search_datasets(county$query, jurisdiction = config$jurisdiction,
        source = "live", portals = county$portal, max_items = 1,
        timeout = 15, total_timeout = 45)
      expect_gt(nrow(found), 0L)
      row <- found[1L, ]
      info <- tbod_dataset_info(row, refresh = TRUE, timeout = 15, total_timeout = 45)
      oid <- info$metadata$objectIdField
      spatial <- tbod_get_dataset(row$id, fields = oid, spatial = TRUE, out_sr = 4326,
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
      source <- tbod_provenance(spatial)
      expect_identical(source$publisher, config$publisher)
      expect_identical(source$jurisdiction, config$jurisdiction)
      expect_identical(source$validation_status, row$validation_status[[1L]])
      expect_identical(source$dataset_id, row$id[[1L]])
      expect_identical(source$source_url, row$source_url)
      expect_identical(source$query$out_sr, 4326)
      expect_identical(source$returned_rows, nrow(spatial))
      expect_identical(source$complete, source$matched_rows == source$returned_rows)
    })
  })
}

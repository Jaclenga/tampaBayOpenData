test_that("checked catalog includes six publishers and can select Tampa offline", {
  local_mocked_bindings(arcgis_http = function(...) stop("unexpected network"))
  tampa <- tbod_list_datasets(jurisdiction = "tampa", source = "checked")
  regional <- tbod_list_datasets(source = "checked")
  expect_identical(nrow(tampa), 20L)
  expect_identical(nrow(regional), 52L)
  expect_setequal(regional$jurisdiction,
                  c("tampa", "stpete", "clearwater", "hillsborough", "pinellas", "tampa-bay"))
  expect_identical(anyDuplicated(regional$id), 0L)
  expected_counts <- c(stpete = 7L, clearwater = 6L, hillsborough = 8L,
                       pinellas = 7L, `tampa-bay` = 4L)
  for (jurisdiction in names(expected_counts)) {
    city <- tbod_list_datasets(jurisdiction = jurisdiction, source = "checked")
    expect_identical(nrow(city), unname(expected_counts[[jurisdiction]]))
    expect_identical(unique(city$jurisdiction), jurisdiction)
    expect_gte(length(unique(city$category)), 2L)
    prefix <- if (jurisdiction == "tampa-bay") "tbrpc-" else paste0(jurisdiction, "-")
    expect_true(all(startsWith(city$id, prefix)))
    expect_true(all(city$validation_status == "checked"))
    expect_true(all(nzchar(city$terms)))
    expect_true(all(city$id %in% regional$id))
  }
  expect_setequal(tbod_search_datasets("libraries", jurisdiction = "all",
                                  source = "checked")$id,
                  c("clearwater-libraries", "hillsborough-libraries"))
  expect_identical(tbod_search_datasets("streets", jurisdiction = "stpete",
                                   source = "checked")$id, "stpete-streets")
})

test_that("unique regional checked IDs resolve their own jurisdiction", {
  for (id in names(regional_source_cases())) {
    case <- regional_source_cases()[[id]]
    info <- tbod_dataset_info(id)
    explicit <- tbod_dataset_info(id, jurisdiction = case$jurisdiction)
    all <- tbod_dataset_info(id, jurisdiction = "all")
    expect_identical(info, explicit)
    expect_identical(info, all)
    expect_identical(info$jurisdiction, case$jurisdiction)
    expect_identical(info$publisher, case$publisher)
    expect_identical(info$service_url, sub("/[0-9]+$", "", case$metadata_url))
    expect_error(tbod_dataset_info(id, jurisdiction = "tampa"), "Unknown dataset",
                 class = "tampa_input_error")
    row <- tbod_list_datasets(case$jurisdiction, source = "checked")
    row <- row[row$id == id, , drop = FALSE]
    expect_identical(tbod_dataset_info(row)$jurisdiction, case$jurisdiction)
  }
  expect_identical(tbod_dataset_info("parks")$jurisdiction, "tampa")
  expect_identical(nrow(tbod_list_datasets("tampa-bay", source = "checked")), 4L)
})

test_that("all-jurisdiction lookup requires a choice when checked IDs are ambiguous", {
  entry <- .read_registry()[[1L]]
  other <- entry
  other$jurisdiction <- "stpete"
  local_mocked_bindings(.read_registry = function() list(entry, other))
  expect_error(tbod_dataset_info(entry$id), "more than one jurisdiction",
               class = "tampa_input_error")
  expect_identical(tbod_dataset_info(entry$id, jurisdiction = "tampa")$jurisdiction, "tampa")
})

test_that("new checked regional layers share typed pagination and provenance", {
  for (id in names(regional_source_cases())) {
    case <- regional_source_cases()[[id]]
    oid <- regional_oid_field(case)
    fields <- unlist(case$fields, use.names = FALSE)
    transport <- fixture_transport(metadata = case$metadata,
                                   features = regional_source_features(case))
    local_mocked_bindings(arcgis_http = transport$http)
    result <- tbod_get_dataset(id, fields = fields, page_size = 1)
    expect_s3_class(result, "tbl_df")
    expect_identical(names(result), fields)
    expect_identical(result[[oid]], c(2L, 8L, 14L))
    expect_identical(result[[case$label_field]],
                     paste0("synthetic-", c(2L, 8L, 14L), " O'Brien & \u00e9"))
    for (name in setdiff(fields, c(oid, case$label_field))) {
      field <- case$metadata$fields[[match(name, .field_names(case$metadata))]]
      if (field$type == "esriFieldTypeDate") expect_s3_class(result[[name]], "POSIXct")
      if (field$type %in% c("esriFieldTypeDouble", "esriFieldTypeSingle"))
        expect_type(result[[name]], "double")
      if (field$type %in% c("esriFieldTypeInteger", "esriFieldTypeSmallInteger"))
        expect_type(result[[name]], "integer")
      expect_true(is.na(result[[name]][[1L]]))
    }
    source <- tbod_provenance(result)
    expect_identical(source$dataset_id, id)
    expect_identical(source$publisher, case$publisher)
    expect_identical(source$jurisdiction, case$jurisdiction)
    expect_identical(source$validation_status, "checked")
    expect_identical(source$endpoint, paste0(case$metadata_url, "/query"))
    expect_true(source$complete)
    expect_identical(source$returned_rows, 3L)
    expect_length(fixture_queries(transport, "features"), 3L)
    expect_true(all(vapply(transport$state$requests, function(request) {
      request$url %in% c(case$metadata_url, paste0(case$metadata_url, "/query"))
    }, logical(1))))
  }
})

test_that("regional checked geometry uses response CRS and keeps missing rows", {
  skip_if_not_installed("sf")
  for (id in names(regional_source_cases())) {
    case <- regional_source_cases()[[id]]
    oid <- regional_oid_field(case)
    transport <- fixture_transport(metadata = case$metadata,
                                   features = regional_source_features(case))
    local_mocked_bindings(arcgis_http = transport$http)
    result <- tbod_get_dataset(id, fields = c(oid, case$label_field),
                          spatial = TRUE, page_size = 1)
    expect_s3_class(result, "sf")
    expect_identical(result[[oid]], c(2L, 8L, 14L))
    expect_identical(sf::st_is_empty(result), c(TRUE, FALSE, FALSE))
    if (is.null(case$native_epsg)) {
      expect_match(sf::st_crs(result)$wkt, "Albers", ignore.case = TRUE)
    } else {
      expect_equal(sf::st_crs(result)$epsg, case$native_epsg)
    }
    expect_true(all(sf::st_is_valid(result)))
    expect_true(tbod_provenance(result)$complete)
    expect_identical(tbod_provenance(result)$jurisdiction, case$jurisdiction)
  }
})

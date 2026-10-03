test_that("publisher metadata is available offline from one validated registry", {
  local_mocked_bindings(arcgis_http = function(...) stop("Unexpected network call"))
  registry <- .portal_registry()
  expect_invisible(.validate_portals(unname(registry)))
  portals <- list_portals()
  expect_s3_class(portals, "tbl_df")
  expect_identical(portals$id, names(registry))
  expect_identical(names(portals), c("id", "root", "org_id", "publisher",
    "jurisdiction", "website", "verified", "metadata_url", "evidence_url"))
  expect_s3_class(portals$verified, "Date")
  expect_false(anyNA(portals$verified))
  expect_setequal(.discovery_portal_keys("all"), portals$id)
  expect_identical(.discovery_portal_keys(c("pinellas", "city")), c("pinellas", "city"))
  expect_false(exists(".discovery_portals", envir = asNamespace("tampaBayOpenData"),
                      inherits = FALSE))
})

test_that("publisher configuration rejects broken identities and evidence", {
  entries <- unname(.portal_registry())
  expect_error(.validate_portals(list()), "array of publisher records")
  expect_error(.validate_portals(entries[[1L]]), "array of publisher records")
  for (field in names(entries[[1L]])) {
    missing <- entries
    missing[[1L]][[field]] <- NULL
    expect_error(.validate_portals(missing), "documented metadata fields", info = field)
    bad <- entries
    bad[[1L]][[field]] <- NA_character_
    expect_error(.validate_portals(bad), class = "tampa_data_error", info = field)
  }
  for (field in c("id", "org_id")) {
    duplicate <- entries
    duplicate[[2L]][[field]] <- duplicate[[1L]][[field]]
    duplicate[[2L]]$metadata_url <- paste0(duplicate[[2L]]$root, "/portals/self")
    expect_error(.validate_portals(duplicate), "must be unique", info = field)
  }
  bad_values <- list(id = c("all", "global", "bad selector"),
    org_id = c("", "short", strrep("!", 16)), jurisdiction = c("all", "Bad Code"),
    root = c("http://county.example.org/sharing/rest",
      "https://user:secret@county.example.org/sharing/rest",
      "https://county.example.org/sharing/rest?token=secret",
      "https://county.example.org/sharing/rest/",
      "https://county.example.org/../sharing/rest"),
    website = c("http://county.example.org", "https://user@county.example.org"),
    metadata_url = c("https://unrelated.example.org/sharing/rest/portals/self"),
    evidence_url = c("http://county.example.org/gis"),
    verified = c("2026-02-30", "2026-2-3", "not a date"))
  for (field in names(bad_values)) {
    for (value in bad_values[[field]]) {
      bad <- entries
      bad[[1L]][[field]] <- value
      expect_error(.validate_portals(bad), class = "tampa_data_error",
                   info = paste(field, value))
    }
  }
  for (selection in list(c("city", "city"), c("all", "pinellas"),
                         "unconfigured", NA_character_, character())) {
    expect_error(.discovery_portal_keys(selection), "list_portals", class = "tampa_input_error")
  }
})

test_that("a seventh configured publisher uses exhaustive discovery and retrieval unchanged", {
  registry <- .portal_registry()
  extra <- registry$city
  extra$id <- extra$jurisdiction <- "synthetic-county"
  extra$root <- "https://synthetic.example.org/sharing/rest"
  extra$org_id <- "SyntheticOrg1234"
  extra$publisher <- "Synthetic County"
  extra$website <- extra$evidence_url <- "https://synthetic.example.org/gis"
  extra$metadata_url <- paste0(extra$root, "/portals/self")
  registry[[extra$id]] <- extra
  expect_invisible(.validate_portals(unname(registry)))
  local_mocked_bindings(.portal_registry = function() registry)
  expect_identical(tail(list_portals()$id, 1L), extra$id)
  pages <- resources <- list()
  endpoints <- character()
  item_ids <- character()
  for (i in seq_along(registry)) {
    config <- registry[[i]]
    ids <- vapply(1:2, function(j) sprintf("%032x", i * 10L + j), character(1))
    urls <- paste0("https://data.example.org/arcgis/rest/services/Publisher", i,
                   "Layer", 1:2, "/FeatureServer/0")
    endpoints <- c(endpoints, urls)
    item_ids <- c(item_ids, ids)
    items <- unname(Map(function(id, url) discovery_test_item(id, url, org = config$org_id), ids, urls))
    pages[[paste0(config$root, "/search/1")]] <- list(
      total = 2L, start = 1L, nextStart = 2L, results = items[1])
    pages[[paste0(config$root, "/search/2")]] <- list(
      total = 2L, start = 2L, nextStart = -1L, results = items[2])
    for (j in 1:2) {
      metadata <- fixture_metadata()
      metadata$id <- 0L
      resources[[urls[[j]]]] <- metadata
      resources[[paste0("https://www.arcgis.com/sharing/rest/content/items/", ids[[j]])]] <- items[[j]]
      resources[[paste0(config$root, "/content/items/", ids[[j]])]] <- items[[j]]
    }
  }
  discovery <- discovery_test_transport(pages, resources)
  features <- fixture_transport(features = fixture_features(c(2L, 1L)))
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    if (grepl("/query$", url)) features$http(url, params, timeout) else
      discovery$http(url, params, timeout)
  })
  found <- list_datasets(source = "live", portals = "all", max_items = Inf)
  expect_setequal(found$source_url, endpoints)
  expect_true(attr(found, "discovery_complete"))
  expect_identical(attr(found, "discovery_scanned_items"),
                   setNames(rep(2L, length(registry)), names(registry)))
  expect_length(attr(found, "discovery_truncated_portals"), 0L)
  expect_length(Filter(function(x) grepl("/search$", x$url), discovery$state$requests),
                2L * length(registry))
  row <- found[found$jurisdiction == extra$jurisdiction, ][1L, ]
  expect_identical(row$publisher, extra$publisher)
  expect_identical(row$portal, extra$root)
  expect_identical(row$validation_status, "discovered")
  by_descriptor <- get_dataset(row, fields = "OBJECTID", limit = 2, page_size = 1)
  by_stable_id <- get_dataset(row$id, fields = "OBJECTID", limit = 2, page_size = 1)
  expect_identical(by_descriptor$OBJECTID, c(1L, 2L))
  expect_identical(by_stable_id$OBJECTID, by_descriptor$OBJECTID)
  expect_true(dataset_provenance(by_stable_id)$complete)
  expect_identical(dataset_provenance(by_stable_id)$publisher, extra$publisher)
  expect_identical(dataset_provenance(by_stable_id)$jurisdiction, extra$jurisdiction)
  expect_identical(dataset_provenance(by_stable_id)$validation_status, "discovered")
  for (selector in c(extra$id, extra$root)) {
    item <- .discover_arcgis_item(row$item_id, 0L, portal = selector)
    expect_identical(item$id, row$id)
    expect_identical(item$publisher, extra$publisher)
  }
})

test_that("organizations can share a global ArcGIS root without losing attribution", {
  registry <- .portal_registry()
  shared <- registry$tbrpc
  shared$id <- shared$jurisdiction <- "synthetic-shared"
  shared$org_id <- "SyntheticOrg1234"
  shared$publisher <- "Synthetic Shared County"
  shared$website <- shared$evidence_url <- "https://shared.example.org/gis"
  shared$metadata_url <- paste0(shared$root, "/portals/", shared$org_id)
  registry[[shared$id]] <- shared
  expect_invisible(.validate_portals(unname(registry)))
  local_mocked_bindings(.portal_registry = function() registry)
  configs <- registry[c("tbrpc", shared$id)]
  ids <- c(strrep("a", 32), strrep("b", 32))
  urls <- paste0("https://data.example.org/arcgis/rest/services/Shared", 1:2,
                 "/FeatureServer/0")
  resources <- list()
  items <- Map(function(id, url, config) {
    discovery_test_item(id, url, org = config$org_id)
  }, ids, urls, configs)
  for (i in 1:2) {
    metadata <- fixture_metadata()
    metadata$id <- 0L
    resources[[urls[[i]]]] <- metadata
    resources[[paste0(shared$root, "/content/items/", ids[[i]])]] <- items[[i]]
  }
  transport <- discovery_test_transport(resources = resources)
  features <- fixture_transport(features = fixture_features(c(2L, 1L)))
  queries <- character()
  local_mocked_bindings(arcgis_http = function(url, params, timeout) {
    if (grepl("/search$", url)) {
      queries <<- c(queries, params$q)
      org <- vapply(configs, `[[`, character(1), "org_id")
      index <- which(vapply(org, function(x) grepl(paste0("orgid:", x),
                                                   params$q, fixed = TRUE), logical(1)))
      if (length(index) != 1L) stop("The shared-root search must identify exactly one organization.")
      return(fixture_response(list(total = 1L, start = 1L, nextStart = -1L,
                                   results = unname(items[index]))))
    }
    if (grepl("/query$", url)) features$http(url, params, timeout) else
      transport$http(url, params, timeout)
  })
  found <- .discover_arcgis(portals = names(configs), max_items = Inf)
  expect_setequal(found$publisher, vapply(configs, `[[`, character(1), "publisher"))
  expect_setequal(found$jurisdiction, vapply(configs, `[[`, character(1), "jurisdiction"))
  expect_true(attr(found, "discovery_complete"))
  expect_length(queries, 2L)
  expect_true(any(grepl(registry$tbrpc$org_id, queries, fixed = TRUE)))
  expect_true(any(grepl(shared$org_id, queries, fixed = TRUE)))
  for (i in 1:2) {
    by_root <- .discover_arcgis_item(ids[[i]], 0L, portal = shared$root)
    expect_identical(by_root$publisher, configs[[i]]$publisher)
    expect_identical(by_root$jurisdiction, configs[[i]]$jurisdiction)
  }
  expect_equal(nrow(.discover_arcgis_item(ids[[2L]], 0L, portal = "tbrpc")), 0L)
  stable <- get_dataset(paste0("arcgis:", ids[[2L]], ":0"),
                        fields = "OBJECTID", limit = 2, page_size = 1)
  expect_identical(stable$OBJECTID, c(1L, 2L))
  expect_identical(dataset_provenance(stable)$publisher, shared$publisher)
  expect_identical(dataset_provenance(stable)$jurisdiction, shared$jurisdiction)
})

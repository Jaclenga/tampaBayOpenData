# Search behavior is tested with synthetic metadata so ordering and portal
# indexing do not depend on changes to the public ArcGIS catalogs.
search_ranking_entry <- function(base, id, title, description = "",
                                 publisher = "City of Tampa", tags = character()) {
  entry <- base
  entry$id <- id
  entry$title <- title
  entry$description <- description
  entry$publisher <- publisher
  entry$category <- "Planning"
  entry$tags <- as.list(tags)
  entry
}

search_ranking_live_fixture <- function() {
  parks <- tbod_list_datasets(source = "checked")
  parks <- parks[parks$id == "parks", , drop = FALSE]
  live <- parks[rep(1L, 4L), , drop = FALSE]
  ids <- vapply(letters[1:4], strrep, character(1), times = 32)
  live$id <- paste0("arcgis:", ids, ":0")
  live$title <- c("First portal copy", "Second portal copy",
                  "Indexed city layer", "Indexed county layer")
  live$description <- rep("Synthetic layer indexed by the portal", 4L)
  live$jurisdiction <- c("tampa", "tampa", "tampa", "hillsborough")
  live$publisher <- c(rep("City of Tampa", 3L), "Hillsborough County")
  live$service_url <- c(rep(parks$service_url, 2L),
                        "https://example.org/arcgis/rest/services/IndexedCity/FeatureServer",
                        "https://example.org/arcgis/rest/services/IndexedCounty/FeatureServer")
  live$layer_id <- c(parks$layer_id, parks$layer_id, 0L, 0L)
  live$source_url <- c(rep(parks$source_url, 2L),
                       paste0(live$service_url[3:4], "/0"))
  live$item_id <- ids
  portals <- .portal_registry()
  live$portal <- c(rep(portals$city$root, 3L), portals$hillsborough$root)
  live$tags <- rep(list("synthetic index"), 4L)
  live$categories <- rep(list("Planning"), 4L)
  live$validation_status <- rep("discovered", 4L)
  live$original_metadata <- rep(list(list(item = "synthetic")), 4L)
  attr(live, "discovery_complete") <- FALSE
  attr(live, "discovery_issues") <- "one synthetic item could not be inspected"
  attr(live, "discovery_failed_portals") <- "pinellas"
  attr(live, "discovery_scanned_items") <- c(city = 2L, hillsborough = 1L)
  attr(live, "discovery_truncated_portals") <- "city"
  live
}

test_that("checked searches rank exact identifiers and titles before partial titles and metadata", {
  base <- .read_registry()[[1L]]
  entries <- list(
    search_ranking_entry(base, "description-only", "Inspections", "Permit applications"),
    search_ranking_entry(base, "partial-title", "Permit Applications"),
    search_ranking_entry(base, "publisher-only", "Documents", publisher = "Permit Office"),
    search_ranking_entry(base, "exact-title", "Permit"),
    search_ranking_entry(base, "tag-only", "Licenses", tags = "permit"),
    search_ranking_entry(base, "permit", "Work orders"),
    search_ranking_entry(base, "irrelevant", "Drainage")
  )
  local_mocked_bindings(.read_registry = function() entries,
                        .package = "tampaBayOpenData")

  results <- tbod_search_datasets("permit", source = "checked")
  expect_setequal(results$id[1:2], c("permit", "exact-title"))
  expect_identical(results$id[[3L]], "partial-title")
  expect_setequal(results$id[4:6],
                  c("description-only", "tag-only", "publisher-only"))
  expect_identical(nrow(results), 6L)
  expect_identical(tbod_search_datasets("permit", source = "checked")$id,
                   results$id)
  expect_identical(tbod_search_datasets("permit applications", source = "checked")$id,
                   c("partial-title", "description-only"))
})

test_that("checked search supports typo fallback without changing empty and literal searches", {
  typo <- tbod_search_datasets("permti", source = "checked")
  expect_true("construction-permits" %in% typo$id)
  expect_true("zoning-districts" %in%
                tbod_search_datasets("zonning", source = "checked")$id)
  expect_true("hillsborough-water-quality" %in%
                tbod_search_datasets("water qualty", source = "checked")$id)
  expect_identical(nrow(tbod_search_datasets("parcels", source = "checked")), 0L)
  expect_identical(tbod_search_datasets("", source = "checked"),
                   tbod_list_datasets(source = "checked"))
  expect_identical(tbod_search_datasets(" \t\n ", source = "checked"),
                   tbod_list_datasets(source = "checked"))
  expect_identical(nrow(tbod_search_datasets("per.*", source = "checked")), 0L)
  expect_identical(nrow(tbod_search_datasets("[", source = "checked")), 0L)
})

test_that("result limit applies to ranked and filtered rows, and validates its input", {
  unbounded <- tbod_search_datasets("", source = "checked", publisher = "CITY OF TAMPA")
  limited <- tbod_search_datasets("", source = "checked",
                                  publisher = "CITY OF TAMPA", limit = 2)
  expect_identical(limited$id, unbounded$id[1:2])
  expect_true(all(tolower(limited$publisher) == "city of tampa"))
  expect_identical(nrow(tbod_search_datasets("", source = "checked",
                                             publisher = "CITY OF TAMPA", limit = 0)), 0L)
  expect_identical(tbod_search_datasets("", source = "checked", limit = Inf)$id,
                   tbod_search_datasets("", source = "checked")$id)
  for (value in list(-1, 1.5, NA_real_, c(1, 2), "2")) {
    expect_error(tbod_search_datasets("permit", source = "checked", limit = value),
                 "limit", class = "tampa_input_error")
  }
})

test_that("live indexed results survive local text ranking and checked endpoints stay unique", {
  live <- search_ranking_live_fixture()
  calls <- list()
  local_mocked_bindings(.discover_arcgis = function(query, portals, max_items, timeout) {
    calls[[length(calls) + 1L]] <<- list(query = query, portals = portals,
                                        max_items = max_items)
    live
  }, .package = "tampaBayOpenData")

  results <- tbod_search_datasets("permit", source = "live", max_items = 1)
  expect_identical(calls[[1L]]$query, "permit")
  expect_identical(calls[[1L]]$max_items, 1)
  expect_identical(nrow(results), 3L)
  expect_setequal(results$id,
                  c("parks", live$id[[3L]], live$id[[4L]]))
  expect_identical(sum(results$id == "parks"), 1L)
  expect_identical(results$validation_status[results$id == "parks"], "checked")
  expect_true(all(results$validation_status[results$id %in% live$id[3:4]] == "discovered"))
  expect_false(any(grepl("permit", live$title, ignore.case = TRUE)))
  expect_identical(attr(results, "discovery_complete"), FALSE)
  expect_identical(attr(results, "discovery_issues"), attr(live, "discovery_issues"))
  expect_identical(attr(results, "discovery_failed_portals"),
                   attr(live, "discovery_failed_portals"))

  limited <- tbod_search_datasets("permit", source = "live", max_items = 1,
                                  limit = 2)
  expect_identical(limited$id, results$id[1:2])
  for (name in c("discovery_complete", "discovery_issues",
                 "discovery_failed_portals", "discovery_scanned_items",
                 "discovery_truncated_portals")) {
    expect_identical(attr(limited, name), attr(results, name), info = name)
  }
  expect_identical(nrow(tbod_search_datasets("permit", source = "live",
                                             max_items = 1, limit = 0)), 0L)
})

test_that("publisher filtering narrows live scans and excludes other publishers", {
  live <- search_ranking_live_fixture()
  calls <- list()
  local_mocked_bindings(.discover_arcgis = function(query, portals, max_items, timeout) {
    calls[[length(calls) + 1L]] <<- portals
    live
  }, .package = "tampaBayOpenData")

  city <- tbod_search_datasets("permit", source = "live",
                               publisher = "CITY OF TAMPA")
  expect_identical(calls[[1L]], "city")
  expect_true(all(city$publisher == "City of Tampa"))
  expect_setequal(city$id, c("parks", live$id[[3L]]))
  expect_identical(nrow(tbod_search_datasets("permit", source = "live",
                                             publisher = "Unknown publisher")), 0L)
  expect_length(calls, 1L)
})

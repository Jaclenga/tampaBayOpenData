test_that("live City discovery returns an item with a stable service layer identity", {
  skip_if_not(identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true"),
              "Set TAMPA_OPEN_DATA_LIVE=true to opt into ArcGIS portal calls")
  found <- .discover_arcgis("permits", portals = "city", max_items = 10, timeout = 15)
  expect_gt(nrow(found), 0L)
  expect_true(all(grepl("^arcgis:[[:xdigit:]]{32}:[0-9]+$", found$id)))
  expect_true(all(grepl("^https://", found$source_url)))
  expect_true(all(found$validation_status == "discovered"))
})

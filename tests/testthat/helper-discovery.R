# Synthetic portal items and service schemas; no copied government records.
discovery_test_item <- function(id, url, title = "Service", org = "IbNXlmt2RVVRCZ6M",
                                type = "Feature Service") {
  list(id = id, type = type, title = title, url = url, orgId = org,
       owner = "synthetic_owner", snippet = "Synthetic test item",
       tags = list("roads", "test"), categories = list("Transport"),
       modified = 1720000000000)
}

discovery_test_transport <- function(pages = list(), resources = list()) {
  state <- new.env(parent = emptyenv())
  state$requests <- list()
  http <- function(url, params, timeout) {
    state$requests[[length(state$requests) + 1L]] <-
      list(url = url, params = params, timeout = timeout)
    value <- if (grepl("/search$", url)) {
      pages[[paste0(url, "/", params$start)]]
    } else resources[[url]]
    if (is.null(value)) return(fixture_response(list(), status = 404L))
    fixture_response(value)
  }
  list(http = http, state = state)
}

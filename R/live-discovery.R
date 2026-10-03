# ArcGIS Portal item search is the live discovery source. Organization IDs
# come from the providers' public portal metadata. The search index may lag
# publication and contains only public items.
.discovery_portal_keys <- function(portals, registry = .portal_registry()) {
  message <- paste0("`portals` must contain unique configured publisher names: ",
                     paste(c(names(registry), "all"), collapse = ", "), ". Use list_portals() to inspect them.")
  if (!is.character(portals) || !length(portals) || anyNA(portals) ||
      any(!nzchar(portals)) || anyDuplicated(portals) ||
      (!identical(portals, "all") && any(!portals %in% names(registry)))) {
    .abort(message, subclass = "tampa_input_error")
  }
  if (identical(portals, "all")) return(names(registry))
  portals
}

.empty_discovery <- function() {
  tibble::tibble(
    id = character(), title = character(), description = character(),
    jurisdiction = character(), publisher = character(), owner = character(),
    source_url = character(), service_url = character(), layer_id = integer(),
    layer_name = character(), item_id = character(), portal = character(),
    validation_status = character(), geometry_type = character(),
    service_type = character(), layer_type = character(),
    modified = as.POSIXct(character(), tz = "UTC"),
    tags = list(), categories = list(), original_metadata = list())
}

.discovery_query <- function(query = NULL, org_id = .portal_registry()$city$org_id) {
  # Discover public Feature Service items. These may legitimately point to
  # queryable MapServer layers as well as FeatureServer services.
  base <- paste0("orgid:", org_id, " AND type:\"Feature Service\"")
  if (is.null(query) || !nzchar(trimws(query))) return(base)
  # A quoted phrase keeps user text out of the portal query operators.
  paste(base, "AND", encodeString(trimws(query), quote = '"'))
}

.discovery_page <- function(query, start, num, timeout, portal) {
  url <- paste0(portal, "/search")
  page <- arcgis_request(url, params = list(
    q = query, start = start, num = num,
    sortField = "modified", sortOrder = "desc"), timeout = timeout)
  valid_integer <- function(x) is.numeric(x) && length(x) == 1L &&
    !is.na(x) && is.finite(x) && x == floor(x)
  if (!is.list(page$results) || !is.null(names(page$results)) ||
      length(page$results) > num || !valid_integer(page$nextStart) ||
      !(page$nextStart == -1L || page$nextStart > start) ||
      !valid_integer(page$total) || page$total < 0L ||
      !valid_integer(page$start) || page$start != start) {
    .abort("The ArcGIS portal returned malformed search pagination.",
           url = url, subclass = "tampa_response_error")
  }
  if (page$nextStart != -1L && !length(page$results)) {
    .abort("The ArcGIS portal returned an empty page with a continuation.",
           url = url, subclass = "tampa_response_error")
  }
  page
}

.discovery_scalar <- function(x, fallback = "") {
  if (is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x))) x else fallback
}

.discovery_strings <- function(x) {
  if (is.null(x)) return(character())
  if (is.character(x)) return(x[!is.na(x) & nzchar(x)])
  if (!is.list(x) || !is.null(names(x))) return(character())
  values <- Filter(function(value) is.character(value) && length(value) == 1L &&
                     !is.na(value) && nzchar(value), x)
  unlist(values, use.names = FALSE) %||% character()
}

.discovery_description <- function(item) {
  snippet <- .discovery_scalar(item$snippet)
  if (nzchar(snippet)) return(snippet)
  description <- .discovery_scalar(item$description)
  trimws(gsub("[[:space:]]+", " ", gsub("<[^>]*>", " ", description)))
}

.discovery_modified <- function(x) {
  if (is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x) && x >= 0) {
    return(as.POSIXct(x / 1000, origin = "1970-01-01", tz = "UTC"))
  }
  as.POSIXct(NA, origin = "1970-01-01", tz = "UTC")
}

# Portal items can refer either to a service root or directly to one layer.
# Reuse the retrieval URL validator so discovery never probes a URL the
# generic client would reject (private hosts, path traversal, bad segments).
.discovery_url_parts <- function(url) {
  if (!is.character(url) || length(url) != 1L || is.na(url) ||
      grepl("[?#@]", url)) return(NULL)
  normalized <- sub("/+$", "", url)
  if (!grepl("/(FeatureServer|MapServer)(/[0-9]+)?$", normalized)) return(NULL)
  checked <- if (grepl("/(FeatureServer|MapServer)$", normalized))
    paste0(normalized, "/0") else normalized
  validated <- tryCatch(.arcgis_layer_url(checked), error = function(e) NULL)
  if (is.null(validated)) return(NULL)
  root <- validated$service_url
  suffix <- substring(normalized, nchar(root) + 1L)
  layer_id <- if (nzchar(suffix)) suppressWarnings(as.numeric(sub("^/", "", suffix))) else NULL
  if (!is.null(layer_id) && (!is.finite(layer_id) || layer_id > .Machine$integer.max)) return(NULL)
  list(service_url = root, layer_id = if (is.null(layer_id)) NULL else as.integer(layer_id),
       service_type = sub("^.*/", "", root))
}

.discovery_layer_candidates <- function(item, parts, timeout, service_cache) {
  if (is.null(parts$layer_id)) {
    key <- parts$service_url
    if (!exists(key, envir = service_cache, inherits = FALSE)) {
      assign(key, arcgis_request(key, timeout = timeout), envir = service_cache)
    }
    service <- get(key, envir = service_cache, inherits = FALSE)
    layers <- service$layers %||% list()
    tables <- service$tables %||% list()
    if (!is.list(layers) || !is.null(names(layers)) ||
        !is.list(tables) || !is.null(names(tables))) {
      stop("Service does not contain valid layer and table arrays.")
    }
    c(layers, tables)
  } else {
    # A direct layer item is already scoped; asking its service root would
    # incorrectly add unrelated layers to the search result.
    layer <- arcgis_request(paste0(parts$service_url, "/", parts$layer_id),
                            timeout = timeout)
    if (!is.numeric(layer$id) || length(layer$id) != 1L ||
        is.na(layer$id) || layer$id != parts$layer_id) {
      stop("Direct layer item has an invalid or changed layer ID.")
    }
    list(layer)
  }
}

.discovery_item_rows <- function(item, timeout, service_cache, config) {
  if (!is.list(item) || !is.null(item$error) ||
      !is.character(item$id) || length(item$id) != 1L || is.na(item$id) ||
      !grepl("^[[:xdigit:]]{32}$", item$id) ||
      !.discovery_scalar(item$type) %in% c("Feature Service", "Map Service")) {
    stop("Item is missing a valid ArcGIS service identity.")
  }
  parts <- .discovery_url_parts(item$url)
  if (is.null(parts)) stop("Item has no supported public HTTPS service URL.")
  candidates <- .discovery_layer_candidates(item, parts, timeout, service_cache)
  rows <- list()
  for (layer in candidates) {
    if (!is.list(layer) || !is.numeric(layer$id) || length(layer$id) != 1L ||
        is.na(layer$id) || !is.finite(layer$id) || layer$id < 0 ||
        layer$id != floor(layer$id) || layer$id > .Machine$integer.max) next
    layer_type <- .discovery_scalar(layer$type)
    if (!layer_type %in% c("Feature Layer", "Table")) next
    if (is.character(layer$capabilities) && length(layer$capabilities) == 1L &&
        !grepl("(^|,)Query(,|$)", layer$capabilities)) next
    # The root lists the geometry type for feature layers; tables have none.
    geometry <- if (identical(layer_type, "Table")) "none" else
      .discovery_scalar(layer$geometryType, NA_character_)
    if (identical(layer_type, "Feature Layer") && is.na(geometry)) next
    name <- .discovery_scalar(layer$name, paste0("Layer ", layer$id))
    item_title <- .discovery_scalar(item$title)
    title <- if (!is.null(parts$layer_id) || length(candidates) == 1L)
      .discovery_scalar(item_title, name) else name
    item_id <- tolower(item$id)
    layer_id <- as.integer(layer$id)
    endpoint <- paste0(parts$service_url, "/", layer_id)
    rows[[length(rows) + 1L]] <- tibble::tibble(
      id = paste0("arcgis:", item_id, ":", layer_id), title = title,
      description = .discovery_description(item), jurisdiction = config$jurisdiction,
      publisher = config$publisher, owner = .discovery_scalar(item$owner),
      source_url = endpoint, service_url = parts$service_url,
      layer_id = layer_id, layer_name = name, item_id = item_id,
      portal = config$root, validation_status = "discovered",
      geometry_type = geometry, service_type = parts$service_type,
      layer_type = layer_type, modified = .discovery_modified(item$modified),
      tags = list(.discovery_strings(item$tags)),
      categories = list(.discovery_strings(item$categories)),
      original_metadata = list(list(item = item, layer = layer)))
  }
  if (!length(rows)) return(.empty_discovery())
  do.call(rbind, rows)
}

.dedupe_discovery <- function(rows) {
  if (!nrow(rows)) return(rows)
  # If a root item and an item dedicated to its layer point to the same URL,
  # prefer the dedicated item's title and metadata. The tie break is stable.
  direct <- vapply(rows$original_metadata, function(meta) {
    !is.null(.discovery_url_parts(meta$item$url)$layer_id)
  }, logical(1))
  choice <- order(rows$source_url, !direct, rows$item_id)
  rows <- rows[choice, , drop = FALSE]
  rows <- rows[!duplicated(rows$source_url), , drop = FALSE]
  rows[order(tolower(rows$title), rows$source_url), , drop = FALSE]
}

# Scan one provider, retaining rows and item issues if a later search page fails.
.discover_portal <- function(key, query, max_items, timeout, cache,
                             config = .portal_registry()[[key]]) {
  search <- .discovery_query(query, config$org_id)
  rows <- list()
  issues <- character()
  start <- 1L
  seen <- 0L
  truncated <- FALSE
  repeat {
    num <- if (is.infinite(max_items)) 100L else as.integer(min(100, max_items - seen))
    if (num <= 0L) break
    page <- tryCatch(.discovery_page(search, start, num, timeout, config$root),
                     error = .discovery_error)
    if (inherits(page, "error")) {
      return(list(rows = rows, issues = issues, error = page,
                  scanned = seen, truncated = FALSE))
    }
    for (item in page$results) {
      item_rows <- tryCatch(.discovery_item_rows(item, timeout, cache, config),
                            error = .discovery_error)
      if (inherits(item_rows, "error")) {
        item_id <- if (is.list(item)) .discovery_scalar(item$id, "unknown") else "unknown"
        issues <- c(issues, paste0(key, "/", item_id, ": ", conditionMessage(item_rows)))
      } else if (nrow(item_rows)) {
        rows[[length(rows) + 1L]] <- item_rows
      }
    }
    seen <- seen + length(page$results)
    if (page$nextStart == -1L) break
    if (seen >= max_items) {
      truncated <- TRUE
      break
    }
    start <- as.integer(page$nextStart)
  }
  list(rows = rows, issues = issues, error = NULL, scanned = seen,
        truncated = truncated)
}

# An elapsed operation budget is not an individual stale portal item.
.discovery_error <- function(e) {
  if (inherits(e, "tampa_timeout_error")) stop(e)
  e
}

# Return public provider layers represented by portal items. max_items limits
# portal *items per provider*, not expanded layer rows. A bad item is isolated;
# an invalid search page remains a visible error.
.discover_arcgis <- function(query = NULL, portals = "city", max_items = Inf,
                             timeout = 30) {
  if (!is.null(query)) .string(query, "query", allow_empty = TRUE)
  registry <- .portal_registry()
  keys <- .discovery_portal_keys(portals, registry)
  .number(max_items, "max_items", integer = TRUE, infinity = TRUE)
  .number(timeout, "timeout", min = .Machine$double.eps)
  if (identical(max_items, 0) || identical(max_items, 0L)) return(.empty_discovery())
  rows <- list()
  issues <- character()
  failed_portals <- character()
  truncated_portals <- character()
  scanned_items <- stats::setNames(integer(length(keys)), keys)
  cache <- new.env(parent = emptyenv())
  for (key in keys) {
    portal <- .discover_portal(key, query, max_items, timeout, cache, registry[[key]])
    rows <- c(rows, portal$rows)
    issues <- c(issues, portal$issues)
    scanned_items[[key]] <- portal$scanned
    if (portal$truncated) truncated_portals <- c(truncated_portals, key)
    if (!is.null(portal$error)) {
      failed_portals <- c(failed_portals, key)
      issues <- c(issues, paste0("Portal ", key, ": ", conditionMessage(portal$error)))
    }
  }
  if (length(failed_portals) == length(keys)) {
    .abort(paste0("All selected ArcGIS portals failed during discovery. ",
                  paste(issues, collapse = " | ")),
           subclass = "tampa_discovery_error")
  }
  result <- if (length(rows)) do.call(rbind, rows) else .empty_discovery()
  result <- .dedupe_discovery(result)
  attr(result, "discovery_issues") <- issues
  attr(result, "discovery_failed_portals") <- failed_portals
  attr(result, "discovery_scanned_items") <- scanned_items
  attr(result, "discovery_truncated_portals") <- truncated_portals
  attr(result, "discovery_complete") <- !length(issues) &&
    !length(failed_portals) && !length(truncated_portals)
  if (length(failed_portals)) {
    warning(paste0("ArcGIS discovery returned partial results; portal(s) failed: ",
                   paste(failed_portals, collapse = ", "),
                   ". See the returned table's `discovery_issues` attribute."),
            call. = FALSE)
  }
  result
}

# Resolve an item ID without searching titles or relying on a prior search.
# The caller chooses a layer when an item points to a multi-layer service.
.discover_arcgis_item <- function(item_id, layer_id = NULL, portal = "all",
                                  timeout = 30) {
  .string(item_id, "item_id")
  if (!grepl("^[[:xdigit:]]{32}$", item_id)) {
    .abort("`item_id` must be a 32-character ArcGIS item ID.",
           subclass = "tampa_input_error")
  }
  if (!is.null(layer_id)) {
    .number(layer_id, "layer_id", integer = TRUE)
    if (layer_id > .Machine$integer.max) .abort("`layer_id` is too large.",
                                                subclass = "tampa_input_error")
  }
  .number(timeout, "timeout", min = .Machine$double.eps)
  registry <- .portal_registry()
  if (!is.character(portal) || length(portal) != 1L || is.na(portal)) {
    .abort("`portal` must identify a configured publisher from list_portals() or be 'all'.",
           subclass = "tampa_input_error")
  }
  if (identical(portal, "all") || identical(portal, "global")) {
    lookup_root <- "https://www.arcgis.com/sharing/rest"
    requested <- NULL
  } else {
    keys <- names(registry)[vapply(registry,
      function(x) identical(x$root, portal), logical(1))]
    if (portal %in% names(registry)) keys <- portal
    if (!length(keys)) .abort("Unknown ArcGIS portal.", subclass = "tampa_input_error")
    requested <- keys
    lookup_root <- registry[[keys[[1L]]]]$root
  }
  url <- paste0(lookup_root, "/content/items/", tolower(item_id))
  item <- arcgis_request(url, timeout = timeout)
  matched <- names(registry)[vapply(registry,
    function(x) identical(item$orgId, x$org_id), logical(1))]
  if (length(matched) != 1L || (!is.null(requested) && !matched %in% requested)) {
    return(.empty_discovery())
  }
  rows <- tryCatch(.discovery_item_rows(item, timeout,
                                        new.env(parent = emptyenv()),
                                        registry[[matched]]),
                    error = function(e) {
                      if (inherits(e, "tampa_timeout_error")) stop(e)
                      .empty_discovery()
                    })
  if (!is.null(layer_id)) rows <- rows[rows$layer_id == layer_id, , drop = FALSE]
  .dedupe_discovery(rows)
}

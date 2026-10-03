# Omitted jurisdictions are resolved from the selected checked ID or descriptor.
.requested_jurisdiction <- function(id, jurisdiction, omitted) {
  if (omitted) return(NULL)
  jurisdiction
}

# Resolve all public retrieval inputs before calling the shared query engine.
# Only a bundled registry entry can claim the package's `checked` status.
.resolve_dataset <- function(id, jurisdiction = "tampa", timeout = 30) {
  if (!is.null(jurisdiction)) .string(jurisdiction, "jurisdiction")
  if (identical(jurisdiction, "all")) jurisdiction <- NULL
  if (is.character(id)) {
    .string(id, "id")
    if (grepl("^arcgis:[0-9a-fA-F]{32}:[0-9]+$", id)) {
      parts <- strsplit(id, ":", fixed = TRUE)[[1L]]
      layer_id <- suppressWarnings(as.numeric(parts[[3L]]))
      if (!is.finite(layer_id) || layer_id > .Machine$integer.max) {
        .abort("The ArcGIS identifier has an invalid layer ID.", subclass = "tampa_input_error")
      }
      rows <- .discover_arcgis_item(parts[[2L]], as.integer(layer_id),
                                    timeout = timeout)
      if (!is.data.frame(rows) || nrow(rows) != 1L) {
        .abort(paste0("ArcGIS item `", parts[[2L]], "` layer ", layer_id,
                      " is unavailable or is not a supported query layer. Search again for its current service."),
               subclass = "tampa_input_error")
      }
      return(.dataset_descriptor(rows, jurisdiction))
    }
    return(.checked_dataset(id, jurisdiction %||% "all"))
  }
  .dataset_descriptor(id, jurisdiction)
}

.checked_dataset <- function(id, jurisdiction) {
  dataset <- .lookup_dataset(id, jurisdiction)
  dataset$validation_status <- "checked"
  dataset$item_id <- dataset$item_id %||% NULL
  dataset$portal <- dataset$portal %||% NULL
  dataset$original_metadata <- dataset
  dataset
}

.dataset_descriptor <- function(x, jurisdiction = "tampa") {
  if (is.data.frame(x)) {
    if (nrow(x) != 1L) {
      .abort("A dataset descriptor must contain exactly one row.",
             subclass = "tampa_input_error")
    }
    x <- lapply(x, function(column) column[[1L]])
  }
  if (!is.list(x) || is.null(names(x)) || anyDuplicated(names(x))) {
    .abort("A dataset descriptor must be a named list or a one-row discovery result.",
           subclass = "tampa_input_error")
  }
  .string(x$service_url, "descriptor.service_url")
  .number(x$layer_id, "descriptor.layer_id", integer = TRUE)
  if (x$layer_id > .Machine$integer.max) {
    .abort("`descriptor.layer_id` must fit in an R integer.",
           subclass = "tampa_input_error")
  }
  layer_url <- paste0(x$service_url, "/", x$layer_id)
  parts <- .arcgis_layer_url(layer_url)
  if (!identical(parts$service_url, x$service_url) ||
      !identical(parts$layer_id, as.integer(x$layer_id))) {
    .abort("The descriptor's service URL and layer ID are inconsistent.",
           subclass = "tampa_input_error")
  }
  status <- x$validation_status %||% "discovered"
  .string(status, "descriptor.validation_status")
  if (!status %in% c("checked", "discovered", "not_checked")) {
    .abort("`descriptor.validation_status` must be checked, discovered, or not_checked.",
           subclass = "tampa_input_error")
  }
  if (is.null(jurisdiction)) jurisdiction <- x$jurisdiction %||% "tampa"
  .string(jurisdiction, "jurisdiction")
  if (!is.null(x$jurisdiction) && !is.na(x$jurisdiction)) {
    .string(x$jurisdiction, "descriptor.jurisdiction")
    if (!identical(x$jurisdiction, jurisdiction)) {
      .abort("The descriptor's jurisdiction differs from the requested jurisdiction.",
             subclass = "tampa_input_error")
    }
  }
  if (identical(status, "checked")) {
    return(.checked_dataset_descriptor(x, jurisdiction))
  }
  .unchecked_dataset_descriptor(x, jurisdiction, status, layer_url, parts)
}

.checked_dataset_descriptor <- function(x, jurisdiction) {
  .string(x$id, "descriptor.id")
  checked <- tryCatch(.checked_dataset(x$id, jurisdiction),
                      tampa_data_error = function(e) NULL)
  if (is.null(checked) || !identical(checked$service_url, x$service_url) ||
      !identical(as.integer(checked$layer_id), as.integer(x$layer_id))) {
    .abort("Only a matching bundled registry entry can claim `checked` status.",
           subclass = "tampa_input_error")
  }
  # Keep item attribution from the bundled record when available. A portal
  # row cannot silently replace that attribution with a different item ID.
  supplied_item <- .descriptor_item_id(x$item_id)
  if (!is.null(supplied_item) && !is.null(checked$item_id) &&
      !identical(supplied_item, tolower(checked$item_id))) {
    .abort("The checked descriptor's ArcGIS item ID differs from the bundled registry.",
           subclass = "tampa_input_error")
  }
  checked$item_id <- checked$item_id %||% supplied_item
  checked$portal <- checked$portal %||% .descriptor_portal(x$portal)
  checked$original_metadata <- x
  checked
}

# Discovered portal rows and direct URLs share the same untrusted path.
.unchecked_dataset_descriptor <- function(x, jurisdiction, status, layer_url, parts) {
  source_url <- x$source_url %||% layer_url
  .string(source_url, "descriptor.source_url")
  if (!identical(source_url, layer_url)) {
    .abort("A discovered descriptor's source URL must equal its ArcGIS layer URL.",
           subclass = "tampa_input_error")
  }
  item_id <- .descriptor_item_id(x$item_id)
  portal <- .descriptor_portal(x$portal)
  if (identical(status, "discovered") && (is.null(item_id) || is.null(portal))) {
    .abort("A discovered descriptor needs an ArcGIS item ID and portal source.",
           subclass = "tampa_input_error")
  }
  expected_id <- if (!is.null(item_id)) paste0("arcgis:", tolower(item_id), ":", parts$layer_id)
  key <- x$id %||% expected_id %||% layer_url
  .string(key, "descriptor.id")
  if (identical(status, "discovered") &&
      !identical(tolower(key), expected_id)) {
    .abort("The descriptor ID does not match its ArcGIS item and layer IDs.",
           subclass = "tampa_input_error")
  }
  title <- x$title
  if (!is.character(title) || length(title) != 1L || is.na(title) ||
      !nzchar(trimws(title))) {
    title <- paste0("ArcGIS layer ", parts$layer_id)
  }
  publisher <- x$publisher
  if (!is.character(publisher) || length(publisher) != 1L ||
      is.na(publisher) || !nzchar(trimws(publisher))) {
    publisher <- "Unknown ArcGIS publisher"
  }
  .string(title, "descriptor.title")
  .string(publisher, "descriptor.publisher")
  x$id <- key
  x$title <- title
  x$publisher <- publisher
  x$jurisdiction <- jurisdiction
  x$source_url <- layer_url
  x$service_url <- parts$service_url
  x$layer_id <- parts$layer_id
  x$item_id <- item_id
  x$portal <- portal
  x$validation_status <- status
  x$verified <- NULL
  x$terms <- x$terms %||% NULL
  x$original_metadata <- x$original_metadata %||% x
  x
}

.descriptor_item_id <- function(item_id) {
  if (is.null(item_id) || (length(item_id) == 1L && is.na(item_id))) return(NULL)
  .string(item_id, "descriptor.item_id")
  if (!grepl("^[0-9a-fA-F]{32}$", item_id)) {
    .abort("`descriptor.item_id` must contain 32 hexadecimal characters.",
           subclass = "tampa_input_error")
  }
  tolower(item_id)
}

.descriptor_portal <- function(portal) {
  if (is.null(portal) || (length(portal) == 1L && is.na(portal))) return(NULL)
  .string(portal, "descriptor.portal")
  if (!grepl("^https://[A-Za-z0-9][A-Za-z0-9.-]*(/[A-Za-z0-9._~!$&'()*+,;=:@%/-]*)?$", portal) ||
      grepl("[?#\\\\]", portal)) {
    .abort("`descriptor.portal` must be an HTTPS portal root without credentials or query parameters.",
           subclass = "tampa_input_error")
  }
  portal
}

.direct_arcgis_descriptor <- function(url) {
  parts <- .arcgis_layer_url(url)
  list(id = url, title = paste0("ArcGIS layer ", parts$layer_id),
       publisher = "Unknown ArcGIS publisher", jurisdiction = "unspecified",
       source_url = url, service_url = parts$service_url,
       layer_id = parts$layer_id, item_id = NULL, portal = NULL,
       validation_status = "not_checked")
}

.arcgis_layer_url <- function(url) {
  .string(url, "url")
  pieces <- regmatches(url, regexec(
    "^https://([^/?#]+)/(.+)/(FeatureServer|MapServer)/([0-9]+)$", url,
    perl = TRUE))[[1L]]
  if (length(pieces) != 5L || grepl("[[:space:]?#\\\\]", url)) {
    .abort("Use a public HTTPS ArcGIS layer URL ending in `/FeatureServer/<id>` or `/MapServer/<id>`.",
           subclass = "tampa_input_error")
  }
  host <- pieces[[2L]]
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$", host) ||
      grepl("\\.\\.|^[0-9.]+$|(^|\\.)localhost$|\\.(local|internal|home|lan)$", host,
            ignore.case = TRUE) ||
      grepl("%2[fF]|%5[cC]|(^|/)\\.\\.?(/|$)", pieces[[3L]])) {
    .abort("The ArcGIS layer URL must use a public DNS host and ordinary path segments.",
           subclass = "tampa_input_error")
  }
  layer_id <- suppressWarnings(as.numeric(pieces[[5L]]))
  if (!is.finite(layer_id) || layer_id > .Machine$integer.max) {
    .abort("The ArcGIS layer URL has an invalid layer ID.",
           subclass = "tampa_input_error")
  }
  list(service_url = sub("/[0-9]+$", "", url), layer_id = as.integer(layer_id))
}

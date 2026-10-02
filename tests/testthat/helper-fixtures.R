# Synthetic records model Tampa's verified permit schema, with deliberately
# supplemental COST and TENTATIVEHEARING fields to exercise additional types.
# They contain no copied government addresses, names, or contact information.
fixture_field <- function(name, type, alias = name) {
  list(name = name, type = type, alias = alias)
}

fixture_metadata <- function(max_records = 2L, pagination = TRUE, ordering = TRUE) {
  list(
    name = "Permits", type = "Feature Layer", capabilities = "Query",
    geometryType = "esriGeometryPoint", objectIdField = "OBJECTID",
    maxRecordCount = max_records, supportedQueryFormats = "JSON, geoJSON, PBF",
    fields = list(
      fixture_field("OBJECTID", "esriFieldTypeOID"),
      fixture_field("RECORD_ID", "esriFieldTypeString", "Record ID"),
      fixture_field("PROJECTSTATUS", "esriFieldTypeString", "Project Status"),
      fixture_field("LASTUPDATE", "esriFieldTypeDate", "Last Update"),
      fixture_field("CREATEDDATE", "esriFieldTypeDate", "Created Date"),
      fixture_field("NEWCONSTRUCTIONSF", "esriFieldTypeInteger"),
      fixture_field("COST", "esriFieldTypeDouble"),
      fixture_field("TENTATIVEHEARING", "esriFieldTypeString"),
      fixture_field("GlobalID", "esriFieldTypeGlobalID"),
      fixture_field("SHAPE", "esriFieldTypeGeometry")
    ),
    extent = list(spatialReference = list(wkid = 102100, latestWkid = 3857)),
    sourceSpatialReference = list(wkid = 102100, latestWkid = 3857),
    advancedQueryCapabilities = list(supportsPagination = pagination,
                                     supportsOrderBy = ordering),
    datesInUnknownTimezone = FALSE,
    dateFieldsTimeReference = list(timeZone = "Eastern Standard Time",
                                  timeZoneIANA = "America/New_York",
                                  respectsDaylightSaving = TRUE)
  )
}

fixture_features <- function(ids = c(3L, 1L, 5L, 2L, 4L)) {
  lapply(ids, function(id) {
    list(attributes = list(
      OBJECTID = id, RECORD_ID = paste0("synthetic-", id),
      PROJECTSTATUS = if (id %% 2L) "Issued" else "Review",
      LASTUPDATE = as.numeric(id) * 1000, CREATEDDATE = NULL,
      NEWCONSTRUCTIONSF = as.integer(100 + id), COST = id * 10.5,
      TENTATIVEHEARING = "09/29/2026", GlobalID = paste0("synthetic-guid-", id)
    ), geometry = list(x = -9170000 + id, y = 3250000 + id))
  })
}

fixture_response <- function(payload, status = 200L) {
  list(status = status,
       body = as.character(jsonlite::toJSON(payload, auto_unbox = TRUE,
                                            null = "null", digits = NA)))
}

# The default server returns unordered batches in its own storage order.
# Ordered queries sort by the actual requested fields and directions.
# A transform can deliberately inject realistic service faults into one stage.
fixture_transport <- function(features = fixture_features(),
                              metadata = fixture_metadata(),
                              count = length(features),
                              ids = NULL,
                              transform = NULL) {
  oid <- metadata$objectIdField %||% metadata$objectIdFieldName
  if (is.null(oid)) {
    oid_fields <- Filter(function(x) identical(x$type, "esriFieldTypeOID"), metadata$fields)
    if (length(oid_fields) == 1L) oid <- oid_fields[[1L]]$name
  }
  feature_oid <- if (length(features) && !is.null(oid) &&
                     !is.null(features[[1L]]$attributes[[oid]])) oid else "OBJECTID"
  if (is.null(ids)) {
    ids <- vapply(features, function(x) x$attributes[[feature_oid]], numeric(1))
  }
  state <- new.env(parent = emptyenv())
  state$requests <- list()
  http <- function(url, params, timeout) {
    state$requests[[length(state$requests) + 1L]] <-
      list(url = url, params = params, timeout = timeout)
    if (!grepl("/query$", url)) {
      payload <- metadata
    } else if (identical(params$returnCountOnly, "true")) {
      payload <- list(count = count)
    } else if (identical(params$returnIdsOnly, "true")) {
      payload <- list(objectIdFieldName = oid,
                      objectIds = as.list(ids))
    } else {
      selected <- features
      if (!is.null(params$objectIds)) {
        requested <- as.numeric(strsplit(params$objectIds, ",", fixed = TRUE)[[1L]])
        selected <- Filter(function(x) x$attributes[[oid]] %in% requested, selected)
      }
      if (!is.null(params$orderByFields)) {
        terms <- trimws(strsplit(params$orderByFields, ",", fixed = TRUE)[[1L]])
        keys <- lapply(terms, function(term) {
          field <- sub("[[:space:]]+(ASC|DESC)$", "", term, ignore.case = TRUE)
          values <- vapply(selected, function(x) as.character(x$attributes[[field]]),
                           character(1))
          if (identical(field, oid)) values <- as.numeric(values)
          key <- xtfrm(values)
          if (grepl("[[:space:]]DESC$", term, ignore.case = TRUE)) -key else key
        })
        selected <- selected[do.call(order, keys)]
        offset <- as.integer(params$resultOffset %||% 0)
        size <- as.integer(params$resultRecordCount %||% length(selected))
        selected <- if (offset < length(selected))
          selected[seq.int(offset + 1L, min(offset + size, length(selected)))] else list()
      }
      if (!is.null(params$outFields) && !identical(params$outFields, "*")) {
        names_requested <- strsplit(params$outFields, ",", fixed = TRUE)[[1L]]
        selected <- lapply(selected, function(feature) {
          feature$attributes <- feature$attributes[
            intersect(names(feature$attributes), names_requested)]
          feature
        })
      }
      if (!identical(params$returnGeometry, "true")) {
        selected <- lapply(selected, function(feature) {
          feature$geometry <- NULL
          feature
        })
      }
      payload <- list(objectIdFieldName = oid, features = selected)
      if (identical(params$returnGeometry, "true")) {
        payload$geometryType <- metadata$geometryType
        payload$spatialReference <- if (!is.null(params$outSR))
          list(wkid = as.numeric(params$outSR)) else metadata$extent$spatialReference
      }
      if (!is.null(params$orderByFields)) {
        payload$exceededTransferLimit <-
          as.numeric(params$resultOffset %||% 0) + length(selected) < length(features)
      }
    }
    if (!is.null(transform)) {
      payload <- transform(payload, params, url, length(state$requests))
    }
    fixture_response(payload)
  }
  list(http = http, state = state)
}

fixture_queries <- function(transport, type = c("all", "features", "ids", "count")) {
  type <- match.arg(type)
  requests <- Filter(function(x) grepl("/query$", x$url), transport$state$requests)
  if (type == "all") return(requests)
  Filter(function(x) {
    if (type == "count") return(identical(x$params$returnCountOnly, "true"))
    if (type == "ids") return(identical(x$params$returnIdsOnly, "true"))
    is.null(x$params$returnCountOnly) && is.null(x$params$returnIdsOnly)
  }, requests)
}

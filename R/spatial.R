# ArcGIS geometry is decoded by GDAL, rather than by hand-written ring logic.
# Reading a local file also prevents GDAL from making its own paginated requests.
arcgis_as_sf <- function(data, features, metadata, spatial_reference = NULL,
                         out_sr = NULL) {
  if (!arcgis_has_sf()) {
    .abort("Spatial results require the optional 'sf' package. Install it with install.packages('sf'), or request a table with spatial = FALSE.",
           subclass = "tampa_spatial_error")
  }
  if (!is.data.frame(data) || !is.list(features) ||
      length(features) != nrow(data)) {
    .abort("ArcGIS geometry and parsed data have different row counts.",
           subclass = "tampa_spatial_error")
  }

  geometry_type <- metadata[["geometryType"]]
  supported <- c("esriGeometryPoint", "esriGeometryMultipoint",
                 "esriGeometryPolyline", "esriGeometryPolygon")
  if (!is.character(geometry_type) || length(geometry_type) != 1L ||
      is.na(geometry_type) || !geometry_type %in% supported) {
    .abort("This layer has no supported spatial geometry type. Request a table with spatial = FALSE.",
           subclass = "tampa_spatial_error")
  }

  # A requested output reference is not evidence of a coordinate-bearing
  # response's CRS. An empty result can use the requested CRS because there are
  # no coordinates to relabel, and its eventual spatial schema remains useful.
  reference <- spatial_reference
  if (is.null(reference) && !is.null(out_sr) && nrow(data) == 0L) {
    reference <- list(wkid = out_sr)
  }
  if (is.null(reference) && is.null(out_sr)) {
    reference <- arcgis_native_reference(metadata)
  }
  crs <- arcgis_spatial_crs(reference)
  if (!is.null(out_sr)) {
    requested_crs <- arcgis_spatial_crs(list(wkid = out_sr))
    if (!isTRUE(crs == requested_crs)) {
      .abort("The ArcGIS response CRS differs from the requested out_sr.",
             subclass = "tampa_spatial_error")
    }
  }

  geometries <- lapply(seq_along(features), function(i) {
    feature <- features[[i]]
    if (!is.list(feature)) {
      .abort(sprintf("Malformed ArcGIS feature at row %d.", i),
             subclass = "tampa_spatial_error")
    }
    geometry <- feature[["geometry"]]
    geometry_reference <- if (is.list(geometry)) geometry[["spatialReference"]] else NULL
    if (!is.null(geometry_reference) &&
        !isTRUE(arcgis_spatial_crs(geometry_reference) == crs)) {
      .abort(sprintf("ArcGIS geometry at row %d has a different CRS from the response.", i),
             subclass = "tampa_spatial_error")
    }
    arcgis_geometry_2d(geometry, geometry_type, i)
  })
  missing <- vapply(geometries, is.null, logical(1))

  if (!length(geometries) || all(missing)) {
    # Construct a typed prototype first so a zero-row result keeps its type.
    prototype <- sf::st_sfc(lapply(seq_len(max(1L, length(features))), function(i) {
      arcgis_empty_geometry(geometry_type)
    }), crs = crs)
    geometry <- prototype[seq_along(features)]
    # Older sf versions generalize an empty subset to sfc_GEOMETRY.
    if (!length(features)) class(geometry) <- class(prototype)
    return(arcgis_attach_geometry(data, geometry))
  }

  geometry <- arcgis_decode_geometry(geometries, geometry_type, crs, missing)
  arcgis_attach_geometry(data, geometry)
}

arcgis_native_reference <- function(metadata) {
  extent <- metadata[["extent"]]
  extent_reference <- if (is.list(extent)) extent[["spatialReference"]] else NULL
  metadata[["spatialReference"]] %||% extent_reference %||%
    metadata[["sourceSpatialReference"]]
}

# The only attribute passed through GDAL is an internal row number. All user
# columns, including POSIXct dates and list columns, come from the parsed data.
arcgis_decode_geometry <- function(geometries, geometry_type, crs, missing) {
  rows <- seq_along(geometries)
  payload <- list(
    geometryType = geometry_type,
    spatialReference = list(wkt = crs$wkt),
    hasZ = FALSE,
    hasM = FALSE,
    fields = list(list(name = "tampa_row_id", type = "esriFieldTypeInteger",
                       alias = "tampa_row_id")),
    features = lapply(rows, function(i) {
      list(attributes = list(tampa_row_id = i), geometry = geometries[[i]])
    })
  )
  path <- tempfile("tampa-geometry-", fileext = ".json")
  on.exit(unlink(path), add = TRUE)
  jsonlite::write_json(payload, path, auto_unbox = TRUE, null = "null",
                       digits = NA)
  decoded <- tryCatch(
    arcgis_read_esrijson(path),
    error = function(e) {
      .abort(paste0("GDAL could not decode the ArcGIS geometry: ",
                    conditionMessage(e)), subclass = "tampa_spatial_error")
    }
  )
  if (!inherits(decoded, "sf") || nrow(decoded) != length(rows) ||
      !"tampa_row_id" %in% names(decoded) ||
      !is.numeric(decoded$tampa_row_id) ||
      anyNA(decoded$tampa_row_id) || anyDuplicated(decoded$tampa_row_id) ||
      !setequal(decoded$tampa_row_id, rows)) {
    .abort("GDAL dropped, duplicated, or changed ArcGIS geometry rows.",
           subclass = "tampa_spatial_error")
  }
  decoded <- decoded[match(rows, decoded$tampa_row_id), ]
  geometry <- sf::st_geometry(decoded)
  if (is.na(sf::st_crs(geometry)) || !isTRUE(sf::st_crs(geometry) == crs)) {
    .abort("GDAL did not retain the verified ArcGIS response CRS.",
           subclass = "tampa_spatial_error")
  }
  actual_types <- as.character(sf::st_geometry_type(geometry))
  allowed_types <- switch(geometry_type,
    esriGeometryPoint = "POINT",
    esriGeometryMultipoint = "MULTIPOINT",
    esriGeometryPolyline = c("LINESTRING", "MULTILINESTRING"),
    esriGeometryPolygon = c("POLYGON", "MULTIPOLYGON")
  )
  if (any(!missing & !actual_types %in% allowed_types) ||
      any(!missing & sf::st_is_empty(geometry))) {
    .abort("GDAL returned an empty or unexpected type for a nonempty ArcGIS geometry.",
           subclass = "tampa_spatial_error")
  }
  # Keep absent geometry rows as typed EMPTY geometries. No validity repair,
  # coordinate transformation, ring closure, or simplification is performed.
  pieces <- lapply(seq_along(geometry), function(i) {
    if (missing[[i]]) arcgis_empty_geometry(geometry_type) else geometry[[i]]
  })
  sf::st_sfc(pieces, crs = crs)
}

arcgis_read_esrijson <- function(path) {
  sf::st_read(paste0("ESRIJSON:", path), quiet = TRUE,
              stringsAsFactors = FALSE)
}

arcgis_has_sf <- function() {
  requireNamespace("sf", quietly = TRUE)
}

arcgis_attach_geometry <- function(data, geometry) {
  # A source field named 'geometry' must survive unchanged.
  name <- "geometry"
  while (name %in% names(data)) name <- paste0(".", name)
  data[[name]] <- geometry
  sf::st_as_sf(data, sf_column_name = name)
}

arcgis_empty_geometry <- function(type) {
  switch(type,
    esriGeometryPoint = sf::st_point(c(NA_real_, NA_real_)),
    esriGeometryMultipoint = sf::st_multipoint(matrix(numeric(), ncol = 2L)),
    esriGeometryPolyline = sf::st_multilinestring(list()),
    esriGeometryPolygon = sf::st_multipolygon(list())
  )
}

arcgis_spatial_crs <- function(reference) {
  if (!is.list(reference) || !length(reference)) {
    .abort("The ArcGIS response has no known spatial reference; coordinates cannot be labelled safely. If out_sr is requested, the response must identify its output CRS.",
           subclass = "tampa_spatial_error")
  }
  resolved <- list()
  # Custom definitions may have only WKT. Prefer the explicit definition when
  # present, and otherwise use latestWkid before the original ArcGIS alias.
  if (!is.null(reference[["wkt"]])) {
    wkt <- .inline_arcgis_wkt(reference[["wkt"]])
    resolved$wkt <- .resolve_arcgis_crs(list(wkt))
  }
  for (field in c("latestWkid", "wkid")) {
    code <- reference[[field]]
    if (is.null(code)) next
    if (!is.numeric(code) || length(code) != 1L || is.na(code) ||
        !is.finite(code) || code <= 0 || code != floor(code)) {
      .abort("The ArcGIS spatial reference contains a malformed WKID.",
             subclass = "tampa_spatial_error")
    }
    aliases <- c(`102100` = 3857L, `102113` = 3857L, `102659` = 2237L,
                 `103023` = 6443L)
    candidates <- list(paste0("EPSG:", format(code, scientific = FALSE)),
                       paste0("ESRI:", format(code, scientific = FALSE)))
    if (as.character(code) %in% names(aliases)) {
      candidates <- c(list(unname(aliases[as.character(code)])), candidates)
    }
    resolved[[field]] <- .resolve_arcgis_crs(candidates)
  }
  known <- Filter(Negate(is.null), resolved[c("latestWkid", "wkid")])
  if (length(known) == 2L && !isTRUE(known[[1L]] == known[[2L]])) {
    .abort("The ArcGIS spatial reference contains conflicting WKID identifiers.",
           subclass = "tampa_spatial_error")
  }
  crs <- resolved[["wkt"]] %||% resolved[["latestWkid"]] %||% resolved[["wkid"]]
  if (!is.null(crs)) return(crs)
  .abort("The ArcGIS spatial reference could not be resolved by sf/GDAL.",
         subclass = "tampa_spatial_error")
}

.inline_arcgis_wkt <- function(wkt) {
  roots <- c("GEOGCS", "GEOCCS", "PROJCS", "VERT_CS", "COMPD_CS", "LOCAL_CS",
             "GEODCRS", "GEOGCRS", "GEODETICCRS", "GEOGRAPHICCRS", "PROJCRS",
             "PROJECTEDCRS", "VERTCRS", "VERTICALCRS", "COMPOUNDCRS", "ENGCRS",
             "ENGINEERINGCRS", "BOUNDCRS", "DERIVEDPROJCRS", "COORDINATEMETADATA")
  pattern <- paste0("^(", paste(roots, collapse = "|"), ")[[:space:]]*(\\[|\\()")
  if (!is.character(wkt) || length(wkt) != 1L || is.na(wkt) ||
      !grepl(pattern, trimws(wkt), ignore.case = TRUE)) {
    .abort("The ArcGIS spatial reference contains malformed WKT; an inline coordinate-system definition is required.",
           subclass = "tampa_spatial_error")
  }
  # sf/GDAL accepts filenames and URLs as CRS inputs. Remote metadata must
  # enter its WKT parser rather than those file and network lookup paths.
  trimws(wkt)
}

.resolve_arcgis_crs <- function(candidates) {
  for (candidate in candidates) {
    crs <- tryCatch(suppressWarnings(sf::st_crs(candidate)),
                    error = function(e) NULL)
    if (!is.null(crs) && !is.na(crs)) return(crs)
  }
  NULL
}

# Validate JSON structure before GDAL can turn malformed geometry into NULL.
# Only the XY components are retained because spatial retrieval is explicitly 2D.
arcgis_geometry_2d <- function(geometry, type, row) {
  fail <- function(detail) {
    .abort(sprintf("Malformed ArcGIS geometry at row %d: %s", row, detail),
           subclass = "tampa_spatial_error")
  }
  if (is.null(geometry)) return(NULL)
  if (!is.list(geometry) || is.null(names(geometry))) {
    fail("expected a geometry object.")
  }
  geometry_keys <- intersect(names(geometry),
                             c("x", "y", "points", "paths", "rings",
                               "curvePaths", "curveRings", "xmin", "xmax"))
  expected_keys <- switch(type,
    esriGeometryPoint = c("x", "y"),
    esriGeometryMultipoint = "points",
    esriGeometryPolyline = "paths",
    esriGeometryPolygon = "rings"
  )
  if (any(!geometry_keys %in% expected_keys)) {
    fail("geometry does not match the layer type, or contains unsupported curves.")
  }
  scalar <- function(x) is.numeric(x) && length(x) == 1L &&
    !is.na(x) && is.finite(x)
  if (type == "esriGeometryPoint") {
    if (!"x" %in% names(geometry)) fail("point has no x coordinate.")
    x <- geometry[["x"]]
    y <- geometry[["y"]]
    if (is.null(x) && is.null(y)) return(NULL)
    if (!scalar(x) || !scalar(y)) {
      fail("point coordinates must be finite numbers.")
    }
    return(list(x = x, y = y))
  }
  key <- expected_keys[[1L]]
  if (!key %in% names(geometry) || !is.list(geometry[[key]]) ||
      !is.null(names(geometry[[key]]))) {
    fail(paste0("expected a ", key, " array."))
  }
  parts <- geometry[[key]]
  if (!length(parts)) return(NULL)
  parts <- arcgis_array_geometry_2d(parts, type, fail, scalar)
  if (!length(parts)) return(NULL)
  result <- list(parts)
  names(result) <- key
  result
}

# Multipoint arrays contain coordinates directly; path and ring arrays contain
# another level of parts. Validate each shape before discarding its Z/M values.
arcgis_array_geometry_2d <- function(parts, type, fail, scalar) {
  xy <- function(coordinate) {
    if (!(is.list(coordinate) || is.numeric(coordinate)) ||
        !is.null(names(coordinate)) ||
        length(coordinate) < 2L || length(coordinate) > 4L ||
        !scalar(coordinate[[1L]]) || !scalar(coordinate[[2L]])) {
      fail("coordinate arrays must contain finite numeric x and y values.")
    }
    c(coordinate[[1L]], coordinate[[2L]])
  }
  if (type == "esriGeometryMultipoint") {
    points <- lapply(parts, function(coordinate) {
      # The ArcGIS specification excludes an empty point inside a multipoint.
      if (is.list(coordinate) && is.null(names(coordinate)) &&
          length(coordinate) >= 2L && length(coordinate) <= 4L &&
          all(vapply(coordinate, is.null, logical(1)))) return(NULL)
      xy(coordinate)
    })
    return(Filter(Negate(is.null), points))
  }
  lapply(parts, function(part) {
    if (!is.list(part) || !is.null(names(part)) || length(part) < 2L) {
      fail("each path or ring must contain enough coordinate pairs.")
    }
    points <- lapply(part, xy)
    if (type == "esriGeometryPolygon" &&
        (length(points) < 4L || !all(points[[1L]] == points[[length(points)]]))) {
      fail("polygon rings must contain at least four coordinates and be closed.")
    }
    points
  })
}

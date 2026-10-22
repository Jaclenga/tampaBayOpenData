`%||%` <- function(x, y) if (is.null(x)) y else x

# Error context may include publisher URLs or URLs supplied by callers. Keep
# the location useful while omitting URL credentials and query parameters.
.error_context_url <- function(url) {
  if (!is.character(url) || length(url) != 1L || is.na(url)) return("[unavailable]")
  if (!grepl("^[A-Za-z][A-Za-z0-9+.-]*://", url)) return(url)
  url <- sub("[?#].*$", "", url)
  sub("^([A-Za-z][A-Za-z0-9+.-]*://)[^/]*@", "\\1", url)
}

.error_context_publisher <- function(publisher) {
  if (!is.character(publisher) || length(publisher) != 1L || is.na(publisher)) {
    return("[unavailable]")
  }
  if (nchar(publisher, type = "bytes") > 120L ||
      grepl("://|[[:cntrl:]?#@=]", publisher)) return("[redacted]")
  publisher
}

.abort <- function(message, dataset = NULL, url = NULL, subclass = NULL) {
  if (!is.null(dataset)) {
    message <- paste0("Dataset `", .error_context_url(dataset$id), "`: ", message,
                      "\nPublisher: ", .error_context_publisher(dataset$publisher),
                      "\nSource: ", .error_context_url(dataset$source_url))
  }
  if (!is.null(url)) {
    url <- .error_context_url(url)
    message <- paste0(message, "\nEndpoint: ", url)
  }
  dataset_id <- if (is.null(dataset)) NULL else .error_context_url(dataset$id)
  stop(errorCondition(message, class = c(subclass, "tampa_data_error"),
                      dataset_id = dataset_id, url = url))
}

.string <- function(x, name, allow_empty = FALSE) {
  if (!is.character(x) || length(x) != 1L || is.na(x) ||
      (!allow_empty && !nzchar(trimws(x)))) {
    .abort(paste0("`", name, "` must be a single nonmissing string."),
           subclass = "tampa_input_error")
  }
  invisible(x)
}

.flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    .abort(paste0("`", name, "` must be TRUE or FALSE."),
           subclass = "tampa_input_error")
  }
  invisible(x)
}

.number <- function(x, name, min = 0, integer = FALSE, infinity = FALSE) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || x < min ||
      (!infinity && !is.finite(x)) ||
      (integer && is.finite(x) && x != floor(x))) {
    received <- if (is.numeric(x) && length(x) == 1L && !is.na(x) &&
                    !is.object(x) &&
                    nchar(as.character(x), type = "bytes") <= 32L) {
      paste0("; received ", as.character(x))
    } else {
      ""
    }
    .abort(paste0("`", name, "` must be ", if (integer) "a whole number" else "numeric",
                  " >= ", min, if (infinity) " (or Inf)" else "", received, "."),
           subclass = "tampa_input_error")
  }
  invisible(x)
}

.field_names <- function(metadata) {
  vapply(metadata$fields, function(x) x$name, character(1))
}

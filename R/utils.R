`%||%` <- function(x, y) if (is.null(x)) y else x

.abort <- function(message, dataset = NULL, url = NULL, subclass = NULL) {
  if (!is.null(dataset)) {
    message <- paste0("Dataset `", dataset$id, "`: ", message,
                      "\nPublisher: ", dataset$publisher,
                      "\nSource: ", dataset$source_url)
  }
  if (!is.null(url)) message <- paste0(message, "\nEndpoint: ", url)
  stop(errorCondition(message, class = c(subclass, "tampa_data_error"),
                      dataset_id = dataset$id, url = url))
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
    .abort(paste0("`", name, "` must be ", if (integer) "a whole number" else "numeric",
                  " >= ", min, if (infinity) " (or Inf)" else "", "."),
           subclass = "tampa_input_error")
  }
  invisible(x)
}

.field_names <- function(metadata) {
  vapply(metadata$fields, function(x) x$name, character(1))
}

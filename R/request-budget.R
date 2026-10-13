# Carry one monotonic deadline through existing request arguments. No session
# options or package-global mutable state are needed, including for nested calls.
.operation_clock <- function() unname(proc.time()[["elapsed"]])

.operation_timeout <- function(timeout, total_timeout) {
  .number(timeout, "timeout", min = 0.001)
  .number(total_timeout, "total_timeout", min = .Machine$double.eps, infinity = TRUE)
  deadline <- min(attr(timeout, "tampa_deadline", exact = TRUE) %||% Inf,
                  .operation_clock() + total_timeout)
  timeout <- as.numeric(timeout)
  if (is.finite(deadline)) attr(timeout, "tampa_deadline") <- deadline
  timeout
}

.operation_remaining <- function(timeout) {
  deadline <- attr(timeout, "tampa_deadline", exact = TRUE)
  if (is.null(deadline)) Inf else deadline - .operation_clock()
}

.check_operation_timeout <- function(timeout, dataset = NULL, url = NULL) {
  if (.operation_remaining(timeout) <= 0) {
    .abort("The operation exceeded `total_timeout`. Narrow the request, increase the budget, or use a resumable download.",
           dataset, url, "tampa_timeout_error")
  }
  invisible(timeout)
}

.operation_sleep <- function(seconds) Sys.sleep(seconds)

.operation_retry_wait <- function(delay, timeout, dataset = NULL, url = NULL) {
  .check_operation_timeout(timeout, dataset, url)
  if (delay >= .operation_remaining(timeout)) {
    .abort("The remaining operation time budget is too short for another retry.",
           dataset, url, "tampa_timeout_error")
  }
  .operation_sleep(delay)
  .check_operation_timeout(timeout, dataset, url)
}

# Keep one HTTP retry path for requests with and without an operation deadline.
# A fresh transfer timeout is calculated after every backoff wait.
.perform_arcgis_http <- function(req, timeout, url) {
  max_retries <- .arcgis_max_retries()
  for (attempt in seq_len(max_retries + 1L)) {
    .check_operation_timeout(timeout, url = url)
    remaining <- .operation_remaining(timeout)
    if (remaining < 0.001) {
      .abort("The remaining operation time budget is too short for another HTTP attempt.",
             url = url, subclass = "tampa_timeout_error")
    }
    current <- httr2::req_timeout(req, min(as.numeric(timeout), remaining))
    response <- tryCatch(httr2::req_perform(current), error = identity)
    .check_operation_timeout(timeout, url = url)
    failed <- inherits(response, "error")
    if (failed && !.arcgis_retryable_transport_error(response)) stop(response)
    transient <- failed || .arcgis_retryable_status(httr2::resp_status(response))
    if (!transient || attempt > max_retries) {
      if (failed) {
        .abort(paste0("A transient connection failure or timeout persisted after ",
                      attempt, " HTTP attempt(s) (", attempt - 1L,
                      " retries): ", conditionMessage(response)),
               url = url, subclass = "tampa_http_error")
      }
      return(list(response = response, attempts = attempt))
    }
    delay <- if (failed) NA_real_ else .bounded_retry_after(response)
    if (is.na(delay)) delay <- .arcgis_backoff(attempt)
    if (delay > 30) {
      return(list(response = response, attempts = attempt,
                  retry_after = delay))
    }
    .operation_retry_wait(delay, timeout, url = url)
  }
}

.arcgis_retryable_transport_error <- function(error) {
  if (!inherits(error, c("httr2_failure", "curl_error"))) return(FALSE)
  code <- error$code
  if (is.numeric(code) && length(code) == 1L && is.finite(code)) {
    # libcurl codes for temporary DNS/connect/transfer/timeout failures.
    return(code %in% c(5, 6, 7, 18, 28, 35, 52, 55, 56))
  }
  TRUE
}

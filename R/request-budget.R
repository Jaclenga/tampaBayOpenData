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

# A fresh transfer timeout is calculated for every attempt. Letting httr2 retry
# one request internally would reuse its original timeout after backoff waits.
.perform_budgeted_request <- function(req, timeout, url) {
  for (attempt in seq_len(3L)) {
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
    if (failed && !inherits(response, c("httr2_failure", "curl_error"))) stop(response)
    transient <- failed || httr2::resp_status(response) %in%
      c(429L, 500L, 502L, 503L, 504L)
    if (!transient || attempt == 3L) {
      if (failed) stop(response)
      return(response)
    }
    delay <- if (failed) NA_real_ else .bounded_retry_after(response)
    if (is.na(delay)) delay <- stats::runif(1L, 1, 2^attempt)
    .operation_retry_wait(delay, timeout, url = url)
  }
}

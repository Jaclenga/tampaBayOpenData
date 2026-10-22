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
    .abort("The request exceeded `total_timeout`, its overall time limit. Try a smaller request or increase `total_timeout`. For large datasets, use `tbod_download_dataset()` to resume work.",
           dataset, url, "tampa_timeout_error")
  }
  invisible(timeout)
}

.operation_sleep <- function(seconds) Sys.sleep(seconds)

.operation_retry_wait <- function(delay, timeout, dataset = NULL, url = NULL) {
  .check_operation_timeout(timeout, dataset, url)
  if (delay >= .operation_remaining(timeout)) {
    .abort("The remaining operation time budget is too short for another retry. Increase `total_timeout` or try again later.",
           dataset, url, "tampa_timeout_error")
  }
  .operation_sleep(delay)
  .check_operation_timeout(timeout, dataset, url)
}

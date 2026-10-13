# Fail immediately if an ordinary test accidentally attempts live HTTP.
# Individual transport tests replace this binding with deterministic responses.
# Only the explicit opt-in live test run can use the real network transport.
# Retry tests replace the dispatch and sleep sinks with deterministic mocks.
if (!identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  testthat::local_mocked_bindings(
    req_perform = function(...) {
      stop("Live HTTP is disabled in the offline test suite. Mock the transport or explicitly set TAMPA_OPEN_DATA_LIVE=true.",
           call. = FALSE)
    },
    .package = "httr2",
    .env = testthat::teardown_env()
  )
}

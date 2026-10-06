#' List the configured public ArcGIS publishers
#'
#' Reads the bundled publisher registry without network requests. Each publisher
#' supplies one organization ID and sharing API root to the same discovery and
#' retrieval code. The `verified` date records an identity check against public
#' organization metadata and official publisher evidence; it does not validate
#' every layer, its contents, or its reuse terms. Layer provenance distinguishes
#' discovered services from the package's checked dataset registry.
#'
#' @return A tibble with `id` (the discovery selector), `root`, `org_id`,
#'   `publisher`, `jurisdiction`, `website`, `verified` (a Date), `metadata_url`,
#'   and `evidence_url`. Use `id` values in the `portals` argument of
#'   [list_datasets()] or [search_datasets()].
#' @export
#' @examples
#' list_portals()
list_portals <- function() {
  entries <- .portal_registry()
  columns <- lapply(names(entries[[1L]]), function(name) {
    unname(vapply(entries, `[[`, character(1), name))
  })
  names(columns) <- names(entries[[1L]])
  columns$verified <- as.Date(columns$verified)
  tibble::as_tibble(columns)
}

# Publisher additions belong in this single bundled configuration. Do not copy
# organization IDs into retrieval branches or expose mutable process options.
.portal_registry <- function() {
  path <- system.file("extdata", "portals.json", package = "tampaBayOpenData")
  if (!nzchar(path)) .abort("The bundled portal registry is missing. Reinstall the package.")
  entries <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) .abort("The bundled portal registry is invalid JSON."))
  .validate_portals(entries)
  stats::setNames(entries, vapply(entries, `[[`, character(1), "id"))
}

# User-supplied portals use the same public-HTTPS boundary as direct layer
# URLs. Keep this separate from the bundled registry's verification metadata:
# an arbitrary portal has no package-verified publisher identity.
.custom_portal_root <- function(portal) {
  .string(portal, "portal")
  match <- regmatches(portal, regexec(
    "^https://([^/?#@]+)(/[^?#]*)$", portal, perl = TRUE))[[1L]]
  if (length(match) != 3L || !endsWith(portal, "/sharing/rest") ||
      grepl("[[:space:]\\\\%]", portal)) {
    .abort("`portal` must be a public HTTPS ArcGIS root ending in /sharing/rest.",
           subclass = "tampa_input_error")
  }
  host <- match[[2L]]
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$", host) ||
      grepl("\\.\\.|^[0-9.]+$|(^|\\.)localhost$|\\.(local|internal|home|lan)$",
            host, ignore.case = TRUE)) {
    .abort("`portal` must use a public DNS host.", subclass = "tampa_input_error")
  }
  segments <- strsplit(sub("^/", "", match[[3L]]), "/", fixed = TRUE)[[1L]]
  if (any(!nzchar(segments)) || any(segments %in% c(".", "..")) ||
      any(!grepl("^[A-Za-z0-9._~-]+$", segments))) {
    .abort("`portal` must use ordinary path segments.", subclass = "tampa_input_error")
  }
  portal
}

.validate_portals <- function(entries) {
  required <- c("id", "root", "org_id", "publisher", "jurisdiction", "website",
                "verified", "metadata_url", "evidence_url")
  if (!is.list(entries) || !length(entries) || !is.null(names(entries))) {
    .abort("The portal registry must contain an array of publisher records.")
  }
  for (entry in entries) {
    if (!is.list(entry) || anyDuplicated(names(entry)) ||
        !setequal(names(entry), required)) {
      .abort("A portal registry record must contain the documented metadata fields.")
    }
    for (name in required) .string(entry[[name]], paste0("portal.", name))
    if (!grepl("^[a-z][a-z0-9]*(-[a-z0-9]+)*$", entry$id) ||
        entry$id %in% c("all", "global")) {
      .abort("Portal IDs must be stable slugs other than the reserved selectors all and global.")
    }
    if (!grepl("^[A-Za-z0-9]{16}$", entry$org_id)) {
      .abort("Portal organization IDs must contain 16 alphanumeric characters.")
    }
    if (!grepl("^[a-z][a-z0-9]*(-[a-z0-9]+)*$", entry$jurisdiction) ||
        identical(entry$jurisdiction, "all")) {
      .abort("Portal jurisdictions must be stable slugs other than all.")
    }
    if (!grepl("^https://[A-Za-z0-9][A-Za-z0-9.-]+(/[-A-Za-z0-9._~]+)*/sharing/rest$",
               entry$root) ||
        grepl("\\.\\.|(^|/)\\.(/|$)", entry$root)) {
      .abort("Portal roots must be HTTPS sharing API roots ending in /sharing/rest.")
    }
    for (name in c("website", "metadata_url", "evidence_url")) {
      if (!grepl("^https://[A-Za-z0-9][A-Za-z0-9.-]+(/[^[:space:]?#\\\\]*)?$",
                 entry[[name]])) {
        .abort("Portal website and evidence URLs must use HTTPS without credentials or query parameters.")
      }
    }
    if (!entry$metadata_url %in% paste0(entry$root, "/portals/",
                                        c("self", entry$org_id))) {
      .abort("Portal metadata URLs must identify the configured sharing root and organization.")
    }
    date <- suppressWarnings(as.Date(entry$verified, format = "%Y-%m-%d"))
    if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", entry$verified) || is.na(date) ||
        !identical(format(date, "%Y-%m-%d"), entry$verified)) {
      .abort("Portal verification dates must use valid YYYY-MM-DD dates.")
    }
  }
  for (name in c("id", "org_id")) {
    if (anyDuplicated(tolower(vapply(entries, `[[`, character(1), name)))) {
      .abort(paste0("Portal registry ", name, " values must be unique."))
    }
  }
  invisible(TRUE)
}

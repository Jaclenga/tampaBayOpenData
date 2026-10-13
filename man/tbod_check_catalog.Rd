\name{tbod_check_catalog}
\alias{tbod_check_catalog}
\title{Check the current health of checked catalog layers}
\usage{
tbod_check_catalog(
  jurisdiction = "all",
  ids = NULL,
  timeout = 10,
  total_timeout = 1800,
  pause = 0.25
)
}
\arguments{
\item{jurisdiction}{One checked-catalog jurisdiction code or \code{"all"}.}

\item{ids}{Optional nonempty vector of unique checked dataset IDs within
\code{jurisdiction}; \code{NULL} checks all selected entries.}

\item{timeout}{Per-HTTP-attempt timeout in seconds.}

\item{total_timeout}{Maximum elapsed seconds for the complete check,
including requests, retries, and pauses. Defaults to 1,800; \code{Inf}
disables the overall deadline. Entries not reached are reported as
\code{unknown}.}

\item{pause}{Delay from 0 to 30 seconds between entries to limit request
rate; defaults to 0.25.}
}
\value{
A tibble with one row per selected entry and \code{publisher},
\code{jurisdiction}, \code{dataset_id}, \code{endpoint}, \code{checked_at} (UTC POSIXct),
\code{status} (\code{healthy}, \code{unavailable}, \code{schema_changed}, \code{unsupported}, or
\code{unknown}), \code{failure_type}, \code{http_status}, \code{service_status},
and \code{layer_status} (\code{available}, \code{unavailable}, or \code{unknown}),
\code{schema_status} (\code{unchanged}, \code{compatible}, \code{incompatible}, or
\code{unavailable}), \code{schema_issues} (a list of issue tibbles), and
\code{details}. \code{http_status} is missing when no HTTP response was received.
}
\description{
Checks current public ArcGIS endpoints and saved schemas for selected
entries in the bundled checked catalog. It contacts publisher services and
returns a report without changing the catalog or saving files. A healthy
result is a point-in-time metadata check, not a measure of record freshness.
}
\details{
Each entry starts one layer-metadata request. The client probes the
service root only after a missing-layer response (HTTP or ArcGIS 404/410,
or an explicit layer-not-found error) to distinguish a missing layer from
a missing service. Transient failures remain \code{unknown}
after bounded retries; entries not reached before \code{total_timeout} are also
\code{unknown}. The default retry limit is three additional attempts per
retryable failure sequence. Set
\code{options(tampaBayOpenData.max_retries = 3L)} to change it (whole number
from 0 to 10).

\code{healthy} means the layer metadata is valid, Query is advertised, and the
schema matches the saved snapshot. \code{schema_changed} includes both
compatible and incompatible drift; inspect \code{schema_status} and
\code{schema_issues}. Confirmed schema drift remains \code{schema_changed} if Query
capability is unreported. A missing object-ID field is reported as schema
drift when a baseline exists; the details also identify unsupported record
retrieval. With no saved baseline, \code{schema_status} is
\code{unavailable} and \code{status} is \code{unknown}. \code{unsupported} includes layers
that cannot be queried and access failures. This check does not retrieve
features or run count and object-ID queries. A layer can advertise Query
yet fail those operations during retrieval. The result cannot guarantee
future service availability.
}
\examples{
if (identical(Sys.getenv("TAMPA_OPEN_DATA_LIVE"), "true")) {
  report <- tbod_check_catalog(ids = "construction-permits")
  report[, c("dataset_id", "status", "schema_status", "details")]
}
}

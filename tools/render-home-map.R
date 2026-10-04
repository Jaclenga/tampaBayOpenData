# Rebuild the static map shown on the pkgdown homepage and README.
# Run from the package root after installing tampaBayOpenData and sf:
#   Rscript tools/render-home-map.R
# This script makes live requests only when run explicitly. pkgdown reads the
# committed PNG and never contacts the City of Tampa to render the homepage.
#
# Source: City of Tampa checked layers `city-boundary` and `capital-projects`.
# https://tampa.maps.arcgis.com/home/item.html?id=ed03de89b95340359431d13bd2bc38f2
# https://tampa.maps.arcgis.com/home/item.html?id=2226a20de08641e38cedd1c2d7cac69e
# Both ArcGIS items state CC0 in their licenseInfo, as recorded in the checked
# registry. Review current source terms before republishing a regenerated map.
# City Conditions and Use do not guarantee accuracy or completeness. The
# boundary is a shoreline-adjusted map representation, not a legal survey.

if (!file.exists("DESCRIPTION") || !dir.exists("man")) {
  stop("Run this script from the tampaBayOpenData package root.")
}
if (dir.exists(".library")) {
  .libPaths(c(normalizePath(".library"), .libPaths()))
}
if (!requireNamespace("tampaBayOpenData", quietly = TRUE) ||
    !requireNamespace("sf", quietly = TRUE)) {
  stop("Install tampaBayOpenData and sf before regenerating the map.")
}

for (id in c("city-boundary", "capital-projects")) {
  info <- tampaBayOpenData::dataset_info(id)
  if (!identical(info$license_info, "CC0")) {
    stop("Review data reuse terms before rendering: ", id)
  }
}

boundary <- tampaBayOpenData::get_dataset(
  "city-boundary", fields = "OBJECTID", spatial = TRUE, out_sr = 4326
)
projects <- tampaBayOpenData::get_dataset(
  "capital-projects", fields = "OBJECTID", spatial = TRUE, out_sr = 4326
)

boundary_source <- tampaBayOpenData::dataset_provenance(boundary)
projects_source <- tampaBayOpenData::dataset_provenance(projects)
if (!isTRUE(boundary_source$complete) || !isTRUE(projects_source$complete)) {
  stop("Map generation requires complete source retrievals.")
}
if (sf::st_crs(boundary)$epsg != 4326 || sf::st_crs(projects)$epsg != 4326) {
  stop("Expected both source layers in EPSG:4326.")
}

# Preserve the full retrieved objects above; exclude missing geometries only
# from the plotted symbols and report their count separately.
plotted <- projects[!sf::st_is_empty(projects), ]
if (!nrow(boundary) || !nrow(plotted)) {
  stop("Both a boundary and at least one project location are required.")
}

output <- file.path("man", "figures", "tampa-capital-projects-map.png")
dir.create(dirname(output), showWarnings = FALSE, recursive = TRUE)
snapshot_date <- format(Sys.time(), "%d %b %Y", tz = "America/New_York")

render_map <- function() {
  grDevices::png(output, width = 1200, height = 690, res = 160,
                 bg = "#F4F8FA")
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::layout(matrix(c(1, 2), nrow = 1), widths = c(1, 1.35))

  graphics::par(mar = c(0, 0, 0, 0), bg = "#F4F8FA",
                fg = "#213D47", family = "sans")
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, 1), ylim = c(0, 1))
  graphics::text(0.09, 0.88, "CITY OF TAMPA", adj = c(0, 0.5),
                 cex = 0.87, font = 2, col = "#496E7A")
  graphics::text(0.09, 0.79, "Capital projects\nacross Tampa",
                 adj = c(0, 1), cex = 1.75, font = 2, col = "#183846")
  graphics::text(0.09, 0.55, paste(nrow(plotted), "mapped locations"),
                 adj = c(0, 0.5), cex = 1.08, col = "#183846")
  graphics::points(0.11, 0.45, pch = 21, cex = 1.2,
                   bg = "#DB6745", col = "#8D3E34")
  graphics::text(0.17, 0.45, "City capital project location",
                 adj = c(0, 0.5), cex = 0.87, col = "#314D58")
  graphics::segments(0.09, 0.37, 0.13, 0.37, lwd = 2.1,
                     col = "#527A76")
  graphics::text(0.17, 0.37, "Shoreline-adjusted city boundary",
                 adj = c(0, 0.5), cex = 0.87, col = "#314D58")
  graphics::text(0.09, 0.18,
                 paste0("City of Tampa public layers\n", snapshot_date,
                        " snapshot"),
                 adj = c(0, 0.5), cex = 0.88, col = "#53707B")

  graphics::par(mar = c(0.7, 0, 0.7, 0.7), bg = "#F4F8FA",
                fg = "#213D47", family = "sans")
  extent <- sf::st_bbox(boundary)
  x_pad <- as.numeric(extent["xmax"] - extent["xmin"]) * 0.08
  y_pad <- as.numeric(extent["ymax"] - extent["ymin"]) * 0.05
  graphics::plot(
    sf::st_geometry(boundary),
    xlim = c(extent["xmin"] - x_pad, extent["xmax"] + x_pad),
    ylim = c(extent["ymin"] - y_pad, extent["ymax"] + y_pad),
    col = "#CFE5D8", border = "#527A76", lwd = 1.3,
    axes = FALSE, xlab = "", ylab = "", reset = FALSE
  )
  graphics::plot(
    sf::st_geometry(plotted), add = TRUE, pch = 21,
    bg = grDevices::adjustcolor("#DB6745", alpha.f = 0.76),
    col = "#8D3E34", lwd = 0.5, cex = 0.76
  )
}

render_map()
message("Wrote ", output)
message("Project records: ", nrow(projects), "; plotted with geometry: ",
        nrow(plotted), "; boundary records: ", nrow(boundary))
message("Source retrieval dates (UTC): projects ", projects_source$retrieved_at,
        "; boundary ", boundary_source$retrieved_at)

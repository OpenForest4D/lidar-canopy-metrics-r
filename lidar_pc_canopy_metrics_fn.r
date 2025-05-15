# R-based worflow for processing lidar point cloud data, DTM and CHM creation; LAS normalization; Canopy metrics; Individual tree detection; Crown-level metrics computation

# Define the f_metrics function in the global environment
f_metrics <- function(Z, n) {
  # Strata: Proportion of Z values in the range of 2 to 5 meters
  strata = length(Z[Z > 2 & Z < 5]) / length(Z)
  # Canopy Cover: Proportion of returns in the first return
  Zcov = length(Z[Z >= 2 & n == 1]) / length(Z[n == 1])
  # Compute percentiles of Z values
  percentiles = quantile(Z, c(seq(0.05, 0.95, 0.05), seq(0.96, 1, 0.01)))

  # Create a list of computed metrics
  list_metrics = list(
    COV = Zcov,            # Canopy cover
    Hmean = mean(Z),       # Mean canopy height
    HSD = sd(Z),           # Standard deviation of height
    HMAX = max(Z),         # Maximum height
    S = strata             # Strata value
  )

  # Add percentile metrics to the list
  for (i in seq_along(percentiles)) {
    list_metrics[[paste0("H", gsub("\\.", "", names(percentiles)[i]), "TH")]] <- percentiles[i]
  }

  return(list_metrics)  # Return the list of metrics
}

# Define the process_lidar_data function
process_lidar_data <- function(laspath, res = 1, algorithm = "p2r") {
  # Install and load required libraries using pacman
  if (!require(pacman)) install.packages("pacman")  # Install pacman package if not already installed
  library(pacman)  # Load pacman
  p_load(lidR, terra, sf, RCSF, rgl)  # Load necessary libraries for lidar data processing

  # Read the raw lidar data from the specified .laz file
  las <- readLAS(laspath)  # Load lidar data into 'las' object

  # Custom function to create a color ramp based on height values
  myColorRamp <- function(colors, values) {
    v <- (values - min(values)) / diff(range(values))  # Normalize height values between 0 and 1
    x <- colorRamp(colors)(v)  # Apply color ramp
    rgb(x[,1], x[,2], x[,3], maxColorValue = 255)  # Convert RGB values to hex
  }

  # Visualize points with color based on height
  col <- myColorRamp(c("blue", "brown", "yellow", "pink"), las@data$Z)  # Apply custom color ramp for height
  points3d(las@data$X, las@data$Y, las@data$Z, col = col)  # Plot 3D points with colors

  # Another visualization using 'viridis' color palette
  col <- myColorRamp(rev(viridis::inferno(10)), las@data$Z)  # Apply 'inferno' color palette
  points3d(las@data$X, las@data$Y, las@data$Z, col = col)  # Plot 3D points with new color palette

  # Add axes to the 3D plot
  axes3d(c("x+", "y-", "z-"))  # Set axes labels
  grid3d(side = c('x+', 'y-', 'z'), col = "gray")  # Add grid lines
  title3d(xlab = "UTM.Easting", ylab = "UTM.Northing", zlab = "Height(m)", col = "red")  # Add title

  # Add terrain to 3D plot
  planes3d(0, 0, -1, 0, col = "gray", alpha = 0.7)  # Add terrain (ground plane) with transparency

  # Remove duplicated points from the lidar data
  las <- filter_duplicates(las)  # Remove duplicates

  # Classify noise points using Statistical Outlier Removal (SOR) algorithm
  las <- classify_noise(las, algorithm = sor(k = 10, m = 3, quantile = FALSE))  # Use SOR for noise classification

  # Filter out the noise points (classified as Class 18)
  las <- filter_poi(las, Classification != 18)  # Remove points classified as noise (Class 18)

  # Generate a Digital Surface Model (DSM) at specified resolution
  dsm <- rasterize_canopy(las, res = res, algorithm = p2r())  # Create DSM using p2r (point-to-raster) algorithm
  col <- height.colors(25)  # Define color palette
  plot(dsm, col = col)  # Plot DSM

  # Classify ground points using Cloth Simulation Filter (CSF)
  las <- classify_ground(las, csf(cloth_resolution = 2, rigidness = 3L))  # Classify ground points using CSF

  # Interpolate ground points into a Digital Terrain Model (DTM) using TIN
  dtm <- rasterize_terrain(las, res = res, algorithm = tin())  # Create DTM using TIN interpolation

  # Plot the DTM in 2D and 3D for verification
  plot(dtm)  # Plot DTM in 2D
  plot_dtm3d(dtm)  # Plot DTM in 3D

  # Visualize ground points (Class 2) within the DTM
  x <- plot(filter_poi(las, Classification == 2))  # Filter for ground points (Class 2)
  add_dtm3d(x, dtm)  # Add DTM to 3D ground points visualization

  # Normalize the lidar data to compute height above ground level
  las_norm <- normalize_height(las, algorithm = dtm)  # Normalize lidar data using the DTM
  plot(las_norm)  # Plot normalized lidar data

  # Generate a Canopy Height Model (CHM) at specified resolution
  chm <- rasterize_canopy(las_norm, res = res, algorithm = p2r())  # Create CHM
  col <- height.colors(25)  # Define color palette for CHM
  plot(chm, col = col)  # Plot CHM

  # Save the CHM and normalized lidar data to files
  output_dir <- "~/lidar_output"
  dir.create(output_dir, showWarnings = FALSE)

  writeRaster(chm, file.path(output_dir, "CHM.tif"), overwrite = TRUE)  # Save CHM as a raster file
  writeLAS(las_norm,  file.path(output_dir, "laz_norm.laz"))  # Save normalized lidar data

  # Compute canopy metrics on a grid with specified resolution
  canopy_metrics_grid <- grid_metrics(las_norm, func = ~f_metrics(Z, ReturnNumber), res = res)  # Apply canopy metrics function
  plot(canopy_metrics_grid)  # Plot the computed canopy metrics

  # Set smoothing window size for the CHM
  kernel <- matrix(1, 3, 3)  # Define smoothing kernel (3x3 window)
  chm_smoothed <- terra::focal(chm, w = kernel, fun = median, na.rm = TRUE)  # Apply median smoothing to the CHM

  # Visualize original and smoothed CHM
  par(mfrow = c(1, 2))  # Arrange plots side by side
  plot(chm, col = col)  # Plot original CHM
  plot(chm_smoothed, col = col)  # Plot smoothed CHM

  # Save smoothed CHM
  writeRaster(chm_smoothed,  file.path(output_dir, "CHM_smoothed.tif"), overwrite = TRUE)  # Save smoothed CHM to file

  # Detect tree tops using a local maxima filter with a 5-meter radius
  ttops <- locate_trees(chm_smoothed, lmf(5))  # Locate tree tops using local maxima filter
  plot(sf::st_geometry(ttops), add = TRUE, pch = 3)  # Add tree tops to plot

  # Visualize tree tops in 3D
  x <- plot(las_norm, bg = "white", size = 4)  # Plot normalized lidar data
  add_treetops3d(x, ttops)  # Add tree tops to 3D plot

  # Segment trees using the Silva2016 algorithm
  las_itc <- segment_trees(las_norm, silva2016(chm_smoothed, ttops))  # Segment trees using Silva2016 algorithm
  plot(las_itc, color = "treeID")  # Plot segmented trees with tree ID color

  # Plot tree crown boundaries
  convex_hulls <- delineate_crowns(las_itc)  # Delineate tree crowns
  plot(chm_smoothed, col = col)  # Plot smoothed CHM
  plot(convex_hulls, add = TRUE, lwd = 2, border = "green")  # Add tree crowns with green border

  # Calculate crown-level metrics
  fun <- ~list(maxz = max(Z),               # Maximum height
               meanz = mean(Z),             # Mean height
               sdz = sd(Z),                 # Standard deviation of height
               varz = var(Z),               # Variance of height
               p98 = quantile(Z, 0.98))     # 98th percentile

  return(list(dsm = dsm, dtm = dtm, chm = chm, chm_smoothed = chm_smoothed, canopy_metrics_grid = canopy_metrics_grid, convex_hulls = convex_hulls))
}

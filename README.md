[![NSF-1948997](https://img.shields.io/badge/NSF-2409885-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=2409885) [![NSF-2409886](https://img.shields.io/badge/NSF-2409886-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=2409886) [![NSF-2409887](https://img.shields.io/badge/NSF-2409887-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=2409887)

## Lidar Data Processing and Canopy Metrics Extraction in R

R-based script for processing airborne lidar data, visualizing point clouds, generating surface models, extracting canopy metrics, and segmenting individual trees. The workflow leverages the [lidR](https://r-lidar.github.io/lidRbook/), [terra](https://rspatial.github.io/terra/), [sf](https://r-spatial.github.io/sf/), [RCSF](https://cran.r-project.org/web/packages/RCSF/index.html) and other packages to automate common lidar analysis tasks, including noise filtering, ground classification, normalization, canopy height modeling, and individual tree segmentation.


## Features:
- Lidar Data Import and Cleaning: Reads .laz files, removes duplicate and noisy points, and classifies ground points.
- 3D Visualization: Visualizes lidar point clouds in 3D using custom and viridis color ramps.
- Surface Model Generation: Creates Digital Surface Model (DSM), Digital Terrain Model (DTM), and Canopy Height Model (CHM).
- Height Normalization: Normalizes point heights relative to the ground surface.
- Canopy Metrics Calculation: Computes grid-based canopy structure metrics, including percentiles, mean, max, and cover.
- CHM Smoothing and Tree Detection: Applies median filtering to CHM, detects tree tops, and segments individual trees.
- Crown Delineation and Metrics: Delineates tree crowns and computes crown-level statistics.

### Inputs:
  - laspath: Path to the lidar point cloud laz file.
  - res: Resolution for raster products (default: 1m).
  - algorithm: Rasterization algorithm (default: "p2r").

### Outputs: 
  - Raster files for DSM, DTM, CHM, and smoothed CHM (.tif)
  - Normalized lidar data (.laz)
  - Canopy metrics grid and tree crown polygons

### Requirements
R packages: lidR, terra, sf, RCSF, rgl, viridis, pacman
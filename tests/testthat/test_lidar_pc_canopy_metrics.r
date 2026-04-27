# =============================================================================
# Unit Tests for lidar_pc_canopy_metrics_fn.r
# Tests cover: f_metrics() — the pure, testable function in the module.
#
# The process_lidar_data() function depends heavily on file I/O, 3D graphics
# (rgl), and external LAS files; those concerns are covered via integration-
# style smoke tests with mocks / skips where live data is unavailable.
#
# Framework : testthat  (>= 3.0)
# Run with  : testthat::test_file("test_lidar_pc_canopy_metrics.r")
#             or: devtools::test() if inside a package
# =============================================================================

library(testthat)

# Source the function definitions (adjust path as needed)
# source("lidar_pc_canopy_metrics_fn.r")

# ---------------------------------------------------------------------------
# Helper: build a minimal f_metrics-compatible Z / n pair
# ---------------------------------------------------------------------------
make_cloud <- function(z_vals, n_vals = NULL) {
  if (is.null(n_vals)) n_vals <- rep(1L, length(z_vals))
  list(Z = z_vals, n = n_vals)
}

# ===========================================================================
# 1.  f_metrics — return structure
# ===========================================================================
test_that("f_metrics returns a named list", {
  pc <- make_cloud(z_vals = c(0, 1, 3, 6, 10, 15))
  result <- f_metrics(pc$Z, pc$n)

  expect_type(result, "list")
  expect_named(result, expected = NULL, ignore.order = TRUE) # names exist
  expect_true(length(names(result)) > 0)
})

test_that("f_metrics always contains the five base metrics", {
  pc <- make_cloud(z_vals = c(0, 1, 3, 6, 10, 15))
  result <- f_metrics(pc$Z, pc$n)

  expect_true("COV"   %in% names(result), info = "COV (canopy cover) missing")
  expect_true("Hmean" %in% names(result), info = "Hmean missing")
  expect_true("HSD"   %in% names(result), info = "HSD missing")
  expect_true("HMAX"  %in% names(result), info = "HMAX missing")
  expect_true("S"     %in% names(result), info = "S (strata) missing")
})

test_that("f_metrics includes percentile metrics with expected naming pattern", {
  pc <- make_cloud(z_vals = seq(0, 30, by = 0.5))
  result <- f_metrics(pc$Z, pc$n)

  # Spot-check a few: H5TH (5th pct), H50TH (50th pct), H100TH (100th pct)
  expect_true(any(grepl("^H\\d+TH$", names(result))),
              info = "No percentile keys matching H<nn>TH found")
  expect_true("H5TH"   %in% names(result))
  expect_true("H50TH"  %in% names(result))
  expect_true("H95TH"  %in% names(result))
  expect_true("H100TH" %in% names(result))
})

# ===========================================================================
# 2.  f_metrics — Hmean
# ===========================================================================
test_that("Hmean equals mean(Z)", {
  z <- c(1, 2, 3, 4, 5)
  result <- f_metrics(z, rep(1L, length(z)))
  expect_equal(result$Hmean, mean(z))
})

test_that("Hmean is correct for a single-point cloud", {
  result <- f_metrics(7.5, 1L)
  expect_equal(result$Hmean, 7.5)
})

# ===========================================================================
# 3.  f_metrics — HMAX
# ===========================================================================
test_that("HMAX equals max(Z)", {
  z <- c(1, 5, 3, 2, 9, 4)
  result <- f_metrics(z, rep(1L, length(z)))
  expect_equal(result$HMAX, 9)
})

test_that("HMAX handles negative and zero heights", {
  z <- c(-1, 0, 2, 5)
  result <- f_metrics(z, rep(1L, length(z)))
  expect_equal(result$HMAX, 5)
})

# ===========================================================================
# 4.  f_metrics — HSD (standard deviation)
# ===========================================================================
test_that("HSD equals sd(Z)", {
  z <- c(10, 12, 8, 11, 9)
  result <- f_metrics(z, rep(1L, length(z)))
  expect_equal(result$HSD, sd(z))
})

test_that("HSD is NA for a single-element cloud (R's sd behaviour)", {
  result <- f_metrics(5.0, 1L)
  expect_true(is.na(result$HSD))
})

# ===========================================================================
# 5.  f_metrics — COV (canopy cover)
# ===========================================================================
test_that("COV is proportion of first-return points >= 2 m", {
  # Z:  0, 1, 2, 3, 4   all first returns
  # >= 2 : indices 3,4,5  → COV = 3/5 = 0.6
  z <- c(0, 1, 2, 3, 4)
  n <- rep(1L, 5)
  result <- f_metrics(z, n)
  expect_equal(result$COV, 3 / 5)
})

test_that("COV ignores non-first returns", {
  # Two first returns (Z=5 and Z=1), one second return (Z=6)
  # First returns >= 2 : Z=5 only  → COV = 1/2
  z <- c(5, 1, 6)
  n <- c(1L, 1L, 2L)
  result <- f_metrics(z, n)
  expect_equal(result$COV, 1 / 2)
})

test_that("COV is 0 when no first returns are >= 2 m", {
  z <- c(0.5, 1.0, 1.9)
  n <- rep(1L, 3)
  result <- f_metrics(z, n)
  expect_equal(result$COV, 0)
})

test_that("COV is 1 when all first returns are >= 2 m", {
  z <- c(3, 5, 10, 20)
  n <- rep(1L, 4)
  result <- f_metrics(z, n)
  expect_equal(result$COV, 1)
})

# ===========================================================================
# 6.  f_metrics — S (strata: 2 m < Z < 5 m)
# ===========================================================================
test_that("S is proportion of Z strictly between 2 and 5", {
  # Z = 1, 2, 3, 4, 5, 6  →  values in (2,5): 3 and 4  → S = 2/6
  z <- c(1, 2, 3, 4, 5, 6)
  n <- rep(1L, 6)
  result <- f_metrics(z, n)
  expect_equal(result$S, 2 / 6)
})

test_that("S boundary: values exactly 2 and 5 are excluded", {
  z <- c(2, 5)           # neither qualifies (strict inequality)
  n <- rep(1L, 2)
  result <- f_metrics(z, n)
  expect_equal(result$S, 0)
})

test_that("S is 0 when all points are below 2 m", {
  z <- c(0, 0.5, 1.0, 1.9)
  n <- rep(1L, 4)
  result <- f_metrics(z, n)
  expect_equal(result$S, 0)
})

test_that("S is 0 when all points are above 5 m", {
  z <- c(6, 10, 20, 30)
  n <- rep(1L, 4)
  result <- f_metrics(z, n)
  expect_equal(result$S, 0)
})

test_that("S is 1 when all points are strictly between 2 and 5", {
  z <- c(2.1, 3.0, 4.9)
  n <- rep(1L, 3)
  result <- f_metrics(z, n)
  expect_equal(result$S, 1)
})

# ===========================================================================
# 7.  f_metrics — percentile values
# ===========================================================================
test_that("H50TH equals median(Z) for a simple sequence", {
  z <- 1:10
  result <- f_metrics(z, rep(1L, length(z)))
  expect_equal(result$H50TH, as.numeric(quantile(z, 0.50)), tolerance = 1e-9)
})

test_that("H100TH equals max(Z)", {
  z <- c(3, 7, 2, 15, 8)
  result <- f_metrics(z, rep(1L, length(z)))
  expect_equal(result$H100TH, max(z))
})

test_that("H5TH equals 5th quantile of Z", {
  z <- seq(0, 100, by = 1)
  result <- f_metrics(z, rep(1L, length(z)))
  expect_equal(result$H5TH, as.numeric(quantile(z, 0.05)), tolerance = 1e-9)
})

# ===========================================================================
# 8.  f_metrics — uniform / constant height inputs
# ===========================================================================
test_that("f_metrics works when all Z values are identical", {
  z <- rep(10, 20)
  n <- rep(1L, 20)
  result <- f_metrics(z, n)

  expect_equal(result$Hmean, 10)
  expect_equal(result$HMAX,  10)
  expect_equal(result$HSD,   0)
  expect_equal(result$S,     0)   # 10 is not in (2, 5)
  expect_equal(result$COV,   1)   # all >= 2 m, all first returns
})

# ===========================================================================
# 9.  f_metrics — large realistic point cloud (performance sanity check)
# ===========================================================================
test_that("f_metrics handles 100 000 points without error", {
  set.seed(42)
  z <- runif(1e5, min = 0, max = 40)
  n <- sample(1L:3L, 1e5, replace = TRUE)

  result <- expect_no_error(f_metrics(z, n))
  expect_true(is.list(result))
  expect_true(result$HMAX <= 40)
  expect_true(result$Hmean > 0)
})

# ===========================================================================
# 10.  f_metrics — return value types
# ===========================================================================
test_that("All returned values are numeric (not character or logical)", {
  z <- c(0, 2.5, 5, 10, 20)
  n <- rep(1L, 5)
  result <- f_metrics(z, n)

  for (nm in names(result)) {
    expect_true(is.numeric(result[[nm]]),
                info = paste("Element", nm, "is not numeric"))
  }
})

# ===========================================================================
# 11.  process_lidar_data — smoke test (skipped without a real .laz file)
# ===========================================================================
test_that("process_lidar_data exists and is a function", {
  expect_true(is.function(process_lidar_data))
})

test_that("process_lidar_data errors gracefully on a non-existent file", {
  skip_if_not_installed("lidR")
  expect_error(
    process_lidar_data("__nonexistent_file__.laz"),
    regexp = NULL   # any error is acceptable
  )
})

# ===========================================================================
# 12.  Integration: f_metrics used inside grid_metrics (mocked)
# ===========================================================================
test_that("f_metrics integrates correctly when called via lapply over grid cells", {
  # Simulate what grid_metrics does: split Z by cell and apply f_metrics
  set.seed(7)
  all_z <- runif(500, 0, 30)
  all_n <- sample(1L:2L, 500, replace = TRUE)
  cell  <- sample(1:10, 500, replace = TRUE)

  results <- lapply(unique(cell), function(ci) {
    idx <- which(cell == ci)
    f_metrics(all_z[idx], all_n[idx])
  })

  expect_length(results, length(unique(cell)))
  lapply(results, function(r) {
    expect_true("COV"   %in% names(r))
    expect_true("Hmean" %in% names(r))
  })
})

# Unit Tests — `lidar_pc_canopy_metrics_fn.r`

Tests for [`lidar_pc_canopy_metrics_fn.r`](https://github.com/OpenForest4D/lidar-canopy-metrics-r/blob/main/lidar_pc_canopy_metrics_fn.r) using the [`testthat`](https://testthat.r-lib.org/) framework (≥ 3.0).

---

## Test Coverage

### `f_metrics()` — Pure Function (no LAS files required)

| # | Group | What's Tested |
|---|-------|---------------|
| 1 | **Return structure** | Returns a named list containing all expected keys |
| 2 | **`Hmean`** | Equals `mean(Z)`; correct for single-point clouds |
| 3 | **`HMAX`** | Equals `max(Z)`; handles negatives and zeros |
| 4 | **`HSD`** | Equals `sd(Z)`; correctly `NA` for n = 1 |
| 5 | **`COV` (canopy cover)** | Only counts first returns (`n == 1`) at ≥ 2 m; edge cases 0 and 1 |
| 6 | **`S` (strata)** | Strict bounds `(2, 5)` exclusive; all-below, all-above, all-within |
| 7 | **Percentiles** | `H5TH`, `H50TH`, `H100TH` match `quantile()` exactly |
| 8 | **Constant height** | All Z identical — tests `HSD = 0`, `COV = 1`, `S = 0` simultaneously |
| 9 | **Performance** | 100,000-point cloud completes without error |
| 10 | **Return types** | Every returned element is `numeric` |

### `process_lidar_data()` — I/O-Heavy Function (guarded tests)

| # | Group | What's Tested |
|---|-------|---------------|
| 11 | **Smoke test** | Function exists; graceful error on missing `.laz` file |
| 12 | **Integration** | Simulates `grid_metrics` cell-splitting via `lapply` — verifies `f_metrics` composability |

---

## How to Run

### 1. Install dependencies

```r
install.packages("testthat")

# For integration tests (optional — skipped automatically if unavailable)
install.packages("lidR")
```

### 2. Source the original file and run the tests

```r
source("lidar_pc_canopy_metrics_fn.r")
testthat::test_file("test_lidar_pc_canopy_metrics.r")
```

### 3. Run as part of a package (if using `devtools`)

```r
devtools::test()
```

---

## File Structure

```
.
├── lidar_pc_canopy_metrics_fn.r      # Source file under test
└── tests/testthat/test_lidar_pc_canopy_metrics.r    # Unit tests (this file)
```

---

## Notes

- Tests for `f_metrics()` require **no external files** — they use synthetic point clouds constructed inline.
- Tests for `process_lidar_data()` are **automatically skipped** if `lidR` is not installed or no `.laz` file is present.
- The performance test (#9) uses `set.seed(42)` for reproducibility.

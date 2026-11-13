# ============================================================
# 03_merge_dataset.R
#
# Merges weather data, fire labels, and satellite data (NDVI/LST)
# into a single analysis-ready table.
#
# The shared key that links all three sources is:
#   district + week_start
#
# After merging, each row represents:
#   ONE district + ONE week → with all features + fire label
#
# INPUTS:
#   data/raw/weather_daily_raw.csv       (from script 01)
#   data/raw/fire_labels_district_week.csv (from script 02)
#   data/raw/ndvi_lst_uttarakhand.csv    (exported from GEE)
#
# OUTPUT:
#   data/processed/merged_dataset.csv
# ============================================================

library(dplyr)
library(lubridate)
library(readr)
library(tidyr)

# -----------------------------------------------------------
# Step 1: Load fire labels (already at district-week level)
# -----------------------------------------------------------
cat("Loading fire labels...\n")
fire_labels <- read_csv("data/raw/fire_labels_district_week.csv",
                        show_col_types = FALSE) %>%
  mutate(week_start = as.Date(week_start))

cat("Fire label rows:", nrow(fire_labels), "\n")

# -----------------------------------------------------------
# Step 2: Aggregate daily weather → weekly weather.
#
# NASA POWER gave us DAILY data.
# We need WEEKLY data to match the fire labels.
#
# Aggregation rules:
#   temperature → weekly average (mean makes sense for temp)
#   humidity    → weekly average
#   rainfall    → weekly TOTAL (we want total rain for the week)
#   wind_speed  → weekly average
# -----------------------------------------------------------
cat("Loading and aggregating daily weather to weekly...\n")

weather_daily <- read_csv("data/raw/weather_daily_raw.csv",
                          show_col_types = FALSE) %>%
  mutate(date = as.Date(date))

weather_weekly <- weather_daily %>%
  # Tag each date with its week (Monday of that ISO week)
  mutate(week_start = floor_date(date, unit = "week", week_start = 1)) %>%
  # Group by district + week and compute aggregates
  group_by(district, week_start) %>%
  summarise(
    avg_temp     = mean(temperature, na.rm = TRUE),
    avg_humidity = mean(humidity,    na.rm = TRUE),
    weekly_rain  = sum(rainfall,     na.rm = TRUE),  # total rainfall for the week
    avg_wind     = mean(wind_speed,  na.rm = TRUE),
    .groups = "drop"
  )

cat("Weekly weather rows:", nrow(weather_weekly), "\n")

# -----------------------------------------------------------
# Step 3: Engineer the "consecutive dry days" feature.
#
# This captures risk build-up: if it hasn't rained for 10 days,
# vegetation is much drier than if the last rain was yesterday.
#
# We calculate this from the daily data, then aggregate to weekly
# (we take the max consecutive dry days seen in that week).
#
# A "dry day" = rainfall < 1mm (common threshold in literature).
# -----------------------------------------------------------
cat("Engineering consecutive dry days feature...\n")

# For each district, calculate a running count of dry days
# that resets to 0 whenever it rains.
weather_daily <- weather_daily %>%
  arrange(district, date) %>%
  group_by(district) %>%
  mutate(
    is_dry_day = ifelse(is.na(rainfall) | rainfall < 1.0, 1, 0),
    # cumsum trick: every time it rains, the group ID increases,
    # so we restart the count within each rain-free streak.
    rain_group = cumsum(is_dry_day == 0),
    # Count how many consecutive dry days up to and including today
    consec_dry_days = ave(is_dry_day, rain_group, FUN = cumsum)
  ) %>%
  ungroup()

# Aggregate: for each district-week, take the max dry-day streak
dry_days_weekly <- weather_daily %>%
  mutate(week_start = floor_date(date, unit = "week", week_start = 1)) %>%
  group_by(district, week_start) %>%
  summarise(max_consec_dry_days = max(consec_dry_days, na.rm = TRUE),
            .groups = "drop")

# Join dry days onto weekly weather
weather_weekly <- weather_weekly %>%
  left_join(dry_days_weekly, by = c("district", "week_start"))

# -----------------------------------------------------------
# Step 4: Load NDVI / LST satellite data.
#
# This file was exported from Google Earth Engine.
# Expected columns: district, date (or week_start), ndvi, lst
#
# If GEE data is not ready yet, this step is SKIPPED and
# we proceed without satellite features (add them in Phase 2).
# -----------------------------------------------------------
ndvi_lst_file <- "data/raw/ndvi_lst_uttarakhand.csv"

if (file.exists(ndvi_lst_file)) {
  cat("Loading NDVI/LST satellite data...\n")

  ndvi_lst_raw <- read_csv(ndvi_lst_file, show_col_types = FALSE) %>%
    mutate(date = as.Date(date))

  # ---
  # NDVI is a MONTHLY product (MOD13A3: one reading per month).
  # The date in the GEE export is always the 1st of each month.
  # If we match by exact week, ~75% of weeks have no match because
  # Jan 1 maps to the Dec 31 week — not any of Jan's actual 4 weeks.
  #
  # Fix: match NDVI by YEAR-MONTH instead of by exact week.
  # Every week in the same month gets the same NDVI value.
  # This is correct — NDVI represents the whole month's vegetation state.
  # ---
  ndvi_monthly <- ndvi_lst_raw %>%
    filter(!is.na(ndvi)) %>%
    mutate(year_month = format(date, "%Y-%m")) %>%
    group_by(district, year_month) %>%
    summarise(avg_ndvi = mean(ndvi, na.rm = TRUE), .groups = "drop")

  cat("NDVI monthly readings:", nrow(ndvi_monthly), "\n")

  # ---
  # LST is an 8-DAY product (MOD11A2: one reading every 8 days).
  # Weekly aggregation works fine here — there's usually a reading
  # within each week or the next closest week.
  # ---
  lst_weekly <- ndvi_lst_raw %>%
    filter(!is.na(lst)) %>%
    mutate(week_start = floor_date(date, unit = "week", week_start = 1)) %>%
    group_by(district, week_start) %>%
    summarise(avg_lst = mean(lst, na.rm = TRUE), .groups = "drop")

  cat("LST weekly readings:", nrow(lst_weekly), "\n")
  satellite_available <- TRUE

} else {
  # Satellite data not available yet — we proceed without it.
  cat("NDVI/LST file not found — omitting satellite features from current merge.\n")
  satellite_available <- FALSE
}

# -----------------------------------------------------------
# Step 5: Merge everything together.
#
# Start with fire_labels (full district-week grid).
# Left-join weather and satellite data onto it.
# "Left join" means we keep ALL rows from fire_labels and
# attach matching weather/satellite data where available.
# -----------------------------------------------------------
cat("Merging all datasets...\n")

merged <- fire_labels %>%
  left_join(weather_weekly, by = c("district", "week_start"))

if (satellite_available) {
  # NDVI: join by year-month (monthly product → every week in same month gets same value)
  merged <- merged %>%
    mutate(year_month = format(week_start, "%Y-%m")) %>%
    left_join(ndvi_monthly, by = c("district", "year_month"))

  # LST: join by exact week (8-day product → weekly match works fine)
  merged <- merged %>%
    left_join(lst_weekly, by = c("district", "week_start"))
}

# -----------------------------------------------------------
# Step 6: Add time-based features derived from the date.
#
# Month (1–12): captures the fire season (March–June is peak).
# We don't use the exact date as a feature — models don't
# understand "March 15" directly, but they can learn from
# "month = 3" (March) that it's fire season.
# -----------------------------------------------------------
merged <- merged %>%
  mutate(
    month      = month(week_start),   # 1 = January, 6 = June, etc.
    week_of_yr = isoweek(week_start)  # 1–52, useful for seasonality
  )

# -----------------------------------------------------------
# Step 7: Quick summary of the merged dataset
# -----------------------------------------------------------
cat("\n--- Merged Dataset Summary ---\n")
cat("Total rows:", nrow(merged), "\n")
cat("Columns:", paste(names(merged), collapse = ", "), "\n")
cat("Missing values per column:\n")
print(colSums(is.na(merged)))

# Show fire rate
cat("\nFire_occurred distribution:\n")
print(table(merged$fire_occurred))

# -----------------------------------------------------------
# Save the merged dataset
# -----------------------------------------------------------
output_path <- "data/processed/merged_dataset.csv"
write_csv(merged, output_path)

cat("\nMerged dataset saved to:", output_path, "\n")
cat("Script 03 complete.\n")

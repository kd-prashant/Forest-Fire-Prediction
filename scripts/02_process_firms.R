# ============================================================
# 02_process_firms.R
#
# Reads the FIRMS fire data CSV (downloaded manually from NASA)
# and converts it into a district-week label table.
#
# What "label" means here:
#   For each district and each week, did a fire occur? (1 = yes, 0 = no)
#
# How we decide if a fire falls inside a district:
#   We use a simple bounding box (rectangle of lat/lon values)
#   for each district. This is not perfectly precise, but it is
#   good enough for district-level prediction, and it avoids
#   the complexity of working with GIS shapefiles.
#
# INPUT:  data/raw/firms_uttarakhand.csv
# OUTPUT: data/raw/fire_labels_district_week.csv
# ============================================================

library(dplyr)
library(lubridate)  # for week() and floor_date() functions
library(readr)

# -----------------------------------------------------------
# Bounding boxes for each district.
# Format: lat_min, lat_max, lon_min, lon_max
# A fire point is "in" a district if its coordinates fall
# inside this rectangle.
# -----------------------------------------------------------
district_boxes <- data.frame(
  district = c("Nainital",  "Pauri_Garhwal", "Almora",   "Tehri_Garhwal", "Chamoli"),
  lat_min  = c(29.20,       29.45,            29.40,       30.15,            30.10),
  lat_max  = c(29.60,       30.20,            29.80,       30.60,            30.80),
  lon_min  = c(79.10,       78.40,            79.30,       78.10,            79.00),
  lon_max  = c(79.80,       79.30,            79.90,       78.70,            79.70),
  stringsAsFactors = FALSE
)

# -----------------------------------------------------------
# Step 1: Read the FIRMS CSV file.
#
# IMPORTANT: The FIRMS CSV uses these column names:
#   latitude, longitude, acq_date, confidence, brightness
#
# Verify column definitions:
#   latitude, longitude, acq_date, confidence, brightness
# -----------------------------------------------------------

# Check if the file exists before attempting ingestion
firms_file <- "data/raw/firms_uttarakhand.csv"

if (!file.exists(firms_file)) {
  stop(
    "FIRMS data file not located at: ", firms_file, "\n",
    "Acquisition required from NASA FIRMS repository (https://firms.modaps.eosdis.nasa.gov/download/)."
  )
}

cat("Reading FIRMS data from:", firms_file, "\n")
firms_raw <- read_csv(firms_file, show_col_types = FALSE)

cat("Total fire detections in raw file:", nrow(firms_raw), "\n")
cat("Column names in the file:", paste(names(firms_raw), collapse = ", "), "\n")

# Keep only the columns we need
# Note: FIRMS CSV uses 'acq_date' for the acquisition date
firms_clean <- firms_raw %>%
  select(latitude, longitude, acq_date, confidence) %>%
  mutate(
    # Convert the date column to R's Date type
    date = as.Date(acq_date),
    # Keep only the date range we care about
  ) %>%
  filter(date >= as.Date("2019-01-01") & date <= as.Date("2024-12-31"))

cat("Fire detections in 2019–2024:", nrow(firms_clean), "\n")

# -----------------------------------------------------------
# Step 2: Assign each fire point to a district.
#
# For each fire point, we check if its latitude and longitude
# falls inside any of our district bounding boxes.
# If it does, we tag it with that district name.
# -----------------------------------------------------------

# This function checks which district a single fire point belongs to.
# Returns the district name, or NA if it doesn't fall in any.
assign_district <- function(lat, lon) {
  for (i in 1:nrow(district_boxes)) {
    if (lat >= district_boxes$lat_min[i] &&
        lat <= district_boxes$lat_max[i] &&
        lon >= district_boxes$lon_min[i] &&
        lon <= district_boxes$lon_max[i]) {
      return(district_boxes$district[i])
    }
  }
  return(NA)  # fire point doesn't fall in any of our 5 districts
}

cat("Assigning districts to fire points (this may take a moment)...\n")

firms_clean$district <- mapply(
  assign_district,
  firms_clean$latitude,
  firms_clean$longitude
)

# Remove fire points that didn't fall in any of our 5 districts
firms_in_districts <- firms_clean %>%
  filter(!is.na(district))

cat("Fire detections in our 5 districts:", nrow(firms_in_districts), "\n")

# -----------------------------------------------------------
# Step 3: Create the district-week label.
#
# For each district, for each week, we check:
#   "Did at least one fire occur?" → 1 if yes, 0 if no
#
# floor_date(..., unit = "week") gives us the Monday of
# the week that date belongs to. This becomes our Week_Start.
# -----------------------------------------------------------

# Add a "week start" column (Monday of the ISO week)
firms_in_districts <- firms_in_districts %>%
  mutate(week_start = floor_date(date, unit = "week", week_start = 1))

# Aggregate: for each district + week, mark Fire_Occurred = 1
fire_weeks <- firms_in_districts %>%
  group_by(district, week_start) %>%
  summarise(fire_occurred = 1, .groups = "drop")

cat("Total district-weeks with fires:", nrow(fire_weeks), "\n")

# -----------------------------------------------------------
# Step 4: Build the complete grid of all district-weeks.
#
# We need rows for BOTH fire weeks AND non-fire weeks.
# Without this, we'd only have Fire=1 rows and no Fire=0 rows,
# which makes it impossible to train a classifier.
#
# We create every possible district-week combination between
# 2019-01-01 and 2024-12-31, then join our fire labels onto it.
# Any week without a fire gets Fire_Occurred = 0.
# -----------------------------------------------------------

# Generate every Monday from 2019 to 2024
all_weeks <- seq(
  from = floor_date(as.Date("2019-01-01"), unit = "week", week_start = 1),
  to   = floor_date(as.Date("2024-12-31"), unit = "week", week_start = 1),
  by   = "week"
)

# Create one row per district per week (the full grid)
all_district_weeks <- expand.grid(
  district   = district_boxes$district,
  week_start = all_weeks,
  stringsAsFactors = FALSE
)

cat("Total district-weeks in full grid:", nrow(all_district_weeks), "\n")

# Join fire labels onto the full grid
# Weeks without fires become NA after the join → fill with 0
fire_labels <- all_district_weeks %>%
  left_join(fire_weeks, by = c("district", "week_start")) %>%
  mutate(fire_occurred = ifelse(is.na(fire_occurred), 0, fire_occurred)) %>%
  arrange(district, week_start)

# Show the class balance so we can see how imbalanced the data is
fire_count    <- sum(fire_labels$fire_occurred == 1)
no_fire_count <- sum(fire_labels$fire_occurred == 0)
cat("\nClass balance check:\n")
cat("  Fire weeks    (fire_occurred = 1):", fire_count, "\n")
cat("  No-fire weeks (fire_occurred = 0):", no_fire_count, "\n")
cat("  Fire rate:", round(fire_count / nrow(fire_labels) * 100, 1), "%\n")
cat("  (Expect ~10-20% — fire events are the minority class, which is normal)\n")

# -----------------------------------------------------------
# Save the fire labels table.
# -----------------------------------------------------------
output_path <- "data/raw/fire_labels_district_week.csv"
write_csv(fire_labels, output_path)

cat("\nFire labels saved to:", output_path, "\n")
cat("Script 02 complete.\n")

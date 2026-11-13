# ============================================================
# GEE_merge_ndvi_lst.R
#
# Run this AFTER downloading the two GEE export files:
#   ndvi_uttarakhand.csv  (NDVI values)
#   lst_uttarakhand.csv   (LST values)
#
# This merges them into one file:
#   data/raw/ndvi_lst_uttarakhand.csv
#
# which is what script 03_merge_dataset.R expects.
# ============================================================

library(dplyr)
library(readr)

# -----------------------------------------------------------
# Check both files exist
# -----------------------------------------------------------
ndvi_file <- "data/raw/ndvi_uttarakhand.csv"
lst_file  <- "data/raw/lst_uttarakhand.csv"

if (!file.exists(ndvi_file)) {
  stop("NDVI file not found: ", ndvi_file,
       "\nDownload it from Google Drive and place it in data/raw/")
}
if (!file.exists(lst_file)) {
  stop("LST file not found: ", lst_file,
       "\nDownload it from Google Drive and place it in data/raw/")
}

# -----------------------------------------------------------
# Load both files
# -----------------------------------------------------------
ndvi_data <- read_csv(ndvi_file, show_col_types = FALSE) %>%
  select(district, date, ndvi) %>%
  mutate(date = as.Date(date))

lst_data <- read_csv(lst_file, show_col_types = FALSE) %>%
  select(district, date, lst) %>%
  mutate(date = as.Date(date)) %>%
  # Convert raw MODIS LST value to Celsius:
  # Step 1: multiply by scale factor 0.02 → gives Kelvin
  # Step 2: subtract 273.15 → gives Celsius
  # Raw values of -9999 or NULL mean no data (cloudy day) → become NA
  mutate(lst = ifelse(is.na(lst) | lst <= 0, NA, (lst * 0.02) - 273.15))

cat("NDVI rows:", nrow(ndvi_data), "\n")
cat("LST rows: ", nrow(lst_data),  "\n")

# -----------------------------------------------------------
# Merge by district + date using a full join.
# Full join keeps rows from BOTH tables even when a date
# exists in one but not the other (NDVI is monthly,
# LST is 8-day — they won't always share the same dates).
# -----------------------------------------------------------
ndvi_lst_merged <- full_join(ndvi_data, lst_data,
                             by = c("district", "date"))

cat("Merged rows:", nrow(ndvi_lst_merged), "\n")
cat("Missing NDVI values:", sum(is.na(ndvi_lst_merged$ndvi)), "\n")
cat("Missing LST values: ", sum(is.na(ndvi_lst_merged$lst)), "\n")

# Save
output_path <- "data/raw/ndvi_lst_uttarakhand.csv"
write_csv(ndvi_lst_merged, output_path)

cat("\nMerged satellite file saved to:", output_path, "\n")
cat("Satellite data merge complete.\n")

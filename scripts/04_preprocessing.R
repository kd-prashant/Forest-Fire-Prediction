# ============================================================
# 04_preprocessing.R
#
# Cleans the merged dataset and prepares it for model training.
#
# Steps:
#   1. Drop rows with too many missing values
#   2. Fill remaining missing values (imputation)
#   3. Encode the district column as numbers (models need numbers)
#   4. Scale numeric features (important for TabNet and LR)
#   5. Split into train and test sets (stratified)
#   6. Save everything ready for modelling
#
# INPUT:  data/processed/merged_dataset.csv
# OUTPUT: data/processed/train_set.csv
#         data/processed/test_set.csv
#         data/processed/preprocessing_info.rds  (scaling params)
# ============================================================

library(dplyr)
library(readr)
library(caret)   # for createDataPartition (stratified split)

set.seed(42)  # makes results reproducible — use same seed every time

# -----------------------------------------------------------
# Load the merged dataset
# -----------------------------------------------------------
cat("Loading merged dataset...\n")
data <- read_csv("data/processed/merged_dataset.csv",
                 show_col_types = FALSE)

cat("Rows:", nrow(data), "| Columns:", ncol(data), "\n")

# -----------------------------------------------------------
# Step 1: Drop rows where the weather data is missing.
#
# The key weather features (temperature, humidity, rainfall, wind)
# must exist. If all four are missing for a row, that row is useless.
# -----------------------------------------------------------
key_weather_cols <- c("avg_temp", "avg_humidity", "weekly_rain", "avg_wind")

rows_before <- nrow(data)
data <- data %>%
  filter(!if_all(all_of(key_weather_cols), is.na))

cat("Rows dropped due to missing weather:", rows_before - nrow(data), "\n")
cat("Rows remaining:", nrow(data), "\n")

# -----------------------------------------------------------
# Step 2: Fill remaining missing values.
#
# For numeric columns: fill with the column median.
# Median is better than mean here because it's not affected
# by extreme values (e.g., a very high temperature spike).
#
# For NDVI/LST: if satellite data wasn't loaded yet, those
# columns won't exist — we just skip them safely.
# -----------------------------------------------------------
cat("Imputing missing values with column medians...\n")

numeric_cols <- c("avg_temp", "avg_humidity", "weekly_rain",
                  "avg_wind", "max_consec_dry_days")

# Only add satellite columns if they exist in the dataset
if ("avg_ndvi" %in% names(data)) numeric_cols <- c(numeric_cols, "avg_ndvi")
if ("avg_lst"  %in% names(data)) numeric_cols <- c(numeric_cols, "avg_lst")

for (col in numeric_cols) {
  if (col %in% names(data)) {
    col_median <- median(data[[col]], na.rm = TRUE)
    data[[col]][is.na(data[[col]])] <- col_median
    cat("  Filled missing in", col, "with median:", round(col_median, 3), "\n")
  }
}

# -----------------------------------------------------------
# Step 3: Encode the district column.
#
# Machine learning models work with numbers, not text.
# We convert district names to integer codes (1, 2, 3, 4, 5).
# We also save the mapping so we can decode predictions later.
# -----------------------------------------------------------
district_levels <- sort(unique(data$district))
data$district_encoded <- as.integer(factor(data$district,
                                           levels = district_levels))

cat("\nDistrict encoding:\n")
for (i in seq_along(district_levels)) {
  cat("  ", i, "=", district_levels[i], "\n")
}

# -----------------------------------------------------------
# Step 4: Select final feature columns for modelling.
#
# We drop: district (text), week_start (date), week_of_yr
# (redundant with month for our purposes).
# We keep: all numeric weather features + encoded district + month.
# -----------------------------------------------------------
feature_cols <- c(
  "avg_temp", "avg_humidity", "weekly_rain", "avg_wind",
  "max_consec_dry_days", "month", "district_encoded"
)

# Add satellite features if available
if ("avg_ndvi" %in% names(data)) feature_cols <- c(feature_cols, "avg_ndvi")
if ("avg_lst"  %in% names(data)) feature_cols <- c(feature_cols, "avg_lst")

cat("\nFeatures used for modelling:", paste(feature_cols, collapse = ", "), "\n")

# -----------------------------------------------------------
# Step 5: Scale numeric features (min-max normalization).
#
# TabNet and Logistic Regression work much better when
# all features are on the same scale (0 to 1).
# Random Forest and XGBoost don't strictly need scaling,
# but it doesn't hurt them either — easier to keep consistent.
#
# We save the min and max for each column so that at
# prediction time (real-time demo), we can scale new input
# data the same way.
# -----------------------------------------------------------
cat("Scaling features to [0, 1] range...\n")

# Columns that need scaling (not month or district_encoded —
# those are already small integers and don't need scaling)
cols_to_scale <- c("avg_temp", "avg_humidity", "weekly_rain",
                   "avg_wind", "max_consec_dry_days")
if ("avg_ndvi" %in% names(data)) cols_to_scale <- c(cols_to_scale, "avg_ndvi")
if ("avg_lst"  %in% names(data)) cols_to_scale <- c(cols_to_scale, "avg_lst")

# Store scaling parameters (min and max of each column)
scaling_params <- list()

for (col in cols_to_scale) {
  col_min <- min(data[[col]], na.rm = TRUE)
  col_max <- max(data[[col]], na.rm = TRUE)
  scaling_params[[col]] <- list(min = col_min, max = col_max)

  # Apply min-max scaling: (value - min) / (max - min)
  data[[col]] <- (data[[col]] - col_min) / (col_max - col_min)
}

cat("Scaling complete.\n")

# -----------------------------------------------------------
# Step 6: Stratified train-test split (80% train, 20% test).
#
# "Stratified" means the split preserves the fire/no-fire ratio.
# If 15% of rows are fires, both train and test sets will be ~15% fires.
# This is important — a random split could put most fires in one set.
#
# The test set is set aside and NEVER used during training.
# We only use it at the very end to evaluate the final model.
# -----------------------------------------------------------
cat("Splitting data into 80% train / 20% test (stratified)...\n")

# createDataPartition returns indices for the training set
train_indices <- createDataPartition(
  y = data$fire_occurred,
  p = 0.80,
  list = FALSE
)

train_set <- data[ train_indices, ]
test_set  <- data[-train_indices, ]

cat("Training rows:", nrow(train_set), "\n")
cat("Test rows:    ", nrow(test_set),  "\n")

# Verify stratification preserved the balance
cat("Fire rate in train:", round(mean(train_set$fire_occurred) * 100, 1), "%\n")
cat("Fire rate in test: ", round(mean(test_set$fire_occurred)  * 100, 1), "%\n")

# -----------------------------------------------------------
# Save everything
# -----------------------------------------------------------

# Keep only the feature columns + target in the final sets
cols_to_keep <- c(feature_cols, "fire_occurred")

write_csv(train_set[, cols_to_keep], "data/processed/train_set.csv")
write_csv(test_set[, cols_to_keep],  "data/processed/test_set.csv")

# Save scaling params and district encoding — needed later for
# the real-time demo (to scale incoming forecast data the same way)
preprocessing_info <- list(
  scaling_params   = scaling_params,
  district_levels  = district_levels,
  feature_cols     = feature_cols
)
saveRDS(preprocessing_info, "data/processed/preprocessing_info.rds")

cat("\nTrain set saved to: data/processed/train_set.csv\n")
cat("Test set  saved to: data/processed/test_set.csv\n")
cat("Preprocessing info saved to: data/processed/preprocessing_info.rds\n")
cat("Script 04 complete.\n")

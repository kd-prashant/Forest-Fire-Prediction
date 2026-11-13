# ==============================================================================
# 08_interpretability.R
# Explainable Artificial Intelligence (XAI) and Biophysical Factor Attribution
# Methodologies: Gini Impurity, Gradient Information Gain, Shapley Additive Explanations
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(randomForest)
  library(xgboost)
  library(shapviz)
})

cat("==============================================================================\n")
cat("                EXPLAINABLE AI (XAI) & FACTOR ATTRIBUTION                     \n")
cat("==============================================================================\n\n")

dir.create("outputs/plots", recursive = TRUE, showWarnings = FALSE)

# 1. Model and Test Data Ingestion
cat("[1/4] Ingesting serialized models and independent test observations...\n")
test_df <- read_csv("data/processed/test_set.csv", show_col_types = FALSE)
feature_names <- setdiff(names(test_df), "fire_occurred")

rf_model  <- readRDS("outputs/models/random_forest.rds")
xgb_model <- readRDS("outputs/models/xgboost.rds")

feature_labels <- c(
  "avg_temp"            = "Air Temperature (Weekly Mean)",
  "avg_humidity"        = "Relative Humidity (Weekly Mean)",
  "weekly_rain"         = "Total Weekly Rainfall",
  "avg_wind"            = "Wind Speed (Weekly Mean)",
  "max_consec_dry_days" = "Consecutive Dry Days (Streak)",
  "month"               = "Month of Year (Seasonality)",
  "district_encoded"    = "District Geography & Terrain",
  "avg_ndvi"            = "Vegetation Moisture (MODIS NDVI)",
  "avg_lst"             = "Land Surface Temp (MODIS LST)"
)

# 2. Random Forest Importance Metrics
cat("[2/4] Extracting Random Forest Impurity Reductions (Mean Decrease in Accuracy & Gini)...\n")
rf_imp <- as.data.frame(importance(rf_model))
rf_imp$Feature <- rownames(rf_imp)
rf_imp$FeatureLabel <- feature_labels[rf_imp$Feature]
if (any(is.na(rf_imp$FeatureLabel))) {
  rf_imp$FeatureLabel[is.na(rf_imp$FeatureLabel)] <- rf_imp$Feature[is.na(rf_imp$FeatureLabel)]
}

# 3. XGBoost Importance Metrics
cat("[3/4] Quantifying Tree Boosting Gain Contributions...\n")
xgb_imp <- xgb.importance(model = xgb_model)
xgb_imp$FeatureLabel <- feature_labels[xgb_imp$Feature]
if (any(is.na(xgb_imp$FeatureLabel))) {
  xgb_imp$FeatureLabel[is.na(xgb_imp$FeatureLabel)] <- xgb_imp$Feature[is.na(xgb_imp$FeatureLabel)]
}

xgb_plot_df <- xgb_imp %>%
  mutate(FeatureLabel = factor(FeatureLabel, levels = rev(FeatureLabel)))

p_imp <- ggplot(xgb_plot_df, aes(x = FeatureLabel, y = Gain, fill = Gain)) +
  geom_col(width = 0.65, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.1f%%", Gain * 100)), hjust = -0.15, size = 3.5, fontface = "bold") +
  coord_flip() +
  scale_fill_gradient(low = "#fdae61", high = "#d7191c") +
  theme_minimal(base_size = 12) +
  ylim(0, max(xgb_plot_df$Gain) * 1.15) +
  labs(
    title    = "Predictor Relative Information Gain (XGBoost)",
    subtitle = "Relative contribution of atmospheric and biophysical variables in node splitting",
    x        = "Predictive Feature",
    y        = "Fractional Information Gain"
  ) +
  theme(
    plot.title       = element_text(face = "bold", size = 13),
    panel.grid.minor = element_blank()
  )

ggsave("outputs/plots/feature_importance.png", plot = p_imp, width = 8.5, height = 5.5, dpi = 300)
cat("  Plot generated: outputs/plots/feature_importance.png\n\n")

# 4. SHAP (Shapley Additive Explanations)
cat("[4/4] Computing Game-Theoretic Shapley Values for Test Partition...\n")
x_test_mat <- as.matrix(test_df[, feature_names])

shap_obj <- shapviz(xgb_model, X_pred = x_test_mat)

# Global Mean |SHAP| Bar Chart
p_shap_bar <- sv_importance(shap_obj, kind = "bar", fill = "#2b83ba") +
  theme_minimal(base_size = 12) +
  labs(
    title    = "Mean Absolute SHAP Magnitude (Global Attribution)",
    subtitle = "Average absolute contribution of predictors to model log-odds output"
  ) +
  theme(plot.title = element_text(face = "bold"))

ggsave("outputs/plots/shap_importance_bar.png", plot = p_shap_bar, width = 8, height = 5, dpi = 300)
cat("  Plot generated: outputs/plots/shap_importance_bar.png\n")

# SHAP Beeswarm Distribution
p_shap_beeswarm <- sv_importance(shap_obj, kind = "beeswarm") +
  theme_minimal(base_size = 12) +
  labs(
    title    = "SHAP Summary Beeswarm Distribution (Directional Effect)",
    subtitle = "Visualizing the directional impact: High feature values in Red, Low in Blue"
  ) +
  theme(plot.title = element_text(face = "bold"))

ggsave("outputs/plots/shap_summary_beeswarm.png", plot = p_shap_beeswarm, width = 8.5, height = 5.5, dpi = 300)
cat("  Plot generated: outputs/plots/shap_summary_beeswarm.png\n\n")

cat("==============================================================================\n")
cat("                  PREDICTOR ATTRIBUTION RANKING (XGBOOST GAIN)                \n")
cat("==============================================================================\n")
print(as.data.frame(xgb_imp %>% select(Feature, FeatureLabel, Gain, Cover, Frequency)), row.names = FALSE)
cat("\nExplainable AI analysis serialized to outputs/plots/\n")

# ==============================================================================
# 07_evaluation.R
# Comparative Performance Benchmarking and Metric Visualizations
# Visualizations: Multi-Model ROC Curves, Metric Breakdown, Confusion Matrices
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(pROC)
  library(tidyr)
})

cat("==============================================================================\n")
cat("                MODEL EVALUATION AND ANALYTICAL VISUALIZATIONS                \n")
cat("==============================================================================\n\n")

dir.create("outputs/plots", recursive = TRUE, showWarnings = FALSE)

pred_file <- if (file.exists("outputs/all_model_predictions.csv")) {
  "outputs/all_model_predictions.csv"
} else if (file.exists("outputs/baseline_predictions.csv")) {
  "outputs/baseline_predictions.csv"
} else {
  stop("Missing prediction logs in outputs/.")
}

cat("Ingesting prediction matrix from:", pred_file, "\n")
preds <- read_csv(pred_file, show_col_types = FALSE)

actual <- preds$actual_fire
prob_cols <- grep("^prob_", names(preds), value = TRUE)

model_names <- gsub("^prob_", "", prob_cols)
model_names <- gsub("_", " ", model_names)
model_names <- tools::toTitleCase(model_names)

cat("Models registered for evaluation:\n")
for (i in seq_along(prob_cols)) {
  cat(sprintf("  [%d] %s\n", i, model_names[i]))
}
cat("\n")

roc_list <- list()
auc_df <- data.frame(Model = character(), AUC = numeric(), stringsAsFactors = FALSE)

for (i in seq_along(prob_cols)) {
  p_col <- prob_cols[i]
  m_name <- model_names[i]
  roc_obj <- roc(actual, preds[[p_col]], quiet = TRUE)
  roc_list[[m_name]] <- roc_obj
  auc_df <- rbind(auc_df, data.frame(Model = m_name, AUC = as.numeric(auc(roc_obj))))
}

# 1. Multi-Model ROC Curves
cat("[1/3] Generating Receiver Operating Characteristic (ROC) Comparison Plot...\n")

roc_data_list <- list()
for (m_name in names(roc_list)) {
  r <- roc_list[[m_name]]
  auc_val <- round(as.numeric(auc(r)), 4)
  df <- data.frame(
    FPR = 1 - r$specificities,
    TPR = r$sensitivities,
    Model = paste0(m_name, " (AUC = ", auc_val, ")")
  )
  roc_data_list[[m_name]] <- df
}
roc_combined <- bind_rows(roc_data_list)

p_roc <- ggplot(roc_combined, aes(x = FPR, y = TPR, color = Model)) +
  geom_line(linewidth = 1.1) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray50") +
  theme_minimal(base_size = 13) +
  scale_color_brewer(palette = "Set1") +
  labs(
    title    = "Multi-Model ROC Trajectories (Uttarakhand Test Set, N = 314)",
    subtitle = "Discrimination benchmark against NASA FIRMS ground truth labels",
    x        = "False Positive Rate (1 - Specificity)",
    y        = "True Positive Rate (Sensitivity / Recall)",
    color    = "Model Architecture"
  ) +
  theme(
    legend.position   = "bottom",
    legend.title      = element_blank(),
    panel.grid.minor  = element_blank(),
    plot.title        = element_text(face = "bold", size = 14),
    plot.subtitle     = element_text(color = "gray30", size = 10)
  )

ggsave("outputs/plots/roc_curves_comparison.png", plot = p_roc, width = 8, height = 6, dpi = 300)
cat("  Plot generated: outputs/plots/roc_curves_comparison.png\n\n")

# 2. Comparative Metric Bar Chart
cat("[2/3] Generating Performance Metrics Benchmark Plot...\n")

metrics_file <- if (file.exists("outputs/all_model_metrics.csv")) {
  "outputs/all_model_metrics.csv"
} else {
  "outputs/baseline_metrics.csv"
}

metrics_data <- read_csv(metrics_file, show_col_types = FALSE)

metrics_long <- metrics_data %>%
  select(Model, Accuracy, Recall, Precision, F1_Score, AUC_ROC) %>%
  pivot_longer(cols = -Model, names_to = "Metric", values_to = "Value") %>%
  mutate(Metric = factor(Metric, levels = c("Recall", "F1_Score", "Precision", "AUC_ROC", "Accuracy")))

p_metrics <- ggplot(metrics_long, aes(x = Metric, y = Value, fill = Model)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = sprintf("%.2f", Value)),
            position = position_dodge(width = 0.8), vjust = -0.4, size = 3.0, fontface = "bold") +
  ylim(0, 1.05) +
  theme_minimal(base_size = 12) +
  scale_fill_brewer(palette = "Dark2") +
  labs(
    title    = "Classifier Benchmark Across Standard Quantitative Metrics",
    subtitle = "Evaluation prioritizing Sensitivity (Recall) and F1 Harmonic Mean for Wildfire Hazard",
    x        = "Performance Metric",
    y        = "Score [0 - 1]",
    fill     = "Architecture"
  ) +
  theme(
    legend.position  = "bottom",
    plot.title       = element_text(face = "bold", size = 13),
    panel.grid.minor = element_blank()
  )

ggsave("outputs/plots/model_metrics_comparison.png", plot = p_metrics, width = 9, height = 5.5, dpi = 300)
cat("  Plot generated: outputs/plots/model_metrics_comparison.png\n\n")

# 3. Confusion Matrices
cat("[3/3] Generating Confusion Matrices across Models...\n")

cm_list <- list()
for (i in seq_along(prob_cols)) {
  p_col <- prob_cols[i]
  m_name <- model_names[i]
  pred_binary <- ifelse(preds[[p_col]] >= 0.5, 1, 0)
  
  tbl <- table(Actual = factor(actual, levels = c(0, 1)),
               Predicted = factor(pred_binary, levels = c(0, 1)))
  
  df_cm <- as.data.frame(tbl)
  df_cm$Model <- m_name
  df_cm$Type <- ifelse(df_cm$Actual == 1 & df_cm$Predicted == 1, "TP",
                ifelse(df_cm$Actual == 0 & df_cm$Predicted == 0, "TN",
                ifelse(df_cm$Actual == 0 & df_cm$Predicted == 1, "FP", "FN")))
  cm_list[[m_name]] <- df_cm
}
cm_all <- bind_rows(cm_list)

cm_all$ActualLabel <- ifelse(cm_all$Actual == 1, "Actual Fire (1)", "No Fire (0)")
cm_all$PredLabel   <- ifelse(cm_all$Predicted == 1, "Predicted Fire (1)", "No Fire (0)")

p_cm <- ggplot(cm_all, aes(x = PredLabel, y = ActualLabel, fill = Freq)) +
  geom_tile(color = "white", linewidth = 1) +
  geom_text(aes(label = paste0(Freq, "\n(", Type, ")")), size = 4.2, fontface = "bold", color = "white") +
  facet_wrap(~ Model) +
  scale_fill_gradient(low = "#4575b4", high = "#d73027") +
  theme_minimal(base_size = 11) +
  labs(
    title    = "Empirical Confusion Matrices (Decision Boundary = 0.50)",
    subtitle = "TP: True Positive | FN: False Negative (Omission) | FP: False Positive (Commission) | TN: True Negative",
    x        = "Predicted Classification",
    y        = "Observed Label"
  ) +
  theme(
    plot.title      = element_text(face = "bold"),
    legend.position = "none",
    strip.text      = element_text(face = "bold", size = 11)
  )

ggsave("outputs/plots/confusion_matrices.png", plot = p_cm, width = 8.5, height = 6.5, dpi = 300)
cat("  Plot generated: outputs/plots/confusion_matrices.png\n\n")

cat("==============================================================================\n")
cat("                       EVALUATION SUMMARY & RANKING                           \n")
cat("==============================================================================\n")
print(as.data.frame(metrics_data), row.names = FALSE)
cat("\nVisualizations serialized to outputs/plots/\n")

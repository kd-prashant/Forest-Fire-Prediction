# ==============================================================================
# 11_hyperparameter_tuning.R
# XGBoost Hyperparameter Optimization via 5-Fold Cross-Validated Grid Search
# ROSE-Balanced Training Data | Caret Framework
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(xgboost)
  library(caret)
  library(pROC)
  library(ROSE)
  library(ggplot2)
  library(tidyr)
})

set.seed(42)

cat("==============================================================================\n")
cat("       XGBOOST HYPERPARAMETER OPTIMIZATION — 5-FOLD CROSS-VALIDATION         \n")
cat("==============================================================================\n\n")

dir.create("outputs/models", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/plots",  recursive = TRUE, showWarnings = FALSE)

# 1. Dataset Ingestion
cat("[1/6] Ingesting training and testing partitions...\n")
train_df <- read_csv("data/processed/train_set.csv", show_col_types = FALSE)
test_df  <- read_csv("data/processed/test_set.csv",  show_col_types = FALSE)

feature_names <- setdiff(names(train_df), "fire_occurred")

cat(sprintf("  Training partition: N = %d | Testing partition: N = %d\n",
            nrow(train_df), nrow(test_df)))
cat(sprintf("  Predictor dimensionality: P = %d\n\n", length(feature_names)))

# 2. ROSE Imbalance Remediation (identical to 05_baseline_models.R)
cat("[2/6] Applying ROSE oversampling on training partition (method = 'both')...\n")
train_balanced <- ovun.sample(fire_occurred ~ ., data = train_df,
                              method = "both", p = 0.5, seed = 42)$data

cat(sprintf("  Pre-ROSE  : [Class 0: %d, Class 1: %d]\n",
            sum(train_df$fire_occurred == 0), sum(train_df$fire_occurred == 1)))
cat(sprintf("  Post-ROSE : [Class 0: %d, Class 1: %d]\n\n",
            sum(train_balanced$fire_occurred == 0), sum(train_balanced$fire_occurred == 1)))

# Convert target for caret (factor with valid R names)
train_balanced$fire_factor <- factor(train_balanced$fire_occurred,
                                     levels = c(0, 1), labels = c("No", "Yes"))

# 3. Hyperparameter Grid Search via xgb.cv (native XGBoost cross-validation)
# NOTE: caret's xgbTree method is incompatible with XGBoost >= 2.0 due to
#       ALTLIST pointer handling changes. xgb.cv provides equivalent 5-fold CV.
cat("[3/6] Initiating 5-fold cross-validated grid search via xgb.cv...\n")

tune_grid <- expand.grid(
  nrounds          = c(100, 150),
  max_depth        = c(3, 5, 7),
  eta              = c(0.05, 0.1),
  gamma            = 0,
  colsample_bytree = 0.8,
  min_child_weight = 1,
  subsample        = 0.8,
  stringsAsFactors = FALSE
)

cat(sprintf("  Grid size: %d candidate configurations\n", nrow(tune_grid)))
cat("  Resampling: 5-Fold Cross-Validation | Metric: AUC-ROC\n\n")

x_train_mat <- as.matrix(train_balanced[, feature_names])
y_train_vec  <- train_balanced$fire_occurred
x_test_mat   <- as.matrix(test_df[, feature_names])
y_test_vec   <- test_df$fire_occurred

dtrain <- xgb.DMatrix(data = x_train_mat, label = y_train_vec)
dtest  <- xgb.DMatrix(data = x_test_mat,  label = y_test_vec)

cv_start <- Sys.time()
cv_results <- vector("list", nrow(tune_grid))

for (i in seq_len(nrow(tune_grid))) {
  params_i <- list(
    objective        = "binary:logistic",
    eval_metric      = "auc",
    max_depth        = tune_grid$max_depth[i],
    eta              = tune_grid$eta[i],
    subsample        = tune_grid$subsample[i],
    colsample_bytree = tune_grid$colsample_bytree[i],
    min_child_weight = tune_grid$min_child_weight[i],
    gamma            = tune_grid$gamma[i]
  )

  cv_out <- xgb.cv(
    params   = params_i,
    data     = dtrain,
    nrounds  = tune_grid$nrounds[i],
    nfold    = 5,
    verbose  = FALSE,
    early_stopping_rounds = 20,
    metrics  = "auc"
  )

  best_auc <- max(cv_out$evaluation_log$test_auc_mean, na.rm = TRUE)
  best_iter <- which.max(cv_out$evaluation_log$test_auc_mean)

  cv_results[[i]] <- data.frame(
    nrounds          = tune_grid$nrounds[i],
    max_depth        = tune_grid$max_depth[i],
    eta              = tune_grid$eta[i],
    subsample        = tune_grid$subsample[i],
    colsample_bytree = tune_grid$colsample_bytree[i],
    min_child_weight = tune_grid$min_child_weight[i],
    best_auc         = round(best_auc, 5),
    best_iter        = best_iter
  )

  cat(sprintf("  Config %2d/%d | depth=%d eta=%.2f rounds=%d | CV AUC=%.5f\n",
              i, nrow(tune_grid),
              tune_grid$max_depth[i], tune_grid$eta[i], tune_grid$nrounds[i],
              best_auc))
}

cv_elapsed <- as.numeric(difftime(Sys.time(), cv_start, units = "secs"))
cat(sprintf("\n  Grid search completed in %.1f seconds.\n", cv_elapsed))

cv_summary <- do.call(rbind, cv_results)
best_row    <- cv_summary[which.max(cv_summary$best_auc), ]

best_params <- list(
  nrounds          = best_row$nrounds,
  max_depth        = best_row$max_depth,
  eta              = best_row$eta,
  subsample        = best_row$subsample,
  colsample_bytree = best_row$colsample_bytree,
  min_child_weight = best_row$min_child_weight,
  gamma            = 0
)

cat("\n  Best Hyperparameter Configuration (5-Fold CV):\n")
cat("  ", paste(rep("-", 55), collapse = ""), "\n", sep = "")
cat(sprintf("  nrounds          : %d\n",   best_params$nrounds))
cat(sprintf("  max_depth        : %d\n",   best_params$max_depth))
cat(sprintf("  eta (learn rate) : %.3f\n", best_params$eta))
cat(sprintf("  subsample        : %.2f\n", best_params$subsample))
cat(sprintf("  colsample_bytree : %.2f\n", best_params$colsample_bytree))
cat(sprintf("  min_child_weight : %d\n",   best_params$min_child_weight))
cat(sprintf("  Best CV AUC      : %.5f\n", best_row$best_auc))
cat("  ", paste(rep("-", 55), collapse = ""), "\n\n", sep = "")

# 4. Retrain Final XGBoost with Best Parameters on Full Balanced Training Data
cat("[4/6] Retraining final XGBoost with optimized hyperparameters...\n")

x_train_mat <- as.matrix(train_balanced[, feature_names])
y_train_vec  <- train_balanced$fire_occurred
x_test_mat   <- as.matrix(test_df[, feature_names])
y_test_vec   <- test_df$fire_occurred

dtrain <- xgb.DMatrix(data = x_train_mat, label = y_train_vec)
dtest  <- xgb.DMatrix(data = x_test_mat,  label = y_test_vec)

final_params <- list(
  objective        = "binary:logistic",
  eval_metric      = "auc",
  max_depth        = best_params$max_depth,
  eta              = best_params$eta,
  subsample        = best_params$subsample,
  colsample_bytree = best_params$colsample_bytree,
  min_child_weight = best_params$min_child_weight,
  gamma            = best_params$gamma
)

model_xgb_tuned <- xgb.train(
  params  = final_params,
  data    = dtrain,
  nrounds = best_params$nrounds,
  evals   = list(train = dtrain, test = dtest),
  verbose = 0
)

cat(sprintf("  Retrained with nrounds = %d | Evaluation: binary:logistic\n\n",
            best_params$nrounds))

# 5. Evaluation on Held-Out Test Partition
cat("[5/6] Evaluating tuned and baseline models on held-out test partition...\n")

compute_metrics <- function(actual, pred_prob, threshold = 0.5, model_name = "Model") {
  pred_class <- ifelse(pred_prob >= threshold, 1, 0)

  cm <- confusionMatrix(
    factor(pred_class, levels = c(0, 1)),
    factor(actual,     levels = c(0, 1)),
    positive = "1"
  )

  roc_obj <- roc(actual, pred_prob, quiet = TRUE)
  auc_val <- as.numeric(auc(roc_obj))

  acc  <- as.numeric(cm$overall["Accuracy"])
  sens <- as.numeric(cm$byClass["Sensitivity"])
  spec <- as.numeric(cm$byClass["Specificity"])
  prec <- as.numeric(cm$byClass["Precision"])
  f1   <- as.numeric(cm$byClass["F1"])

  if (is.na(prec)) prec <- 0
  if (is.na(f1))   f1   <- 0

  data.frame(
    Model       = model_name,
    Accuracy    = round(acc,     4),
    Recall      = round(sens,    4),
    Precision   = round(prec,    4),
    F1_Score    = round(f1,      4),
    Specificity = round(spec,    4),
    AUC_ROC     = round(auc_val, 4)
  )
}

# Tuned model
prob_tuned   <- predict(model_xgb_tuned, newdata = dtest)
metrics_tuned <- compute_metrics(y_test_vec, prob_tuned,
                                 threshold = 0.5, model_name = "XGBoost (Tuned)")

# Baseline untuned model (reload serialized artifact)
model_xgb_baseline <- readRDS("outputs/models/xgboost.rds")
prob_baseline <- predict(model_xgb_baseline, newdata = dtest)
metrics_baseline <- compute_metrics(y_test_vec, prob_baseline,
                                    threshold = 0.5, model_name = "XGBoost (Baseline)")

cat("\n  Comparative Evaluation — Tuned vs. Baseline XGBoost:\n")
cat("  ", paste(rep("-", 72), collapse = ""), "\n", sep = "")
cat(sprintf("  %-22s %9s %9s %9s %9s %9s\n",
            "Configuration", "Accuracy", "Recall", "F1", "AUC", "Specificity"))
cat("  ", paste(rep("-", 72), collapse = ""), "\n", sep = "")
cat(sprintf("  %-22s %9.4f %9.4f %9.4f %9.4f %9.4f\n",
            metrics_baseline$Model, metrics_baseline$Accuracy,
            metrics_baseline$Recall, metrics_baseline$F1_Score,
            metrics_baseline$AUC_ROC, metrics_baseline$Specificity))
cat(sprintf("  %-22s %9.4f %9.4f %9.4f %9.4f %9.4f\n",
            metrics_tuned$Model, metrics_tuned$Accuracy,
            metrics_tuned$Recall, metrics_tuned$F1_Score,
            metrics_tuned$AUC_ROC, metrics_tuned$Specificity))
cat("  ", paste(rep("-", 72), collapse = ""), "\n\n", sep = "")

# Delta comparison
delta_acc  <- metrics_tuned$Accuracy  - metrics_baseline$Accuracy
delta_rec  <- metrics_tuned$Recall    - metrics_baseline$Recall
delta_f1   <- metrics_tuned$F1_Score  - metrics_baseline$F1_Score
delta_auc  <- metrics_tuned$AUC_ROC   - metrics_baseline$AUC_ROC
cat("  Performance Delta (Tuned - Baseline):\n")
cat(sprintf("    Accuracy : %+.4f | Recall : %+.4f | F1 : %+.4f | AUC : %+.4f\n\n",
            delta_acc, delta_rec, delta_f1, delta_auc))

# 6. Persistence and Logging
cat("[6/6] Serializing artifacts and appending metrics to benchmark log...\n")

saveRDS(model_xgb_tuned, "outputs/models/xgboost_tuned.rds")
cat("  Tuned model serialized: outputs/models/xgboost_tuned.rds\n")

# Append tuned row to all_model_metrics.csv
existing_metrics <- read_csv("outputs/all_model_metrics.csv", show_col_types = FALSE)

# Remove any prior tuned entry to avoid duplicates
existing_metrics <- existing_metrics %>%
  filter(Model != "XGBoost (Tuned)")

updated_metrics <- bind_rows(existing_metrics, metrics_tuned)
write_csv(updated_metrics, "outputs/all_model_metrics.csv")
cat("  Benchmark metrics appended: outputs/all_model_metrics.csv\n")

# Comparison plot
compare_df <- bind_rows(metrics_baseline, metrics_tuned) %>%
  pivot_longer(cols = c(Accuracy, Recall, F1_Score, AUC_ROC),
               names_to  = "Metric",
               values_to = "Value") %>%
  mutate(
    Metric = recode(Metric,
                    "Accuracy" = "Accuracy",
                    "Recall"   = "Recall (Sensitivity)",
                    "F1_Score" = "F1-Score",
                    "AUC_ROC"  = "AUC-ROC"),
    Model  = factor(Model, levels = c("XGBoost (Baseline)", "XGBoost (Tuned)"))
  )

p_compare <- ggplot(compare_df, aes(x = Metric, y = Value, fill = Model)) +
  geom_col(position = position_dodge(width = 0.65), width = 0.6,
           color = "white", linewidth = 0.3) +
  geom_text(aes(label = sprintf("%.4f", Value)),
            position = position_dodge(width = 0.65),
            vjust = -0.5, size = 3.1, fontface = "bold", color = "grey25") +
  scale_fill_manual(values = c("XGBoost (Baseline)" = "#6baed6",
                               "XGBoost (Tuned)"    = "#08519c")) +
  scale_y_continuous(limits = c(0, 1.08), breaks = seq(0, 1, 0.1),
                     expand = expansion(mult = c(0, 0))) +
  labs(
    title    = "XGBoost Hyperparameter Tuning — Performance Comparison",
    subtitle = "5-fold cross-validated grid search vs. baseline configuration",
    x        = "Evaluation Metric",
    y        = "Score",
    fill     = "Configuration",
    caption  = paste0("Grid: max_depth \u2208 {3,5,7}, eta \u2208 {0.05,0.1}, ",
                      "nrounds \u2208 {100,150} | Resampling: 5-Fold CV")
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title      = element_text(face = "bold", size = 13, hjust = 0),
    plot.subtitle   = element_text(size = 10, color = "grey40", hjust = 0),
    plot.caption    = element_text(size = 8, color = "grey55"),
    axis.text.x     = element_text(size = 10),
    axis.text.y     = element_text(size = 9),
    legend.position = "top",
    legend.title    = element_text(face = "bold", size = 10),
    panel.grid.major.x = element_blank(),
    panel.grid.minor   = element_blank(),
    plot.margin     = margin(12, 16, 10, 12)
  )

ggsave("outputs/plots/tuning_comparison.png", p_compare,
       width = 9, height = 5.5, dpi = 180, bg = "white")
cat("  Comparison plot serialized: outputs/plots/tuning_comparison.png\n\n")

cat("==============================================================================\n")
cat("                  UPDATED FULL BENCHMARK — ALL MODELS                        \n")
cat("==============================================================================\n")
print(as.data.frame(updated_metrics), row.names = FALSE)
cat("\n==============================================================================\n")
cat("              XGBOOST HYPERPARAMETER TUNING — COMPLETE                       \n")
cat("==============================================================================\n")
cat("Artifacts generated:\n")
cat("  outputs/models/xgboost_tuned.rds\n")
cat("  outputs/plots/tuning_comparison.png\n")
cat("  outputs/all_model_metrics.csv (updated)\n")

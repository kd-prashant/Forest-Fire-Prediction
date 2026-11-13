# ==============================================================================
# 06_tabnet_model.R
# TabNet Deep Learning Architecture Training and Benchmarking
# Attentive Interpretable Tabular Learning (Google Cloud AI / PyTorch backend)
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tabnet)
  library(torch)
  library(caret)
  library(pROC)
  library(ROSE)
})

set.seed(42)
torch_manual_seed(42)

cat("==============================================================================\n")
cat("                TRAINING PROPOSED TABNET DEEP LEARNING MODEL                  \n")
cat("==============================================================================\n\n")

# 1. Dataset Ingestion
cat("[1/4] Ingesting training and testing partitions...\n")
train_df <- read_csv("data/processed/train_set.csv", show_col_types = FALSE)
test_df  <- read_csv("data/processed/test_set.csv",  show_col_types = FALSE)

feature_names <- setdiff(names(train_df), "fire_occurred")

# 2. Imbalance Remediation via ROSE
cat("[2/4] Applying ROSE synthetic oversampling for neural convergence...\n")
train_balanced <- ovun.sample(fire_occurred ~ ., data = train_df, method = "both", p = 0.5, seed = 42)$data

train_balanced$fire_occurred <- factor(train_balanced$fire_occurred, levels = c(0, 1), labels = c("No", "Yes"))
test_factor_y <- factor(test_df$fire_occurred, levels = c(0, 1), labels = c("No", "Yes"))

# 3. Model Optimization
cat("[3/4] Optimizing TabNet architecture via Sparsemax Attention Mechanism...\n")
cat("  Hyperparameters: Steps = 4 | Decision Width = 16 | Attention Width = 16\n")
cat("  Optimization: Adam (lr = 0.02) | Epochs = 20 | Batch Size = 64 | Valid Split = 0.15\n")

start_time <- Sys.time()

model_tabnet <- tabnet_fit(
  x = train_balanced[, feature_names],
  y = train_balanced$fire_occurred,
  config = tabnet_config(
    epochs          = 20,
    batch_size      = 64,
    decision_width  = 16,
    attention_width = 16,
    num_steps       = 4,
    penalty         = 0.001,
    feature_reusage = 1.3,
    mask_type       = "sparsemax",
    learn_rate      = 0.02,
    valid_split     = 0.15,
    verbose         = FALSE
  )
)

end_time <- Sys.time()
cat(sprintf("  Model convergence completed in %.1f seconds.\n", as.numeric(difftime(end_time, start_time, units = "secs"))))

saveRDS(model_tabnet, "outputs/models/tabnet_model.rds")
cat("  Serialized architecture: outputs/models/tabnet_model.rds\n\n")

# 4. Independent Test Evaluation
cat("[4/4] Evaluating TabNet on held-out test partition (N = 314)...\n")

test_probs_df <- predict(model_tabnet, new_data = test_df[, feature_names], type = "prob")
prob_tabnet <- test_probs_df$.pred_Yes

pred_class <- ifelse(prob_tabnet >= 0.5, "Yes", "No")
cm <- confusionMatrix(
  factor(pred_class, levels = c("No", "Yes")),
  test_factor_y,
  positive = "Yes"
)

roc_obj <- roc(test_df$fire_occurred, prob_tabnet, quiet = TRUE)
auc_val <- as.numeric(auc(roc_obj))

metrics_tabnet <- data.frame(
  Model       = "TabNet (Proposed Deep Learning)",
  Accuracy    = round(as.numeric(cm$overall["Accuracy"]), 4),
  Recall      = round(as.numeric(cm$byClass["Sensitivity"]), 4),
  Precision   = round(as.numeric(cm$byClass["Precision"]), 4),
  F1_Score    = round(as.numeric(cm$byClass["F1"]), 4),
  Specificity = round(as.numeric(cm$byClass["Specificity"]), 4),
  AUC_ROC     = round(auc_val, 4)
)

cat("  TabNet Generalization Metrics:\n")
cat(sprintf("    Accuracy:    %.4f\n", metrics_tabnet$Accuracy))
cat(sprintf("    Recall:      %.4f (True Positive Sensitivity)\n", metrics_tabnet$Recall))
cat(sprintf("    Precision:   %.4f\n", metrics_tabnet$Precision))
cat(sprintf("    F1-Score:    %.4f\n", metrics_tabnet$F1_Score))
cat(sprintf("    AUC-ROC:     %.4f\n\n", metrics_tabnet$AUC_ROC))

# Multi-Model Integration
base_preds <- read_csv("outputs/baseline_predictions.csv", show_col_types = FALSE)
base_preds$prob_tabnet <- prob_tabnet
write_csv(base_preds, "outputs/all_model_predictions.csv")

base_metrics <- read_csv("outputs/baseline_metrics.csv", show_col_types = FALSE)
all_metrics <- bind_rows(base_metrics, metrics_tabnet)
write_csv(all_metrics, "outputs/all_model_metrics.csv")

cat("==============================================================================\n")
cat("               FULL MODEL BENCHMARK: TABNET VS. BASELINES                     \n")
cat("==============================================================================\n")
print(as.data.frame(all_metrics), row.names = FALSE)
cat("\nModeling benchmark logged to outputs/all_model_metrics.csv\n")

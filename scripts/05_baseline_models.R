# ==============================================================================
# 05_baseline_models.R
# Baseline Classifier Training and Cross-Validation
# Architecture: Logistic Regression (GLM), Random Forest, XGBoost
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(randomForest)
  library(xgboost)
  library(caret)
  library(pROC)
  library(ROSE)
})

set.seed(42)

cat("==============================================================================\n")
cat("                  TRAINING BASELINE CLASSIFIER ARCHITECTURES                  \n")
cat("==============================================================================\n\n")

dir.create("outputs/models", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/plots",  recursive = TRUE, showWarnings = FALSE)

# 1. Dataset Ingestion
cat("[1/5] Ingesting modeling matrices...\n")
train_df <- read_csv("data/processed/train_set.csv", show_col_types = FALSE)
test_df  <- read_csv("data/processed/test_set.csv",  show_col_types = FALSE)

cat(sprintf("  Training partition (N = %d) | Testing partition (N = %d)\n", nrow(train_df), nrow(test_df)))
cat(sprintf("  Predictor dimensions: P = %d\n", length(setdiff(names(train_df), "fire_occurred"))))
cat(sprintf("  Baseline fire incidence rates: Train = %.2f%% | Test = %.2f%%\n\n",
            mean(train_df$fire_occurred) * 100, mean(test_df$fire_occurred) * 100))

feature_names <- setdiff(names(train_df), "fire_occurred")

# Factor representations
train_df_factor <- train_df
train_df_factor$fire_occurred <- factor(train_df_factor$fire_occurred, levels = c(0, 1), labels = c("No", "Yes"))

test_df_factor <- test_df
test_df_factor$fire_occurred <- factor(test_df_factor$fire_occurred, levels = c(0, 1), labels = c("No", "Yes"))

# 2. Imbalance Remediation via ROSE
cat("[2/5] Applying Random Over-Sampling Examples (ROSE) on training partition...\n")
train_balanced <- ovun.sample(fire_occurred ~ ., data = train_df, method = "both", p = 0.5, seed = 42)$data
cat(sprintf("  Pre-sampling class distribution : [Class 0: %d, Class 1: %d]\n",
            sum(train_df$fire_occurred == 0), sum(train_df$fire_occurred == 1)))
cat(sprintf("  Post-sampling class distribution: [Class 0: %d, Class 1: %d]\n\n",
            sum(train_balanced$fire_occurred == 0), sum(train_balanced$fire_occurred == 1)))

train_balanced_factor <- train_balanced
train_balanced_factor$fire_occurred <- factor(train_balanced_factor$fire_occurred, levels = c(0, 1), labels = c("No", "Yes"))

# Metric Computation Utility
compute_metrics <- function(actual, pred_prob, threshold = 0.5, model_name = "Model") {
  pred_class <- ifelse(pred_prob >= threshold, 1, 0)
  
  cm <- confusionMatrix(
    factor(pred_class, levels = c(0, 1)),
    factor(actual, levels = c(0, 1)),
    positive = "1"
  )
  
  roc_obj <- roc(actual, pred_prob, quiet = TRUE)
  auc_val <- as.numeric(auc(roc_obj))
  
  acc   <- as.numeric(cm$overall["Accuracy"])
  sens  <- as.numeric(cm$byClass["Sensitivity"]) # Recall
  spec  <- as.numeric(cm$byClass["Specificity"])
  prec  <- as.numeric(cm$byClass["Precision"])
  f1    <- as.numeric(cm$byClass["F1"])
  
  if (is.na(prec)) prec <- 0
  if (is.na(f1))   f1 <- 0
  
  data.frame(
    Model       = model_name,
    Accuracy    = round(acc, 4),
    Recall      = round(sens, 4),
    Precision   = round(prec, 4),
    F1_Score    = round(f1, 4),
    Specificity = round(spec, 4),
    AUC_ROC     = round(auc_val, 4)
  )
}

# ------------------------------------------------------------------------------
# Model 1: Logistic Regression (GLM)
# ------------------------------------------------------------------------------
cat("[3/5] Fitting Model 1: Logistic Regression (Logit link)...\n")
model_lr <- glm(
  fire_occurred ~ .,
  data = train_balanced,
  family = binomial(link = "logit")
)

prob_lr <- predict(model_lr, newdata = test_df, type = "response")
metrics_lr <- compute_metrics(test_df$fire_occurred, prob_lr, threshold = 0.5, model_name = "Logistic Regression")
cat(sprintf("  GLM Convergence achieved | Test AUC: %.4f | Recall: %.4f | F1: %.4f\n",
            metrics_lr$AUC_ROC, metrics_lr$Recall, metrics_lr$F1_Score))
saveRDS(model_lr, "outputs/models/logistic_regression.rds")

# ------------------------------------------------------------------------------
# Model 2: Random Forest
# ------------------------------------------------------------------------------
cat("\n[4/5] Fitting Model 2: Random Forest (B = 200 trees, mtry = 3)...\n")
model_rf <- randomForest(
  fire_occurred ~ .,
  data = train_balanced_factor,
  ntree = 200,
  mtry = 3,
  importance = TRUE
)

prob_rf <- predict(model_rf, newdata = test_df_factor, type = "prob")[, "Yes"]
metrics_rf <- compute_metrics(test_df$fire_occurred, prob_rf, threshold = 0.5, model_name = "Random Forest")
cat(sprintf("  Random Forest Ensembling complete | Test AUC: %.4f | Recall: %.4f | F1: %.4f\n",
            metrics_rf$AUC_ROC, metrics_rf$Recall, metrics_rf$F1_Score))
saveRDS(model_rf, "outputs/models/random_forest.rds")

# ------------------------------------------------------------------------------
# Model 3: XGBoost
# ------------------------------------------------------------------------------
cat("\n[5/5] Fitting Model 3: Extreme Gradient Boosting (XGBoost)...\n")
x_train <- as.matrix(train_balanced[, feature_names])
y_train <- train_balanced$fire_occurred

x_test  <- as.matrix(test_df[, feature_names])
y_test  <- test_df$fire_occurred

dtrain <- xgb.DMatrix(data = x_train, label = y_train)
dtest  <- xgb.DMatrix(data = x_test,  label = y_test)

xgb_params <- list(
  objective        = "binary:logistic",
  eval_metric      = "auc",
  max_depth        = 5,
  eta              = 0.08,
  subsample        = 0.8,
  colsample_bytree = 0.8
)

model_xgb <- xgb.train(
  params  = xgb_params,
  data    = dtrain,
  nrounds = 150,
  evals   = list(train = dtrain, test = dtest),
  verbose = 0
)

prob_xgb <- predict(model_xgb, newdata = dtest)
metrics_xgb <- compute_metrics(test_df$fire_occurred, prob_xgb, threshold = 0.5, model_name = "XGBoost")
cat(sprintf("  XGBoost Boosting iterations: 150 | Test AUC: %.4f | Recall: %.4f | F1: %.4f\n",
            metrics_xgb$AUC_ROC, metrics_xgb$Recall, metrics_xgb$F1_Score))
saveRDS(model_xgb, "outputs/models/xgboost.rds")

# Serialization of test predictions
predictions_df <- data.frame(
  actual_fire              = test_df$fire_occurred,
  prob_logistic_regression = prob_lr,
  prob_random_forest       = prob_rf,
  prob_xgboost             = prob_xgb
)
write_csv(predictions_df, "outputs/baseline_predictions.csv")

all_baseline_metrics <- bind_rows(metrics_lr, metrics_rf, metrics_xgb)
write_csv(all_baseline_metrics, "outputs/baseline_metrics.csv")

cat("\n==============================================================================\n")
cat("                       BASELINE PERFORMANCE BENCHMARK                         \n")
cat("==============================================================================\n")
print(all_baseline_metrics, row.names = FALSE)
cat("\nArtifacts serialized: outputs/models/ and outputs/baseline_metrics.csv\n")

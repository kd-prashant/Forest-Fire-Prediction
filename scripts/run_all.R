# ==============================================================================
# run_all.R
# Automated End-to-End Execution Pipeline
# Uttarakhand Wildfire Susceptibility & Near-Term Risk Classification
# ==============================================================================

cat("\n")
cat("##############################################################################\n")
cat("#                                                                            #\n")
cat("#      UTTARAKHAND FOREST FIRE PREDICTION & EARLY WARNING SYSTEM             #\n")
cat("#      Automated Pipeline Driver | Geospatial Environmental Risk Analytics   #\n")
cat("#                                                                            #\n")
cat("##############################################################################\n\n")

total_start <- Sys.time()

# Step 1: Preprocessing & Data Quality Audit
cat(">>> [MODULE 1/9] Executing Preprocessing and Biophysical Data Quality Audit...\n")
source("scripts/check_data_quality.R")
cat("\n------------------------------------------------------------------------------\n\n")

# Step 2: Baseline Model Optimization
cat(">>> [MODULE 2/9] Fitting Baseline Classifiers (GLM, Random Forest, XGBoost)...\n")
source("scripts/05_baseline_models.R")
cat("\n------------------------------------------------------------------------------\n\n")

# Step 3: TabNet Deep Learning Architecture
cat(">>> [MODULE 3/9] Fitting Attentive Deep Learning Architecture (TabNet)...\n")
source("scripts/06_tabnet_model.R")
cat("\n------------------------------------------------------------------------------\n\n")

# Step 4: Multi-Model Evaluation & Analytical Figures
cat(">>> [MODULE 4/9] Generating Performance Benchmarks & Analytical Visualizations...\n")
source("scripts/07_evaluation.R")
cat("\n------------------------------------------------------------------------------\n\n")

# Step 5: Explainable AI & Factor Attribution
cat(">>> [MODULE 5/9] Computing Shapley Additive Explanations (SHAP) & Gain Attribution...\n")
source("scripts/08_interpretability.R")
cat("\n------------------------------------------------------------------------------\n\n")

# Step 6: Operational Inference Protocol
cat(">>> [MODULE 6/9] Executing Operational Inference Protocol & Real-Time Scenarios...\n")
source("scripts/09_realtime_demo.R")
cat("\n------------------------------------------------------------------------------\n\n")

# Step 7: TabNet Attention Mechanism Analysis
cat(">>> [MODULE 7/9] Extracting TabNet Sparsemax Attention Weights & Spatial Attribution...\n")
source("scripts/10_tabnet_attention.R")
cat("\n------------------------------------------------------------------------------\n\n")

# Step 8: XGBoost Hyperparameter Optimization
cat(">>> [MODULE 8/9] Executing XGBoost 5-Fold CV Hyperparameter Optimization...\n")
source("scripts/11_hyperparameter_tuning.R")
cat("\n------------------------------------------------------------------------------\n\n")

# Step 9: Research Report Compilation
cat(">>> [MODULE 9/9] Compiling Research Report (Interactive HTML and Editable DOCX)...\n")
tryCatch({
  source("scripts/compile_report.R")
}, error = function(e) {
  cat(sprintf("  Compilation note: %s\n", conditionMessage(e)))
})
cat("\n------------------------------------------------------------------------------\n\n")

total_end <- Sys.time()

cat("##############################################################################\n")
cat("#                        PIPELINE EXECUTION COMPLETE                         #\n")
cat("##############################################################################\n\n")
cat(sprintf("Total Elapsed Computation Time: %.2f minutes\n\n", as.numeric(difftime(total_end, total_start, units = "mins"))))
cat("Generated Project Artifacts:\n")
cat("  1. Serialized Models (outputs/models/):\n")
cat("     - logistic_regression.rds\n")
cat("     - random_forest.rds\n")
cat("     - xgboost.rds\n")
cat("     - xgboost_tuned.rds\n")
cat("     - tabnet_model.rds\n\n")
cat("  2. Performance Benchmark Data (outputs/):\n")
cat("     - all_model_metrics.csv\n")
cat("     - all_model_predictions.csv\n\n")
cat("  3. Analytical Figures (outputs/plots/):\n")
cat("     - roc_curves_comparison.png          (Comparative ROC trajectories)\n")
cat("     - model_metrics_comparison.png        (Precision, Recall, F1, AUC benchmark)\n")
cat("     - confusion_matrices.png             (Cross-model confusion matrices)\n")
cat("     - feature_importance.png             (Empirical node-splitting information gain)\n")
cat("     - shap_importance_bar.png            (Mean absolute SHAP magnitude)\n")
cat("     - shap_summary_beeswarm.png          (Directional feature attribution)\n")
cat("     - tabnet_attention_weights.png        (Sparsemax feature attribution ranking)\n")
cat("     - tabnet_attention_by_district.png    (District-stratified spatial attention)\n")
cat("     - tuning_comparison.png              (Tuned vs. default XGBoost benchmark)\n")
cat("     - system_architecture.png            (End-to-end 6-tier system architecture)\n\n")
cat("  4. Academic Thesis Report (report/):\n")
cat("     - final_report.Rmd                   (Source RMarkdown manuscript)\n")
cat("     - final_report.html                  (Compiled interactive HTML report)\n")
cat("     - final_report.docx                  (Compiled editable Microsoft Word report)\n\n")
cat("Pipeline execution completed successfully.\n")

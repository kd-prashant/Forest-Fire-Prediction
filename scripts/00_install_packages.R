# ============================================================
# 00_install_packages.R
#
# Package dependency installation manifest.
# Installs required R packages from CRAN mirrors.
# ============================================================

# This is a helper function that checks if a package is already
# installed before trying to install it — avoids re-downloading.
install_if_missing <- function(package_name) {
  if (!requireNamespace(package_name, quietly = TRUE)) {
    cat("Installing:", package_name, "\n")
    install.packages(package_name, repos = "https://cran.rstudio.com/")
  } else {
    cat("Already installed:", package_name, "\n")
  }
}

# --- Core data packages ---
install_if_missing("dplyr")      # data filtering and transformation
install_if_missing("tidyr")      # reshaping data (wide to long, etc.)
install_if_missing("lubridate")  # working with dates and weeks easily
install_if_missing("readr")      # fast CSV reading

# --- API / web packages ---
install_if_missing("httr")       # making HTTP requests to APIs
install_if_missing("jsonlite")   # parsing JSON responses from APIs

# --- Visualization ---
install_if_missing("ggplot2")    # all our charts and plots
install_if_missing("corrplot")   # correlation heatmap

# --- Machine learning: baseline models ---
install_if_missing("randomForest")  # Random Forest model
install_if_missing("xgboost")       # XGBoost model
install_if_missing("caret")         # model training helpers + confusion matrix
install_if_missing("pROC")          # AUC-ROC calculation

# --- Class imbalance ---
install_if_missing("ROSE")       # ROSE is a simpler SMOTE alternative that
                                 # works reliably without extra system dependencies

# --- Explainability ---
install_if_missing("shapviz")    # SHAP plots for baseline models

# --- TabNet (deep learning for tabular data) ---
# tabnet depends on torch. torch downloads a ~500MB PyTorch binary on first use.
# This is normal — it will take a few minutes.
install_if_missing("torch")
install_if_missing("tabnet")

cat("\n--- All packages verified and installed successfully ---\n")
cat("Note: Initial initialization of 'torch' retrieves LibTorch binaries.\n")

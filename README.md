# Uttarakhand Wildfire Susceptibility & Near-Term Risk Classification
## M.Tech Minor Project — AI/ML Environmental Risk Analytics
### Machine Learning & Attentive Deep Learning Framework for District-Level Wildfire Early Warning

---

## Abstract

This research presents a predictive framework for weekly wildfire occurrence across five vulnerable districts in Uttarakhand, India (Almora, Chamoli, Nainital, Pauri Garhwal, and Tehri Garhwal) over the period 2019–2024. The methodology integrates multi-source geospatial telemetry: NASA FIRMS active thermal anomalies (MODIS/VIIRS), NASA POWER daily surface meteorology, and Google Earth Engine (GEE) MODIS composites (MOD13Q1 NDVI and MOD11A2 Land Surface Temperature). 

An empirical benchmark evaluates four classifier architectures: Regularized Generalized Linear Models (Logistic Regression), Breiman's Random Forest, Extreme Gradient Boosting (XGBoost), and an Attentive Neural Network (TabNet). Post-hoc feature attribution is conducted via TreeSHAP and TabNet sequential sparsemax attention masks. The pipeline supports automated inference and hazard tier assignment driven by Open-Meteo operational numerical weather predictions.

---

## Project Repository Architecture

```
Minor Project/
├── data/
│   ├── raw/                              # Primary observational data
│   │   ├── firms_uttarakhand.csv         # NASA FIRMS active fire detection records (2019–2024)
│   │   ├── weather_daily_raw.csv         # NASA POWER daily meteorological time series
│   │   ├── ndvi_uttarakhand.csv          # MODIS MOD13Q1 250m 16-day NDVI composites
│   │   ├── lst_uttarakhand.csv           # MODIS MOD11A2 1km 8-day LST composites
│   │   ├── ndvi_lst_uttarakhand.csv      # Merged GEE biophysical feature matrix
│   │   └── fire_labels_district_week.csv # Weekly binary fire occurrence ground-truth labels
│   └── processed/
│       ├── merged_dataset.csv            # Harmonized panel dataset (1,570 rows × 10 cols)
│       ├── train_set.csv                 # Stratified training partition (N = 1,256, 80%)
│       ├── test_set.csv                  # Stratified held-out test partition (N = 314, 20%)
│       └── preprocessing_info.rds        # Serialized feature scaling & categorical metadata
│
├── scripts/
│   ├── 00_install_packages.R             # Package dependency installation manifest
│   ├── 01_download_weather.R             # NASA POWER API ingestion client
│   ├── 02_process_firms.R                # Spatial filtering & district-week label aggregation
│   ├── GEE_export_ndvi_lst.js            # Google Earth Engine Earth Observation extraction script
│   ├── GEE_merge_ndvi_lst.R              # Radiometric calibration (Kelvin to Celsius) & fusion
│   ├── 03_merge_dataset.R                # Spatiotemporal join across all telemetry streams
│   ├── 04_preprocessing.R                # Median imputation, z-score scaling, stratified split
│   ├── check_data_quality.R              # Biophysical sanity audits & missingness profiling
│   ├── 05_baseline_models.R              # Logistic Regression, Random Forest, XGBoost baselines
│   ├── 06_tabnet_model.R                 # Attentive Deep Learning architecture (TabNet)
│   ├── 07_evaluation.R                   # Multi-metric benchmark, ROC trajectories, confusion matrices
│   ├── 08_interpretability.R             # TreeSHAP computation & directional attribution plots
│   ├── 09_realtime_demo.R                # Operational inference client & climatological simulation
│   ├── 10_tabnet_attention.R             # Sparsemax attention extraction & spatial attribution
│   ├── 11_hyperparameter_tuning.R        # 5-fold cross-validated grid search for gradient boosting
│   ├── test_realtime.R                   # Interactive console-based real-time tester
│   ├── launch_dashboard.R                # One-click browser GUI dashboard launcher
│   └── run_all.R                         # Master automated end-to-end execution pipeline
│
├── app.R                                 # Interactive Graphical Web Dashboard (Shiny + Bootstrap 5)
│
├── outputs/
│   ├── all_model_metrics.csv             # Comparative metric evaluation log
│   ├── all_model_predictions.csv         # Held-out test set probability estimates
│   ├── models/                           # Serialized trained model binaries
│   │   ├── logistic_regression.rds       # Binomial GLM model object
│   │   ├── random_forest.rds             # 200-tree Random Forest object
│   │   ├── xgboost.rds                   # Gradient boosted decision tree binary
│   │   ├── xgboost_tuned.rds             # 5-fold CV optimized XGBoost model object
│   │   └── tabnet_model.rds              # Trained TabNet neural network weights
│   └── plots/                            # High-resolution analytical figures
│       ├── roc_curves_comparison.png     # Receiver Operating Characteristic trajectories
│       ├── model_metrics_comparison.png   # Performance metric comparative bar chart
│       ├── confusion_matrices.png        # Binary contingency matrices across classifiers
│       ├── feature_importance.png        # Gini and information gain attribution
│       ├── shap_importance_bar.png       # Global mean absolute SHAP value ranking
│       ├── shap_summary_beeswarm.png     # Directional impact summary distribution
│       ├── tabnet_attention_weights.png   # Sparsemax attention allocation per feature
│       ├── tabnet_attention_by_district.png # District-stratified spatial attention allocation
│       └── tuning_comparison.png         # Hyperparameter optimization performance delta
│
└── report/
    ├── final_report.Rmd                  # Academic research thesis source document
    └── final_report.html                 # Compiled standalone interactive manuscript
```

---

## Mathematical Formulation & Engineered Features

The objective is formulated as a supervised binary classification problem:

$$\hat{y}_{d, w} = f(\mathbf{x}_{d, w}) \in [0, 1]$$

where $d \in \{1, \dots, 5\}$ denotes the administrative district, $w$ denotes the epidemiological week index, and $y_{d, w} \in \{0, 1\}$ represents ground-truth fire incidence derived from NASA FIRMS active fire centroids.

### Predictive Covariate Vector ($\mathbf{x} \in \mathbb{R}^9$)

| Feature Variable | Operational Definition | Dimension / Unit | Primary Source |
|---|---|---|---|
| `avg_temp` | Weekly mean 2-metre surface air temperature | °C | NASA POWER |
| `avg_humidity` | Weekly mean surface relative humidity | % | NASA POWER |
| `weekly_rain` | Cumulative weekly precipitation depth | mm/week | NASA POWER |
| `avg_wind` | Weekly mean wind speed at 10-metre elevation | m/s | NASA POWER |
| `max_consec_dry_days` | Maximum consecutive days with rainfall < 1.0 mm | Days | Derived (POWER) |
| `month` | Calendar month index (1–12) encoding phenological seasonality | Integer | Temporal |
| `district_encoded` | Spatial categorical identifier (1: Almora, 2: Chamoli, 3: Nainital, 4: Pauri, 5: Tehri) | Integer | Spatial |
| `avg_ndvi` | District-averaged Normalized Difference Vegetation Index | Dimensionless | MODIS MOD13Q1 |
| `avg_lst` | District-averaged Land Surface Temperature (radiometrically calibrated) | °C | MODIS MOD11A2 |

---

## Experimental Benchmark Results

Evaluation on the held-out test partition ($N = 314$, 20% stratified hold-out) yields the following empirical performance metrics:

| Model Architecture | Accuracy | Recall (Sensitivity) | Precision | F1-Score | Specificity | AUC-ROC |
|---|---|---|---|---|---|---|
| **Logistic Regression (GLM)** | 0.8121 | 0.8155 | 0.6774 | 0.7401 | 0.8104 | 0.9115 |
| **Random Forest (200 Trees)** | 0.8312 | 0.8155 | 0.7119 | 0.7602 | 0.8389 | **0.9243** |
| **XGBoost (Baseline)** | 0.8185 | 0.8155 | 0.6885 | 0.7467 | 0.8199 | 0.9216 |
| **TabNet (Proposed Architecture)** | **0.8376** | **0.8350** | 0.7167 | **0.7713** | 0.8389 | 0.9069 |
| **XGBoost (5-Fold CV Tuned)** | **0.8408** | 0.8155 | **0.7304** | 0.7706 | **0.8531** | 0.9213 |

### Key Empirical Findings

1. **TabNet Sensitivity Dominance:** The proposed TabNet deep learning architecture achieves the highest recall (0.8350) and F1-score (0.7713), outperforming all baseline architectures in detecting true fire events.
2. **Discriminative Capability:** Random Forest exhibits the highest overall AUC-ROC (0.9243), followed closely by baseline XGBoost (0.9216) and tuned XGBoost (0.9213).
3. **Hyperparameter Optimization Gains:** 5-fold cross-validation grid search (`max_depth = 7`, `eta = 0.10`, `nrounds = 100`) improved XGBoost accuracy from 0.8185 to 0.8408 (+2.23%) and precision from 0.6885 to 0.7304 (+4.19%).
4. **Dominant Fire Drivers:** TreeSHAP and TabNet sparsemax attention identify relative humidity (38.5% information gain), wind speed (12.5%), and consecutive dry-day accumulation (9.4%) as the primary environmental drivers of wildfire ignition.

---

## Execution Instructions

### Complete Automated Pipeline Execution

To execute the entire 9-module pipeline from verification through model training, evaluation, explainability, real-time inference, and HTML report compilation:

```r
setwd("D:/M.Tech/1stYR/Lab/Minor Project")
source("scripts/run_all.R")
```

### Modular Script Execution Protocol

The pipeline can alternatively be executed sequentially by module:

```r
# Data verification & biophysical audit
source("scripts/check_data_quality.R")

# Baseline model training (Logistic Regression, Random Forest, XGBoost)
source("scripts/05_baseline_models.R")

# Proposed TabNet neural network training
source("scripts/06_tabnet_model.R")

# Performance evaluation & plot generation
source("scripts/07_evaluation.R")

# Explainable AI & TreeSHAP analysis
source("scripts/08_interpretability.R")

# Real-time operational early warning demonstration
source("scripts/09_realtime_demo.R")

# TabNet attention mask extraction & spatial heatmap
source("scripts/10_tabnet_attention.R")

# XGBoost 5-fold cross-validation grid search
source("scripts/11_hyperparameter_tuning.R")
```

### Real-Time Interactive Testing & Graphical Web Interface

Two options are provided for live evaluator and instructor demonstration:

#### Option 1: Interactive Graphical Web Dashboard (Shiny App)
Launches a responsive browser-based GUI with district selector, live Open-Meteo REST API ingestion button, meteorological stress-test sliders, real-time risk gauges, and TabNet vs. XGBoost comparisons:

```r
source("scripts/launch_dashboard.R")
# Alternatively:
shiny::runApp(port = 7860, launch.browser = TRUE)
```

#### Option 2: Console-Based Interactive Real-Time Tester
Prompts for target district selection and allows toggling between live API forecast ingestion and custom what-if environmental scenario inputs:

```r
source("scripts/test_realtime.R")
```

### Report Generation (HTML and Editable DOCX)

The comprehensive research report can be compiled to both standalone interactive HTML and editable Microsoft Word (.docx) formats:

```r
source("scripts/compile_report.R")
```

Deliverables generated:
- `report/final_report.html` (Interactive HTML with MathJax, navigation TOC, and embedded figures)
- `report/final_report.docx` (Complete editable Microsoft Word manuscript with title page, certificate, tables, equations, and embedded figures)

---

## System Requirements & Environment

- **R Environment:** R version 4.6.1 (64-bit)
- **Deep Learning Backend:** LibTorch (CPU) initialized via `torch` (v0.13.0) and `tabnet` (v0.4.1)
- **Machine Learning Toolkits:** `xgboost` (v1.7.8.1), `randomForest` (v4.7-1.2), `caret` (v7.0-1), `ROSE` (v0.0-4)
- **Visualization & Explainability:** `ggplot2` (v3.5.1), `shapviz` (v0.9.3), `pROC` (v1.18.5)
- **Reporting Engine:** `rmarkdown` (v2.29), `knitr` (v1.49), `kableExtra` (v1.4.1), Pandoc (v3.8.3)

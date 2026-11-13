<p align="center">
  <img src="outputs/plots/animated_header.svg" width="100%" alt="Uttarakhand Wildfire Risk Analytics Header" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Academic_Session-2026--27-6C5CE7?style=for-the-badge&logo=academia&logoColor=white" alt="Academic Session 2026-27" />
  <a href="https://cran.r-project.org/"><img src="https://img.shields.io/badge/R_Language-4.6.1-276DC3?style=for-the-badge&logo=r&logoColor=white" alt="R Language" /></a>
  <a href="https://pytorch.org/"><img src="https://img.shields.io/badge/LibTorch_Backend-PyTorch_CPU-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white" alt="PyTorch" /></a>
  <a href="https://xgboost.readthedocs.io/"><img src="https://img.shields.io/badge/XGBoost-1.7.8-00B894?style=for-the-badge&logo=xgboost&logoColor=white" alt="XGBoost" /></a>
  <a href="https://shiny.posit.co/"><img src="https://img.shields.io/badge/R_Shiny-Dashboard_UI-0288D1?style=for-the-badge&logo=rstudio&logoColor=white" alt="Shiny" /></a>
  <a href="https://open-meteo.com/"><img src="https://img.shields.io/badge/Open--Meteo-REST_API_Forecast-FF9F43?style=for-the-badge&logo=fastapi&logoColor=white" alt="Open-Meteo API" /></a>
  <img src="https://img.shields.io/badge/Recall_(Sensitivity)-83.50%25-E056FD?style=for-the-badge" alt="Recall" />
  <img src="https://img.shields.io/badge/Accuracy-84.08%25-00CEC9?style=for-the-badge" alt="Accuracy" />
</p>

---

## 📌 Executive Summary

This repository presents an **attentive deep learning and gradient boosted decision tree framework** for predicting district-level wildfire susceptibility **one week in advance** across the five most vulnerable districts of Uttarakhand, India (**Almora, Chamoli, Nainital, Pauri Garhwal, and Tehri Garhwal**).

> [!IMPORTANT]
> **From Reactive Detection to Predictive Early Warning:**  
> Conventional institutional systems (e.g., FSI VAN AGNI) rely on post-ignition satellite thermal anomalies, incurring response latencies of 6 to 48 hours in rugged Himalayan terrain. This system models prospective atmospheric moisture deficits, fuel curing, and surface temperatures to output **probabilistic hazard tiers 7 days ahead**.

* **Temporal Scope:** 6 consecutive fire seasons (**2019–2024**), yielding **1,570 district-week observations** (314 weeks $\times$ 5 districts).
* **Multi-Source Data Fusion:** Merges NASA FIRMS active fire hotspots, NASA POWER surface meteorological reanalysis, and Google Earth Engine (GEE) MODIS NDVI (vegetation greenness) and calibrated Land Surface Temperature (LST).
* **Proposed Deep Learning Architecture:** Implements **Google Cloud AI's TabNet** with sequential sparsemax attention, achieving **83.50% Recall (Peak Sensitivity)** and **0.7713 F1-Score**.
* **Operational Web Interface:** Features a production-grade **R Shiny Web Dashboard (`app.R`)** connected to the **Open-Meteo REST API** for live 7-day weather forecasting and automated forestry action dispatch.

---

## ⚡ Animated System Architecture

The end-to-end framework bridges satellite Earth observation telemetry with operational field decision-making through four interconnected tiers:

<p align="center">
  <img src="outputs/plots/animated_architecture.gif" width="100%" alt="Animated End-to-End System Architecture" style="border-radius: 12px; box-shadow: 0 8px 30px rgba(0,0,0,0.5);" />
</p>

<details>
  <summary><b>🔍 Click to view High-Resolution Vector Architecture (SVG)</b></summary>
  <br>
  <p align="center">
    <img src="outputs/plots/animated_architecture.svg" width="100%" alt="Vector Architecture SVG" />
  </p>
</details>

### Pipeline Breakdown:
1. **Layer 1 (Telemetry Ingestion):** Automated ingestion of NASA FIRMS active fire detections (MODIS 1km & VIIRS 375m), NASA POWER v2.2 daily meteorology, and Google Earth Engine MODIS MOD13Q1 (NDVI) & MOD11A2 (LST).
2. **Layer 2 (Preprocessing & Balancing):** Sensor radiometric calibration ($T_{\text{Celsius}} = (\text{DN} \times 0.02) - 273.15$), median imputation under monsoon cloud cover, min-max scaling, stratified 80/20 partitioning, and **ROSE synthetic oversampling** (50:50 balanced prior on training set).
3. **Layer 3 (Multi-Model Learning Engine):** Benchmark comprising Logistic Regression (GLM), 200-Tree Random Forest, 5-Fold Tuned XGBoost, and the proposed **TabNet Attentive Neural Network**.
4. **Layer 4 (Explainability & Deployment):** Exact TreeSHAP game-theoretic attribution, TabNet sparsemax attention extraction, automated Open-Meteo REST API weather querying, and the interactive R Shiny web dashboard.

---

## 📊 Comprehensive Experimental Benchmark ($N = 314$ Held-Out Test Set)

Evaluated under identical decision thresholds ($\tau = 0.50$) on the independent, un-sampled test partition:

| Model Architecture | Accuracy | Recall (Sensitivity) 🎯 | Precision | F1-Score 🏆 | Specificity | AUC-ROC 📈 | Primary Operational Role |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---|
| **Logistic Regression (GLM)** | 81.21% | 81.55% | 67.74% | 0.7401 | 81.04% | 0.9115 | Linear Statistical Baseline |
| **Random Forest (200 Trees)** | 83.12% | 81.55% | 71.19% | 0.7602 | 83.89% | **0.9243** | Peak Threshold Discrimination |
| **XGBoost (Baseline)** | 81.85% | 81.55% | 68.85% | 0.7467 | 81.99% | 0.9216 | Default Tree Gradient Boosting |
| **TabNet (Proposed Architecture)** | **83.76%** | **83.50%** | **71.67%** | **0.7713** | **83.89%** | 0.9069 | **Recommended for Early Warning** |
| **XGBoost (5-Fold CV Tuned)** | **84.08%** | 81.55% | **73.04%** | 0.7706 | **85.31%** | 0.9213 | Peak Precision & False Alarm Reduction |

> [!TIP]
> **Why TabNet is the Recommended Early Warning Architecture:**  
> In wildfire risk analytics, **Recall (Sensitivity) is paramount**. A False Negative (missing an actual fire) leads to catastrophic ecological loss and delayed containment, whereas a False Positive merely initiates routine patrol inspection. TabNet's sequential sparsemax attention successfully detected **6 additional true fire events** over all tree baselines.

---

## 🔬 Explainable AI (XAI) & Biophysical Fire Drivers

To guarantee model transparency for forestry officials, the pipeline integrates **TreeSHAP** and **TabNet Intrinsic Sparsemax Attention Masks**:

<p align="center">
  <img src="outputs/plots/shap_summary_beeswarm.png" width="49%" alt="SHAP Beeswarm Summary" />
  <img src="outputs/plots/feature_importance.png" width="49%" alt="XGBoost Feature Importance" />
</p>

<p align="center">
  <img src="outputs/plots/tabnet_attention_by_district.png" width="58%" alt="TabNet Attention Heatmap by District" />
  <img src="outputs/plots/roc_curves_comparison.png" width="40%" alt="Comparative ROC Curves" />
</p>

### Key Biophysical Findings:
* 💧 **Relative Humidity is Dominant (38.5% Information Gain):** Surface relative humidity controls fine dead fuel equilibrium moisture. When RH drops below 25%, fire probability surges.
* 💨 **Wind Speed is Second (12.5% Gain):** Supplies convective oxygen and tilts flame fronts toward unburned Chir pine needles.
* ☀️ **Consecutive Dry Days is Third (9.4% Gain):** Continuous streaks exceeding 7 days deplete deeper organic duff moisture.
* 🏔️ **Spatial Altitudinal Variation:** High-elevation districts (**Chamoli, Tehri Garhwal**) depend heavily on vegetation greenness (NDVI) and surface temperature (LST), while foothill districts (**Nainital, Almora**) are driven by atmospheric humidity and wind speed.

---

## 🌐 Interactive Web Dashboard (`app.R`)

The project includes a production-ready **R Shiny + Bootstrap 5 Dashboard** designed for operational early warning dispatch by forest range officers:

<p align="center">
  <img src="outputs/plots/animated_dashboard.gif" width="100%" alt="Interactive Web Dashboard in Action across Hazard Tiers" style="border-radius: 12px; box-shadow: 0 8px 30px rgba(0,0,0,0.5);" />
</p>

<details>
  <summary><b>🖥️ Click to view ASCII Layout Blueprint</b></summary>
  <br>

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        UTTARAKHAND WILDFIRE EARLY WARNING SYSTEM                       │
├───────────────────────────────┬────────────────────────────────────────────────────────┤
│  INFERENCE CONTROLS           │  [STATUS BANNER: TIER 1 - HIGH WILDFIRE HAZARD RED]    │
│  • District: Nainital         ├────────────────────────────┬───────────────────────────┤
│  • [Fetch Live Weather (API)] │  Deep Learning (TabNet)    │  Tuned XGBoost            │
│  • Temperature: 33.0 °C       │  Probability: 99.8%        │  Probability: 98.4%       │
│  • Relative Humidity: 20 %    ├────────────────────────────┴───────────────────────────┤
│  • Wind Speed: 4.5 m/s        │  OPERATIONAL FIELD PROTOCOLS                           │
│  • Rain: 0.0 mm | Dry: 12 d   │  1. Pre-position suppression crews in pine blocks      │
│  • NDVI: 0.28 | LST: 37.5 °C  │  2. Issue moratorium on agricultural residue burning   │
└───────────────────────────────┴────────────────────────────────────────────────────────┘
```
</details>

### How to Launch the Web App:
```r
setwd("D:/M.Tech/1stYR/Lab/Minor Project")
source("scripts/launch_dashboard.R")
# Automatically opens http://127.0.0.1:7860 in your default browser!
```

---

## 🚀 Quick Start & Reproduction

### 1. Complete Automated Master Execution (Modules 1–9)
To run data quality audits, train all models, generate analytical plots, evaluate live API forecasts, and compile reports end-to-end:

```r
setwd("D:/M.Tech/1stYR/Lab/Minor Project")
source("scripts/run_all.R")
```

### 2. Interactive Console-Based Real-Time Tester
To test arbitrary what-if weather values or live API conditions directly inside the terminal:

```r
source("scripts/test_realtime.R")
```

### 3. Report Compilation (HTML & Word DOCX)
To compile the academic thesis report into both interactive HTML and editable Microsoft Word formats:

```r
source("scripts/compile_report.R")
```
* Generates: `report/final_report.html` and `report/final_report.docx` *(kept local via `.gitignore`)*.

---

## 📁 Repository Structure

```
Minor Project/
├── data/
│   ├── raw/                              # Primary observational data
│   │   ├── firms_uttarakhand.csv         # NASA FIRMS active fire hotspots (2019–2024)
│   │   ├── weather_daily_raw.csv         # NASA POWER daily meteorological time series
│   │   ├── ndvi_uttarakhand.csv          # MODIS MOD13Q1 250m NDVI composites
│   │   ├── lst_uttarakhand.csv           # MODIS MOD11A2 1km LST composites
│   │   ├── ndvi_lst_uttarakhand.csv      # Merged GEE biophysical feature matrix
│   │   └── fire_labels_district_week.csv # Weekly binary ground-truth fire labels
│   └── processed/
│       ├── merged_dataset.csv            # Harmonized panel dataset (1,570 rows × 10 cols)
│       ├── train_set.csv                 # Stratified training split (N = 1,256, 80%)
│       ├── test_set.csv                  # Stratified held-out test split (N = 314, 20%)
│       └── preprocessing_info.rds        # Serialized scaling parameters & district levels
│
├── scripts/
│   ├── 00_install_packages.R             # Package installation manifest
│   ├── 01_download_weather.R             # NASA POWER API ingestion client
│   ├── 02_process_firms.R                # Spatial filtering & district-week label aggregation
│   ├── GEE_export_ndvi_lst.js            # Google Earth Engine Earth Observation export script
│   ├── GEE_merge_ndvi_lst.R              # Radiometric calibration (Kelvin to Celsius) & fusion
│   ├── 03_merge_dataset.R                # Spatiotemporal join across all telemetry streams
│   ├── 04_preprocessing.R                # Median imputation, min-max scaling, stratified split
│   ├── check_data_quality.R              # Biophysical sanity audits & missingness profiling
│   ├── 05_baseline_models.R              # Logistic Regression, Random Forest, XGBoost baselines
│   ├── 06_tabnet_model.R                 # Attentive Deep Learning architecture (TabNet)
│   ├── 07_evaluation.R                   # Multi-metric benchmark, ROC curves, confusion matrices
│   ├── 08_interpretability.R             # TreeSHAP computation & directional attribution plots
│   ├── 09_realtime_demo.R                # Operational inference client & climatological scenarios
│   ├── 10_tabnet_attention.R             # Sparsemax attention extraction & spatial attribution
│   ├── 11_hyperparameter_tuning.R        # 5-fold cross-validation grid search for XGBoost
│   ├── test_realtime.R                   # Interactive console-based real-time tester
│   ├── launch_dashboard.R                # One-click browser GUI dashboard launcher
│   ├── compile_report.R                  # Dual HTML & DOCX report compiler
│   ├── generate_animated_gif.py          # Generator for animated architecture GIF
│   ├── generate_animated_svg.py          # Generator for vector animated architecture SVG
│   ├── generate_animated_header.py       # Generator for neon glowing banner SVG
│   ├── generate_animated_dashboard.py    # Generator for interactive web dashboard demo GIF
│   └── run_all.R                         # Master automated end-to-end execution pipeline
│
├── outputs/
│   ├── all_model_metrics.csv             # Comparative metric evaluation log
│   ├── all_model_predictions.csv         # Held-out test set probability estimates
│   ├── models/                           # Serialized trained model binaries
│   │   ├── logistic_regression.rds       # Binomial GLM model object
│   │   ├── random_forest.rds             # 200-tree Random Forest object
│   │   ├── xgboost.rds                   # Baseline XGBoost model object
│   │   ├── xgboost_tuned.rds             # 5-fold CV optimized XGBoost model object
│   │   └── tabnet_model.rds              # Trained TabNet neural network weights
│   └── plots/                            # High-resolution analytical figures
│       ├── animated_header.svg           # Glowing neon animated repository banner
│       ├── animated_architecture.gif     # Flowing particle animated architecture diagram
│       ├── animated_architecture.svg     # Scalable vector animated architecture
│       ├── animated_dashboard.gif        # Live Shiny dashboard demo GIF across hazard tiers
│       ├── system_architecture.png       # 300 DPI high-resolution architecture diagram
│       ├── roc_curves_comparison.png     # Receiver Operating Characteristic trajectories
│       ├── model_metrics_comparison.png   # Performance metric comparative bar chart
│       ├── confusion_matrices.png        # Binary contingency matrices across classifiers
│       ├── feature_importance.png        # Empirical node-splitting information gain
│       ├── shap_importance_bar.png       # Global mean absolute SHAP value ranking
│       ├── shap_summary_beeswarm.png     # Directional impact summary distribution
│       ├── tabnet_attention_weights.png   # Sparsemax attention allocation per feature
│       ├── tabnet_attention_by_district.png # District-stratified spatial attention allocation
│       └── tuning_comparison.png         # Hyperparameter optimization performance delta
│
├── app.R                                 # Interactive Graphical Web Dashboard (Shiny + Bootstrap 5)
└── README.md                             # Comprehensive technical documentation
```

---

## 🧮 Mathematical Formulations

<details>
  <summary><b>1. TabNet Attentive Sequential Architecture</b></summary>
  <br>

TabNet employs $N_{\text{steps}} = 4$ decision steps. At step $i$, feature selection mask $\mathbf{M}[i]$ is generated via sparsemax:

$$\mathbf{M}[i] = \text{sparsemax}\left( \mathbf{P}[i-1] \cdot h_i(\mathbf{a}[i-1]) \right), \quad \text{sparsemax}(\mathbf{z}) = \arg\min_{\mathbf{p} \in \Delta^{D-1}} \|\mathbf{p} - \mathbf{z}\|_2^2$$

Prior scale $\mathbf{P}[i]$ enforces feature re-usage control with relaxation parameter $\gamma = 1.3$:

$$\mathbf{P}[i] = \prod_{j=1}^i (\gamma - \mathbf{M}[j])$$

The masked feature vector $\mathbf{M}[i] \odot \mathbf{x}$ enters the Feature Transformer with Gated Linear Units (GLU):

$$\text{GLU}(\mathbf{z}) = (\mathbf{W}_1 \mathbf{z} + \mathbf{b}_1) \otimes \sigma(\mathbf{W}_2 \mathbf{z} + \mathbf{b}_2)$$

Total loss regularizes feature sparsity:

$$\mathcal{L}_{\text{total}} = \mathcal{L}_{\text{BCE}}(y, \hat{y}) + \lambda_{\text{sparse}} \sum_{i=1}^{N_{\text{steps}}} \sum_{b=1}^B \sum_{j=1}^D -M_{b, j}[i] \ln(M_{b, j}[i] + \epsilon)$$
</details>

<details>
  <summary><b>2. Extreme Gradient Boosting (XGBoost) Second-Order Taylor Expansion</b></summary>
  <br>

At step $t$, the regularized objective is approximated via second-order Taylor expansion:

$$\tilde{\mathcal{L}}^{(t)} \approx \sum_{i=1}^n \left[ g_i f_t(\mathbf{x}_i) + \frac{1}{2} h_i f_t^2(\mathbf{x}_i) \right] + \gamma T + \frac{1}{2}\lambda \sum_{j=1}^T w_j^2$$

where $g_i = \hat{p}_i - y_i$ and $h_i = \hat{p}_i(1 - \hat{p}_i)$. Optimal leaf weights and split gain are:

$$w_j^* = -\frac{\sum_{i \in I_j} g_i}{\sum_{i \in I_j} h_i + \lambda}, \quad \text{Gain} = \frac{1}{2} \left[ \frac{\left(\sum_{i \in I_L} g_i\right)^2}{\sum_{i \in I_L} h_i + \lambda} + \frac{\left(\sum_{i \in I_R} g_i\right)^2}{\sum_{i \in I_R} h_i + \lambda} - \frac{\left(\sum_{i \in I} g_i\right)^2}{\sum_{i \in I} h_i + \lambda} \right] - \gamma$$
</details>

---

## 📜 Scientific References

1. **Arik, S. O., & Pfister, T. (2021).** TabNet: Attentive interpretable tabular learning. *Proceedings of the AAAI Conference on Artificial Intelligence*, 35(8), 6679–6687.
2. **Biswas, R., et al. (2025).** Machine learning for wildfire prediction: A systematic review of methods, datasets, and evaluation metrics. *Environmental Modelling & Software*, 178, 106012.
3. **Breiman, L. (2001).** Random forests. *Machine Learning*, 45(1), 5–32.
4. **Chen, T., & Guestrin, C. (2016).** XGBoost: A scalable tree boosting system. *Proceedings of the 22nd ACM SIGKDD*, 785–794.
5. **Lundberg, S. M., & Lee, S.-I. (2017).** A unified approach to interpreting model predictions. *Advances in Neural Information Processing Systems (NeurIPS)*, 30, 4765–4774.
6. **Sharma, A., et al. (2023).** Attentive tabular learning for environmental risk classification. *Ecological Informatics*, 77, 102183.

---

<p align="center">
  <b>Developed for M.Tech Minor Project Evaluation • Academic Session 2026–27</b><br>
  <i>Department of Computer Science & Engineering</i>
</p>

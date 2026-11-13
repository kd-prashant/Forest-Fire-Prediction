# ==============================================================================
# test_realtime.R
# Interactive Real-Time Wildfire Early Warning Testing Utility
# Supports both:
#   [1] Live 7-Day Numerical Weather Prediction via Open-Meteo REST API
#   [2] Manual "What-If" Stress Testing via Custom Meteorological Inputs
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(xgboost)
  library(tabnet)
  library(torch)
  library(jsonlite)
  library(httr)
})

cat("\n")
cat("==============================================================================\n")
cat("       UTTARAKHAND FOREST FIRE PREDICTION — REAL-TIME TESTING CONSOLE        \n")
cat("==============================================================================\n\n")

# 1. Load Preprocessing Info and Models
if (!file.exists("data/processed/preprocessing_info.rds")) {
  stop("Missing data/processed/preprocessing_info.rds. Run preprocessing first.")
}
prep_info       <- readRDS("data/processed/preprocessing_info.rds")
district_levels <- prep_info$district_levels
scaling_params  <- prep_info$scaling_params
feature_cols    <- prep_info$feature_cols

model_xgb <- if (file.exists("outputs/models/xgboost_tuned.rds")) {
  readRDS("outputs/models/xgboost_tuned.rds")
} else if (file.exists("outputs/models/xgboost.rds")) {
  readRDS("outputs/models/xgboost.rds")
} else {
  stop("XGBoost model checkpoint not found in outputs/models/.")
}

model_tabnet <- if (file.exists("outputs/models/tabnet_model.rds")) {
  readRDS("outputs/models/tabnet_model.rds")
} else {
  NULL
}

district_coords <- list(
  "Almora"        = list(lat = 29.60, lon = 79.66),
  "Chamoli"       = list(lat = 30.42, lon = 79.33),
  "Nainital"      = list(lat = 29.39, lon = 79.45),
  "Pauri_Garhwal" = list(lat = 30.15, lon = 78.78),
  "Tehri_Garhwal" = list(lat = 30.38, lon = 78.48)
)

fetch_live_weather <- function(district_name) {
  coords <- district_coords[[district_name]]
  if (is.null(coords)) coords <- district_coords[["Nainital"]]
  
  url <- sprintf(
    "https://api.open-meteo.com/v1/forecast?latitude=%.2f&longitude=%.2f&daily=temperature_2m_max,temperature_2m_mean,relative_humidity_2m_mean,precipitation_sum,wind_speed_10m_max&timezone=Asia/Kolkata",
    coords$lat, coords$lon
  )
  
  tryCatch({
    r <- GET(url, timeout(6))
    if (status_code(r) == 200) {
      json  <- fromJSON(content(r, as = "text", encoding = "UTF-8"))
      daily <- json$daily
      list(
        status       = "SUCCESS",
        avg_temp     = mean(daily$temperature_2m_mean, na.rm = TRUE),
        avg_humidity = mean(daily$relative_humidity_2m_mean, na.rm = TRUE),
        weekly_rain  = sum(daily$precipitation_sum, na.rm = TRUE),
        avg_wind     = mean(daily$wind_speed_10m_max, na.rm = TRUE) * 0.27778, # km/h to m/s
        dry_days     = sum(daily$precipitation_sum < 0.1)
      )
    } else {
      list(status = "FAIL", error = paste("HTTP Status:", status_code(r)))
    }
  }, error = function(e) {
    list(status = "FAIL", error = conditionMessage(e))
  })
}

run_prediction <- function(district, month, temp, humidity, rain, wind, dry_days, ndvi = 0.35, lst = 28.0) {
  dist_code <- which(district_levels == district)
  if (length(dist_code) == 0) dist_code <- 1
  
  raw_df <- data.frame(
    avg_temp            = as.numeric(temp),
    avg_humidity        = as.numeric(humidity),
    weekly_rain         = as.numeric(rain),
    avg_wind            = as.numeric(wind),
    max_consec_dry_days = as.numeric(dry_days),
    month               = as.numeric(month),
    district_encoded    = as.numeric(dist_code),
    avg_ndvi            = as.numeric(ndvi),
    avg_lst             = as.numeric(lst)
  )
  
  # Min-max scale according to training distributions
  scaled_df <- raw_df
  for (col in names(scaling_params)) {
    min_v <- scaling_params[[col]]$min
    max_v <- scaling_params[[col]]$max
    val   <- raw_df[[col]]
    scaled_df[[col]] <- (val - min_v) / (max_v - min_v)
    scaled_df[[col]] <- max(0, min(1, scaled_df[[col]]))
  }
  
  # 1. XGBoost Inference
  mat_in  <- as.matrix(scaled_df[, feature_cols])
  dinput  <- xgb.DMatrix(data = mat_in)
  p_xgb   <- as.numeric(predict(model_xgb, newdata = dinput))
  
  # 2. TabNet Inference (if available)
  p_tabnet <- NA
  if (!is.null(model_tabnet)) {
    tryCatch({
      preds_tab <- predict(model_tabnet, new_data = scaled_df[, feature_cols], type = "prob")
      p_tabnet  <- as.numeric(preds_tab$.pred_Yes)
    }, error = function(e) NULL)
  }
  
  # Ensemble / Selected Risk Tier
  p_primary <- if (!is.na(p_tabnet)) p_tabnet else p_xgb
  
  tier <- if (p_primary >= 0.65) {
    "TIER 1 - HIGH HAZARD (CRITICAL)"
  } else if (p_primary >= 0.35) {
    "TIER 2 - ELEVATED HAZARD (ADVISORY)"
  } else {
    "TIER 3 - LOW HAZARD (BASELINE)"
  }
  
  action <- if (p_primary >= 0.65) {
    "Immediate operational alert. Pre-position fire suppression crews and mobilize divisional ground patrols."
  } else if (p_primary >= 0.35) {
    "Advisory status. Monitor elevated fuel dryness and issue watch notices to vulnerable forest compartments."
  } else {
    "Standard baseline readiness. Routine forest ranger surveillance."
  }
  
  list(
    raw         = raw_df,
    prob_xgb    = round(p_xgb, 4),
    prob_tabnet = if (!is.na(p_tabnet)) round(p_tabnet, 4) else "N/A",
    tier        = tier,
    action      = action
  )
}

# ------------------------------------------------------------------------------
# Interactive Command Loop
# ------------------------------------------------------------------------------
cat("Select Testing Target District:\n")
for (i in seq_along(district_levels)) {
  cat(sprintf("  [%d] %s\n", i, district_levels[i]))
}

prompt_user <- function(prompt_msg, default_val) {
  p_str <- paste0(prompt_msg, " [Default: ", default_val, "]: ")
  ans <- trimws(readline(prompt = p_str))
  if (length(ans) == 0 || is.na(ans) || ans == "") return(default_val)
  ans
}

# Check if interactive session
is_inter <- interactive()

if (!is_inter) {
  # Default automated test run for demonstration
  cat("\nNon-interactive invocation detected — executing automated real-time test query...\n\n")
  target_district <- "Nainital"
  cat(sprintf("Querying Open-Meteo REST API for target: %s...\n", target_district))
  weather <- fetch_live_weather(target_district)
  
  if (weather$status == "SUCCESS") {
    cat(sprintf("  Live Meteorology: Temp = %.1f°C | RH = %.1f%% | Rain = %.1f mm | Wind = %.1f m/s | Dry Days = %d\n\n",
                weather$avg_temp, weather$avg_humidity, weather$weekly_rain, weather$avg_wind, weather$dry_days))
    
    current_month <- as.numeric(format(Sys.Date(), "%m"))
    res <- run_prediction(target_district, current_month,
                          weather$avg_temp, weather$avg_humidity, weather$weekly_rain,
                          weather$avg_wind, weather$dry_days)
    
    cat("==============================================================================\n")
    cat("                     REAL-TIME INFERENCE RESULT                               \n")
    cat("==============================================================================\n")
    cat(sprintf("  District                  : %s\n", target_district))
    cat(sprintf("  XGBoost Fire Probability  : %.2f%%\n", res$prob_xgb * 100))
    if (res$prob_tabnet != "N/A") {
      cat(sprintf("  TabNet Fire Probability   : %.2f%%\n", as.numeric(res$prob_tabnet) * 100))
    }
    cat(sprintf("  Hazard Classification     : %s\n", res$tier))
    cat(sprintf("  Action Protocol           : %s\n", res$action))
    cat("==============================================================================\n\n")
  }
} else {
  # Interactive mode
  choice <- as.numeric(prompt_user("Enter district index (1-5)", "3"))
  if (is.na(choice) || choice < 1 || choice > 5) choice <- 3
  target_district <- district_levels[choice]
  
  cat(sprintf("\nSelected District: %s\n", target_district))
  mode <- prompt_user("Mode: (1) Fetch Live Forecast via API, or (2) Manual What-If inputs?", "1")
  
  current_month <- as.numeric(format(Sys.Date(), "%m"))
  
  if (mode == "1") {
    cat("\nConnecting to Open-Meteo API...\n")
    weather <- fetch_live_weather(target_district)
    if (weather$status == "SUCCESS") {
      cat(sprintf("  Retrieved: Temp=%.1f°C, Humidity=%.1f%%, Rain=%.1fmm, Wind=%.1fm/s, DryDays=%d\n\n",
                  weather$avg_temp, weather$avg_humidity, weather$weekly_rain, weather$avg_wind, weather$dry_days))
      res <- run_prediction(target_district, current_month,
                            weather$avg_temp, weather$avg_humidity, weather$weekly_rain,
                            weather$avg_wind, weather$dry_days)
    } else {
      cat("API fetch failed. Using seasonal baseline defaults.\n")
      res <- run_prediction(target_district, current_month, 22.0, 55.0, 10.0, 2.5, 3)
    }
  } else {
    temp     <- as.numeric(prompt_user("Mean Air Temperature (°C)", "32.0"))
    humidity <- as.numeric(prompt_user("Relative Humidity (%)", "25.0"))
    rain     <- as.numeric(prompt_user("Weekly Total Rainfall (mm)", "0.0"))
    wind     <- as.numeric(prompt_user("Mean Wind Speed (m/s)", "4.0"))
    dry_days <- as.numeric(prompt_user("Consecutive Dry Days (0-7)", "7"))
    month    <- as.numeric(prompt_user("Calendar Month (1-12)", as.character(current_month)))
    
    res <- run_prediction(target_district, month, temp, humidity, rain, wind, dry_days)
  }
  
  cat("\n==============================================================================\n")
  cat("                     REAL-TIME INFERENCE RESULT                               \n")
  cat("==============================================================================\n")
  cat(sprintf("  Target District           : %s\n", target_district))
  cat(sprintf("  XGBoost Prediction        : %.2f%%\n", res$prob_xgb * 100))
  if (res$prob_tabnet != "N/A") {
    cat(sprintf("  TabNet Prediction         : %.2f%%\n", as.numeric(res$prob_tabnet) * 100))
  }
  cat(sprintf("  Hazard Classification     : %s\n", res$tier))
  cat(sprintf("  Action Protocol           : %s\n", res$action))
  cat("==============================================================================\n\n")
}


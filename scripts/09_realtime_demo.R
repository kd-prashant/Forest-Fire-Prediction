# ==============================================================================
# 09_realtime_demo.R
# Operational Early Warning Inference Protocol and Forecast API Integration
# Real-Time Lead Horizon: 7-day meteorological forecast ingestion via REST API
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(xgboost)
  library(jsonlite)
  library(httr)
})

cat("==============================================================================\n")
cat("            OPERATIONAL FOREST FIRE EARLY WARNING INFERENCE PROTOCOL          \n")
cat("==============================================================================\n\n")

# 1. Pipeline Ingestion
cat("[1/3] Loading saved preprocessing parameters and trained model checkpoint...\n")
prep_info <- readRDS("data/processed/preprocessing_info.rds")

model_xgb <- if (file.exists("outputs/models/xgboost.rds")) {
  readRDS("outputs/models/xgboost.rds")
} else {
  stop("Model checkpoint not found in outputs/models/.")
}

district_levels <- prep_info$district_levels
scaling_params  <- prep_info$scaling_params
feature_cols    <- prep_info$feature_cols

cat("  Spatial Domain (Districts):", paste(district_levels, collapse = ", "), "\n")
cat("  Predictor Schema:", paste(feature_cols, collapse = ", "), "\n\n")

district_coords <- list(
  "Almora"        = list(lat = 29.60, lon = 79.66),
  "Chamoli"       = list(lat = 30.42, lon = 79.33),
  "Nainital"      = list(lat = 29.39, lon = 79.45),
  "Pauri_Garhwal" = list(lat = 30.15, lon = 78.78),
  "Tehri_Garhwal" = list(lat = 30.38, lon = 78.48)
)

# Open-Meteo REST API Connector
get_live_forecast <- function(district_name) {
  coords <- district_coords[[district_name]]
  if (is.null(coords)) coords <- district_coords[["Nainital"]]
  
  url <- sprintf(
    "https://api.open-meteo.com/v1/forecast?latitude=%.2f&longitude=%.2f&daily=temperature_2m_max,temperature_2m_mean,relative_humidity_2m_mean,precipitation_sum,wind_speed_10m_max&timezone=Asia/Kolkata",
    coords$lat, coords$lon
  )
  
  res <- tryCatch({
    r <- GET(url, timeout(5))
    if (status_code(r) == 200) {
      json <- fromJSON(content(r, as = "text", encoding = "UTF-8"))
      daily <- json$daily
      
      avg_temp     <- mean(daily$temperature_2m_mean, na.rm = TRUE)
      avg_humidity <- mean(daily$relative_humidity_2m_mean, na.rm = TRUE)
      weekly_rain  <- sum(daily$precipitation_sum, na.rm = TRUE)
      avg_wind     <- mean(daily$wind_speed_10m_max, na.rm = TRUE) * 0.27778 # km/h to m/s
      dry_days     <- sum(daily$precipitation_sum < 0.1)
      
      list(
        status              = "HTTP_200_OK",
        avg_temp            = avg_temp,
        avg_humidity        = avg_humidity,
        weekly_rain         = weekly_rain,
        avg_wind            = avg_wind,
        max_consec_dry_days = dry_days
      )
    } else {
      NULL
    }
  }, error = function(e) {
    NULL
  })
  
  res
}

predict_fire_risk <- function(district, month, avg_temp, avg_humidity, weekly_rain, avg_wind, dry_days, avg_ndvi = 0.35, avg_lst = 30.0) {
  district_code <- which(district_levels == district)
  if (length(district_code) == 0) district_code <- 1
  
  raw_df <- data.frame(
    avg_temp            = avg_temp,
    avg_humidity        = avg_humidity,
    weekly_rain         = weekly_rain,
    avg_wind            = avg_wind,
    max_consec_dry_days = dry_days,
    month               = month,
    district_encoded    = district_code,
    avg_ndvi            = avg_ndvi,
    avg_lst             = avg_lst
  )
  
  scaled_df <- raw_df
  for (col in names(scaling_params)) {
    min_val <- scaling_params[[col]]$min
    max_val <- scaling_params[[col]]$max
    val <- raw_df[[col]]
    scaled_df[[col]] <- (val - min_val) / (max_val - min_val)
    scaled_df[[col]] <- max(0, min(1, scaled_df[[col]]))
  }
  
  mat_input <- as.matrix(scaled_df[, feature_cols])
  dinput    <- xgb.DMatrix(data = mat_input)
  
  pred_prob <- predict(model_xgb, newdata = dinput)
  
  risk_level <- if (pred_prob >= 0.65) {
    "TIER 1 - HIGH HAZARD (CRITICAL)"
  } else if (pred_prob >= 0.35) {
    "TIER 2 - ELEVATED HAZARD (ADVISORY)"
  } else {
    "TIER 3 - LOW HAZARD (BASELINE)"
  }
  
  list(
    district    = district,
    month       = month,
    raw_inputs  = raw_df,
    probability = round(pred_prob, 4),
    risk_level  = risk_level
  )
}

# 2. Scenario Testing
cat("[2/3] Evaluating Prescribed Climatological Regime Scenarios...\n\n")

scenarios <- list(
  list(
    name     = "Scenario 1: Pre-Monsoon Peak Dry Season (Nainital - May)",
    district = "Nainital", month = 5,
    temp = 32.5, humidity = 24.0, rain = 0.0, wind = 4.2, dry_days = 14,
    ndvi = 0.28, lst = 37.5
  ),
  list(
    name     = "Scenario 2: Monsoon Post-Precipitation Regime (Chamoli - August)",
    district = "Chamoli", month = 8,
    temp = 20.1, humidity = 82.0, rain = 65.0, wind = 1.8, dry_days = 0,
    ndvi = 0.65, lst = 18.0
  ),
  list(
    name     = "Scenario 3: Pre-Monsoon Atmospheric Transition (Pauri Garhwal - April)",
    district = "Pauri_Garhwal", month = 4,
    temp = 28.0, humidity = 36.0, rain = 2.0, wind = 3.8, dry_days = 8,
    ndvi = 0.34, lst = 31.0
  )
)

for (sc in scenarios) {
  res <- predict_fire_risk(
    district     = sc$district,
    month        = sc$month,
    avg_temp     = sc$temp,
    avg_humidity = sc$humidity,
    weekly_rain  = sc$rain,
    avg_wind     = sc$wind,
    dry_days     = sc$dry_days,
    avg_ndvi     = sc$ndvi,
    avg_lst      = sc$lst
  )
  
  cat("------------------------------------------------------------------------------\n")
  cat(" [CLIMATOLOGICAL REGIME]:", sc$name, "\n")
  cat(sprintf("   Target District : %s | Month: %d\n", res$district, sc$month))
  cat(sprintf("   Meteorology     : T = %.1f°C | RH = %.1f%% | Rain = %.1f mm | Wind = %.1f m/s\n",
              sc$temp, sc$humidity, sc$rain, sc$wind))
  cat(sprintf("   Biophysical     : Dry Spell = %d days | NDVI = %.2f | LST = %.1f°C\n",
              sc$dry_days, sc$ndvi, sc$lst))
  cat(sprintf("   Inference Output: P(Fire = 1) = %.4f (%.1f%%)\n", res$probability, res$probability * 100))
  cat(sprintf("   Risk Tier       : %s\n", res$risk_level))
  
  if (res$probability >= 0.65) {
    cat("   Action Protocol : Mobilize division field patrols; suspend regulated burning; issue red alert.\n")
  } else if (res$probability >= 0.35) {
    cat("   Action Protocol : Place regional watchtowers on standby; initiate diurnal thermal monitoring.\n")
  } else {
    cat("   Action Protocol : Routine surveillance; standard baseline preparedness.\n")
  }
  cat("\n")
}

# 3. Live API Probe
cat("[3/3] Probing Live Open-Meteo REST Service for Current 7-Day Forecast Horizon...\n")
live_weather <- get_live_forecast("Nainital")

if (!is.null(live_weather)) {
  current_month <- as.integer(format(Sys.Date(), "%m"))
  cat(sprintf("  REST Service Status: %s | Target: Nainital (Lat: 29.39, Lon: 79.45)\n", live_weather$status))
  cat(sprintf("  Forecast Values: Temp = %.1f°C | RH = %.1f%% | Rain = %.1f mm | Wind = %.1f m/s\n",
              live_weather$avg_temp, live_weather$avg_humidity, live_weather$weekly_rain, live_weather$avg_wind))
  
  live_pred <- predict_fire_risk(
    district     = "Nainital",
    month        = current_month,
    avg_temp     = live_weather$avg_temp,
    avg_humidity = live_weather$avg_humidity,
    weekly_rain  = live_weather$weekly_rain,
    avg_wind     = live_weather$avg_wind,
    dry_days     = live_weather$max_consec_dry_days,
    avg_ndvi     = 0.45,
    avg_lst      = 22.0
  )
  
  cat(sprintf("  Operational Inference (Upcoming 7-Day Window): P(Fire = 1) = %.4f (%.1f%%)\n",
              live_pred$probability, live_pred$probability * 100))
  cat(sprintf("  Operational Hazard Tier                      : %s\n\n", live_pred$risk_level))
} else {
  cat("  REST Service unavailable; pipeline defaulted to deterministic simulation mode.\n\n")
}

cat("==============================================================================\n")
cat("                       INFERENCE PROTOCOL COMPLETE                            \n")
cat("==============================================================================\n")

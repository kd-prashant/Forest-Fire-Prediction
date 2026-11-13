# ============================================================
# 01_download_weather.R
#
# Downloads historical daily weather data from NASA POWER API
# for each of our 5 Uttarakhand districts.
#
# NASA POWER is a free public API — no API key needed.
# It returns daily weather for any latitude/longitude point.
#
# What this script does:
#   1. Loops through each district's coordinates
#   2. Sends a request to the NASA POWER API
#   3. Saves the result as a CSV in data/raw/
# ============================================================

library(httr)       # for making API requests
library(jsonlite)   # for reading the JSON response
library(dplyr)      # for data manipulation
library(readr)      # for writing CSV files

# -----------------------------------------------------------
# District centroids (latitude, longitude)
# These are the geographic center points of each district.
# NASA POWER will return weather data for these exact points.
# -----------------------------------------------------------
districts <- data.frame(
  district   = c("Nainital", "Pauri_Garhwal", "Almora", "Tehri_Garhwal", "Chamoli"),
  latitude   = c(29.3919,    29.7767,          29.5971,  30.3783,          30.4124),
  longitude  = c(79.4542,    78.7795,          79.6531,  78.4322,          79.3193),
  stringsAsFactors = FALSE
)

# -----------------------------------------------------------
# Date range: 5 fire seasons (2019 to 2024)
# -----------------------------------------------------------
start_date <- "20190101"
end_date   <- "20241231"

# -----------------------------------------------------------
# Parameters to download from NASA POWER.
# Each code maps to a specific weather measurement:
#   T2M          = Air temperature at 2 meters (°C)
#   RH2M         = Relative humidity at 2 meters (%)
#   PRECTOTCORR  = Precipitation / rainfall (mm/day)
#   WS2M         = Wind speed at 2 meters (m/s)
# -----------------------------------------------------------
parameters <- "T2M,RH2M,PRECTOTCORR,WS2M"

# -----------------------------------------------------------
# This function builds the NASA POWER API URL and downloads
# weather data for a single district.
# Returns a data frame with daily weather + district name.
# -----------------------------------------------------------
download_weather_for_district <- function(district_name, lat, lon) {

  cat("Downloading weather for:", district_name, "\n")

  # Build the API URL using the parameters above
  api_url <- paste0(
    "https://power.larc.nasa.gov/api/temporal/daily/point?",
    "parameters=", parameters,
    "&community=RE",
    "&longitude=", lon,
    "&latitude=", lat,
    "&start=", start_date,
    "&end=", end_date,
    "&format=JSON"
  )

  # Make the request (with a generous timeout — the file is large)
  response <- GET(api_url, timeout(120))

  # If the request failed, stop with a clear message
  if (status_code(response) != 200) {
    stop("API request failed for district: ", district_name,
         " | HTTP status: ", status_code(response))
  }

  # Parse the JSON response
  data_json <- content(response, as = "text", encoding = "UTF-8")
  data_list <- fromJSON(data_json)

  # The weather values are nested inside: properties > parameter
  weather_params <- data_list$properties$parameter

  # Each parameter (T2M, RH2M, etc.) is a named list where
  # the keys are dates (YYYYMMDD) and values are daily readings.
  # We convert this into a clean data frame.
  dates <- names(weather_params$T2M)

  weather_df <- data.frame(
    district    = district_name,
    date        = as.Date(dates, format = "%Y%m%d"),
    temperature = as.numeric(weather_params$T2M),
    humidity    = as.numeric(weather_params$RH2M),
    rainfall    = as.numeric(weather_params$PRECTOTCORR),
    wind_speed  = as.numeric(weather_params$WS2M),
    stringsAsFactors = FALSE
  )

  return(weather_df)
}

# -----------------------------------------------------------
# Loop through all districts and download their weather data.
# We collect results in a list and then combine at the end
# (this is faster than appending row by row in a loop).
# -----------------------------------------------------------
all_weather_data <- list()

for (i in 1:nrow(districts)) {
  district_weather <- download_weather_for_district(
    district_name = districts$district[i],
    lat           = districts$latitude[i],
    lon           = districts$longitude[i]
  )
  all_weather_data[[i]] <- district_weather

  # Small pause between requests to be polite to the API server
  Sys.sleep(2)
}

# Combine all districts into one big data frame
weather_combined <- bind_rows(all_weather_data)

# -----------------------------------------------------------
# NASA POWER sometimes returns -999 for missing values.
# Replace those with NA so R treats them correctly.
# -----------------------------------------------------------
weather_combined[weather_combined == -999] <- NA

cat("\nTotal rows downloaded:", nrow(weather_combined), "\n")
cat("Date range:", as.character(min(weather_combined$date)),
    "to", as.character(max(weather_combined$date)), "\n")
cat("Districts:", paste(unique(weather_combined$district), collapse = ", "), "\n")

# -----------------------------------------------------------
# Save the raw downloaded data as a CSV.
# We keep the raw file untouched so we can always go back
# to it if something goes wrong later in processing.
# -----------------------------------------------------------
output_path <- "data/raw/weather_daily_raw.csv"
write_csv(weather_combined, output_path)

cat("\nWeather data saved to:", output_path, "\n")
cat("Script 01 complete.\n")

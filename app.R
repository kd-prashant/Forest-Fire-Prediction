# ==============================================================================
# app.R
# Interactive Web Dashboard for Real-Time Wildfire Early Warning Inference
# M.Tech Minor Project — AI/ML Environmental Risk Analytics
# Framework: R Shiny + bslib (Modern Responsive Web Interface)
# ==============================================================================

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(xgboost)
  library(tabnet)
  library(torch)
  library(jsonlite)
  library(httr)
  library(ggplot2)
  library(dplyr)
})

# ------------------------------------------------------------------------------
# 1. Load Pretrained Artifacts & Metadata
# ------------------------------------------------------------------------------
prep_info       <- readRDS("data/processed/preprocessing_info.rds")
district_levels <- prep_info$district_levels
scaling_params  <- prep_info$scaling_params
feature_cols    <- prep_info$feature_cols

model_xgb <- if (file.exists("outputs/models/xgboost_tuned.rds")) {
  readRDS("outputs/models/xgboost_tuned.rds")
} else if (file.exists("outputs/models/xgboost.rds")) {
  readRDS("outputs/models/xgboost.rds")
} else {
  NULL
}

model_tabnet <- if (file.exists("outputs/models/tabnet_model.rds")) {
  tryCatch(readRDS("outputs/models/tabnet_model.rds"), error = function(e) NULL)
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

fetch_api_weather <- function(district_name) {
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
        success      = TRUE,
        avg_temp     = round(mean(daily$temperature_2m_mean, na.rm = TRUE), 1),
        avg_humidity = round(mean(daily$relative_humidity_2m_mean, na.rm = TRUE), 1),
        weekly_rain  = round(sum(daily$precipitation_sum, na.rm = TRUE), 1),
        avg_wind     = round(mean(daily$wind_speed_10m_max, na.rm = TRUE) * 0.27778, 1), # m/s
        dry_days     = sum(daily$precipitation_sum < 0.1)
      )
    } else {
      list(success = FALSE, error = paste("HTTP Status:", status_code(r)))
    }
  }, error = function(e) {
    list(success = FALSE, error = conditionMessage(e))
  })
}

# ------------------------------------------------------------------------------
# 2. UI Layout (Bootstrap 5 via bslib)
# ------------------------------------------------------------------------------
ui <- page_navbar(
  title = "Uttarakhand Wildfire Early Warning System",
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#1a5fa8",
    danger = "#d9534f",
    warning = "#f0ad4e",
    success = "#5cb85c"
  ),
  
  nav_panel(
    title = "Real-Time Risk Simulator",
    layout_sidebar(
      sidebar = sidebar(
        width = 360,
        title = "Inference Controls",
        
        selectInput(
          "district", "Target Administrative District:",
          choices = district_levels, selected = "Nainital"
        ),
        
        actionButton(
          "btn_fetch", "Fetch Live Weather (Open-Meteo API)",
          class = "btn-primary w-100 mb-3", icon = icon("cloud-sun")
        ),
        
        hr(),
        h6("Custom / Stress-Test Parameters:"),
        sliderInput("temp", "Mean Air Temperature (°C):", min = 5, max = 45, value = 24, step = 0.5),
        sliderInput("humidity", "Relative Humidity (%):", min = 10, max = 100, value = 45, step = 1),
        sliderInput("wind", "Wind Speed (m/s):", min = 0.5, max = 12.0, value = 3.0, step = 0.1),
        sliderInput("rain", "Weekly Cumulative Rainfall (mm):", min = 0, max = 150, value = 5, step = 1),
        sliderInput("dry_days", "Consecutive Dry Days (Rain < 1mm):", min = 0, max = 14, value = 5, step = 1),
        sliderInput("month", "Calendar Month (Phenology):", min = 1, max = 12, value = as.numeric(format(Sys.Date(), "%m")), step = 1),
        
        accordion(
          open = FALSE,
          accordion_panel(
            "Advanced Biophysical Indices (MODIS)",
            sliderInput("ndvi", "NDVI (Vegetation Greenness):", min = 0.1, max = 0.8, value = 0.35, step = 0.02),
            sliderInput("lst", "Land Surface Temp (°C):", min = 5, max = 45, value = 28.0, step = 0.5)
          )
        )
      ),
      
      # Main Dashboard Results Panel
      fluidRow(
        column(
          width = 12,
          uiOutput("status_banner")
        )
      ),
      
      fluidRow(
        column(
          width = 6,
          card(
            card_header("Deep Learning Inference (TabNet)"),
            card_body(
              uiOutput("tabnet_prob_card"),
              p(class = "text-muted small mt-2",
                "TabNet architecture with sequential sparsemax attention masks. Optimized for true positive detection sensitivity (Recall = 83.5%).")
            )
          )
        ),
        column(
          width = 6,
          card(
            card_header("Gradient Boosting Inference (XGBoost 5-Fold Tuned)"),
            card_body(
              uiOutput("xgb_prob_card"),
              p(class = "text-muted small mt-2",
                "5-fold cross-validated XGBoost (Depth = 7, Eta = 0.10, Rounds = 100). Optimized for overall precision (Precision = 73.04%, Accuracy = 84.08%).")
            )
          )
        )
      ),
      
      fluidRow(
        column(
          width = 12,
          card(
            card_header("Operational Advisory Protocol"),
            card_body(
              uiOutput("operational_protocol")
            )
          )
        )
      ),
      
      fluidRow(
        column(
          width = 12,
          card(
            card_header("Biophysical Factor Contribution"),
            card_body(
              plotOutput("factor_plot", height = "260px")
            )
          )
        )
      )
    )
  ),
  
  nav_panel(
    title = "Model Benchmark Reference",
    card(
      card_header("Empirical Model Performance on Independent Held-Out Test Set (N = 314)"),
      card_body(
        tableOutput("benchmark_table"),
        p(class = "mt-3",
          strong("Key Takeaway for Field Operations: "),
          "TabNet delivers the highest Recall (83.50%) and F1-score (0.7713), ensuring minimal missed fire events, while Tuned XGBoost delivers the highest accuracy (84.08%) and precision (73.04%).")
      )
    )
  )
)

# ------------------------------------------------------------------------------
# 3. Server Logic
# ------------------------------------------------------------------------------
server <- function(input, output, session) {
  
  # Reactive live API fetch handler
  observeEvent(input$btn_fetch, {
    showNotification(paste("Connecting to Open-Meteo REST API for", input$district, "..."), type = "message", duration = 3)
    data <- fetch_api_weather(input$district)
    
    if (data$success) {
      updateSliderInput(session, "temp",     value = data$avg_temp)
      updateSliderInput(session, "humidity", value = data$avg_humidity)
      updateSliderInput(session, "wind",     value = data$avg_wind)
      updateSliderInput(session, "rain",     value = data$weekly_rain)
      updateSliderInput(session, "dry_days", value = min(14, data$dry_days))
      updateSliderInput(session, "month",    value = as.numeric(format(Sys.Date(), "%m")))
      showNotification("Live meteorological data applied successfully!", type = "default", duration = 3)
    } else {
      showNotification(paste("API Error:", data$error), type = "error", duration = 5)
    }
  })
  
  # Reactive prediction computation
  predictions <- reactive({
    dist_code <- which(district_levels == input$district)
    if (length(dist_code) == 0) dist_code <- 1
    
    raw_df <- data.frame(
      avg_temp            = input$temp,
      avg_humidity        = input$humidity,
      weekly_rain         = input$rain,
      avg_wind            = input$wind,
      max_consec_dry_days = input$dry_days,
      month               = input$month,
      district_encoded    = dist_code,
      avg_ndvi            = input$ndvi,
      avg_lst             = input$lst
    )
    
    # Scale inputs
    scaled_df <- raw_df
    for (col in names(scaling_params)) {
      min_v <- scaling_params[[col]]$min
      max_v <- scaling_params[[col]]$max
      val   <- raw_df[[col]]
      scaled_df[[col]] <- (val - min_v) / (max_v - min_v)
      scaled_df[[col]] <- max(0, min(1, scaled_df[[col]]))
    }
    
    # 1. XGBoost
    p_xgb <- if (!is.null(model_xgb)) {
      mat_in <- as.matrix(scaled_df[, feature_cols])
      as.numeric(predict(model_xgb, newdata = xgb.DMatrix(data = mat_in)))
    } else 0.5
    
    # 2. TabNet
    p_tab <- if (!is.null(model_tabnet)) {
      tryCatch({
        preds_tab <- predict(model_tabnet, new_data = scaled_df[, feature_cols], type = "prob")
        as.numeric(preds_tab$.pred_Yes)
      }, error = function(e) p_xgb)
    } else p_xgb
    
    list(
      p_xgb   = round(p_xgb, 4),
      p_tab   = round(p_tab, 4),
      primary = round(p_tab, 4),
      raw     = raw_df
    )
  })
  
  # Hazard Tier Status Banner
  output$status_banner <- renderUI({
    res <- predictions()
    prob <- res$primary
    
    if (prob >= 0.65) {
      div(class = "alert alert-danger p-3 mb-3",
          h4(class = "alert-heading fw-bold mb-1", "TIER 1 — HIGH WILDFIRE HAZARD (CRITICAL RED ALERT)"),
          p(class = "mb-0", sprintf("Target District: %s | Estimated Fire Occurrence Probability: %.1f%%", input$district, prob * 100))
      )
    } else if (prob >= 0.35) {
      div(class = "alert alert-warning p-3 mb-3",
          h4(class = "alert-heading fw-bold mb-1", "TIER 2 — ELEVATED WILDFIRE HAZARD (ADVISORY WATCH)"),
          p(class = "mb-0", sprintf("Target District: %s | Estimated Fire Occurrence Probability: %.1f%%", input$district, prob * 100))
      )
    } else {
      div(class = "alert alert-success p-3 mb-3",
          h4(class = "alert-heading fw-bold mb-1", "TIER 3 — LOW WILDFIRE HAZARD (BASELINE MONITORING)"),
          p(class = "mb-0", sprintf("Target District: %s | Estimated Fire Occurrence Probability: %.1f%%", input$district, prob * 100))
      )
    }
  })
  
  output$tabnet_prob_card <- renderUI({
    p_val <- predictions()$p_tab
    color_class <- if (p_val >= 0.65) "text-danger" else if (p_val >= 0.35) "text-warning" else "text-success"
    div(
      h2(class = paste("fw-bold", color_class), sprintf("%.1f%%", p_val * 100)),
      div(class = "progress", style = "height: 22px;",
          div(class = paste("progress-bar", if (p_val >= 0.65) "bg-danger" else if (p_val >= 0.35) "bg-warning" else "bg-success"),
              role = "progressbar", style = sprintf("width: %.1f%%;", p_val * 100),
              sprintf("%.1f%%", p_val * 100))
      )
    )
  })
  
  output$xgb_prob_card <- renderUI({
    p_val <- predictions()$p_xgb
    color_class <- if (p_val >= 0.65) "text-danger" else if (p_val >= 0.35) "text-warning" else "text-success"
    div(
      h2(class = paste("fw-bold", color_class), sprintf("%.1f%%", p_val * 100)),
      div(class = "progress", style = "height: 22px;",
          div(class = paste("progress-bar", if (p_val >= 0.65) "bg-danger" else if (p_val >= 0.35) "bg-warning" else "bg-success"),
              role = "progressbar", style = sprintf("width: %.1f%%;", p_val * 100),
              sprintf("%.1f%%", p_val * 100))
      )
    )
  })
  
  output$operational_protocol <- renderUI({
    prob <- predictions()$primary
    if (prob >= 0.65) {
      tagList(
        p(strong("Operational Status: "), "CRITICAL EMERGENCY PREPAREDNESS"),
        tags$ul(
          tags$li("Pre-position ground suppression crews in vulnerable forest compartments."),
          tags$li("Immediate moratorium on agricultural residue burning and controlled pine-needle fires."),
          tags$li("Initiate twice-daily drone / forest guard watch patrol along compartment fire lines."),
          tags$li("Coordinate emergency water replenishment at regional divisional stations.")
        )
      )
    } else if (prob >= 0.35) {
      tagList(
        p(strong("Operational Status: "), "ELEVATED AWARENESS & SURVEILLANCE"),
        tags$ul(
          tags$li("Notify divisional forest officers of rising vapour pressure deficit and fuel dryness."),
          tags$li("Verify standby readiness of quick-response fire fighting equipment and backpack pumps."),
          tags$li("Issue community advisory to village forest councils (Van Panchayats).")
        )
      )
    } else {
      tagList(
        p(strong("Operational Status: "), "ROUTINE BASELINE MONITORING"),
        tags$ul(
          tags$li("Maintain standard automated meteorological surveillance."),
          tags$li("Scheduled maintenance of divisional equipment and radio communications."),
          tags$li("No restrictions required for standard forest operations.")
        )
      )
    }
  })
  
  # Factor contribution plot
  output$factor_plot <- renderPlot({
    res <- predictions()$raw
    
    factors_df <- data.frame(
      Factor = c("Relative Humidity", "Wind Speed", "Consecutive Dry Days", "Temperature", "Rainfall"),
      ObservedValue = c(
        sprintf("%.1f %%", res$avg_humidity),
        sprintf("%.1f m/s", res$avg_wind),
        sprintf("%d days", res$max_consec_dry_days),
        sprintf("%.1f °C", res$avg_temp),
        sprintf("%.1f mm", res$weekly_rain)
      ),
      RiskTendency = c(
        ifelse(res$avg_humidity < 35, "Elevates Fire Hazard", "Suppresses Fire Hazard"),
        ifelse(res$avg_wind > 3.5, "Elevates Fire Hazard", "Suppresses Fire Hazard"),
        ifelse(res$max_consec_dry_days >= 7, "Elevates Fire Hazard", "Suppresses Fire Hazard"),
        ifelse(res$avg_temp > 28, "Elevates Fire Hazard", "Suppresses Fire Hazard"),
        ifelse(res$weekly_rain < 5, "Elevates Fire Hazard", "Suppresses Fire Hazard")
      ),
      ImportanceWeight = c(38.5, 12.5, 9.4, 9.4, 6.7)
    )
    
    ggplot(factors_df, aes(x = reorder(Factor, ImportanceWeight), y = ImportanceWeight, fill = RiskTendency)) +
      geom_col(width = 0.6) +
      geom_text(aes(label = paste0(ObservedValue, " (", round(ImportanceWeight, 1), "%)")),
                hjust = -0.1, size = 3.5, fontface = "bold") +
      scale_fill_manual(values = c("Elevates Fire Hazard" = "#d9534f", "Suppresses Fire Hazard" = "#5cb85c")) +
      scale_y_continuous(limits = c(0, 50), expand = expansion(mult = c(0, 0.15))) +
      coord_flip() +
      labs(
        title = "Key Environmental Drivers & Observed Input Levels",
        x = NULL, y = "Global Factor Importance (%)", fill = "Influence on Risk"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        legend.position = "bottom",
        panel.grid.major.y = element_blank(),
        plot.title = element_text(face = "bold", size = 12)
      )
  })
  
  # Benchmark table
  output$benchmark_table <- renderTable({
    if (file.exists("outputs/all_model_metrics.csv")) {
      readr::read_csv("outputs/all_model_metrics.csv", show_col_types = FALSE)
    }
  }, striped = TRUE, hover = TRUE, bordered = TRUE)
}

# ------------------------------------------------------------------------------
# 4. Launch App
# ------------------------------------------------------------------------------
shinyApp(ui = ui, server = server)


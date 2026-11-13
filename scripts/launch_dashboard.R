# ==============================================================================
# launch_dashboard.R
# One-Command Launcher for Uttarakhand Wildfire Early Warning Web Dashboard
# Opens an interactive graphical user interface in the default web browser
# ==============================================================================

suppressPackageStartupMessages({
  library(shiny)
})

cat("\n")
cat("==============================================================================\n")
cat("     LAUNCHING UTTARAKHAND WILDFIRE EARLY WARNING WEB DASHBOARD (SHINY)      \n")
cat("==============================================================================\n\n")
cat("Starting local HTTP server on http://127.0.0.1:7860 ...\n")
cat("Opening interactive interface in your default web browser...\n")
cat("Press Ctrl + C or Esc in the console to terminate the server.\n\n")

runApp(appDir = ".", port = 7860, launch.browser = TRUE)


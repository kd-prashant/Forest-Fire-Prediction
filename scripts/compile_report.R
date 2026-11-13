# ==============================================================================
# compile_report.R
# Renders final_report.Rmd into both HTML and DOCX (Microsoft Word) formats
# ==============================================================================

cat("\n==============================================================================\n")
cat("      COMPILING RESEARCH REPORT TO INTERACTIVE HTML AND MICROSOFT WORD DOCX    \n")
cat("==============================================================================\n\n")

# Set pandoc path
pandoc_dir <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools"
if (file.exists(file.path(pandoc_dir, "pandoc.exe"))) {
  Sys.setenv(RSTUDIO_PANDOC = pandoc_dir)
  cat("Pandoc path configured:", pandoc_dir, "\n")
}

suppressPackageStartupMessages({
  library(rmarkdown)
  library(knitr)
})

cat("[1/2] Rendering standalone interactive HTML report...\n")
html_out <- render(
  input         = "report/final_report.Rmd",
  output_format = "html_document",
  output_file   = "final_report.html",
  quiet         = FALSE
)
cat("  HTML report compiled successfully:", html_out, "\n\n")

cat("[2/2] Rendering editable Microsoft Word (.docx) manuscript...\n")
docx_out <- render(
  input         = "report/final_report.Rmd",
  output_format = "word_document",
  output_file   = "final_report.docx",
  quiet         = FALSE
)
cat("  DOCX report compiled successfully:", docx_out, "\n\n")

cat("==============================================================================\n")
cat("                    REPORT COMPILATION COMPLETE                               \n")
cat("==============================================================================\n")
cat("Generated Deliverables:\n")
cat("  1. HTML Document: report/final_report.html\n")
cat("  2. Word Document: report/final_report.docx\n\n")


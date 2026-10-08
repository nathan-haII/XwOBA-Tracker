# Runs the whole pipeline from the project root: download -> database -> model
source("R/01_download_data.R")
source("R/02_build_database.R")
source("R/03_model.R")
message("\nAll done. Launch the app with: shiny::runApp('app')")

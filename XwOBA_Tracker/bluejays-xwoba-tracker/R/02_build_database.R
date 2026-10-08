# Step 2: DATA CLEANING + DATABASE
# Reads the raw CSVs, standardises and validates them, and loads them into a
# SQLite database that the modelling step queries with SQL.

source("R/00_config.R")
library(readr)
library(dplyr)
library(DBI)
library(RSQLite)

# "Guerrero Jr., Vladimir" -> "Vladimir Guerrero Jr."
tidy_name <- function(x) sub("^(.*), (.*)$", "\\2 \\1", x)

read_season <- function(path) {
  df <- read_csv(path, show_col_types = FALSE)
  name_col <- grep("first_name", names(df), value = TRUE)[1]
  needed   <- c("player_id", "year", "pa", "bip", "woba", "est_woba")
  missing  <- setdiff(needed, names(df))
  if (is.na(name_col) || length(missing) > 0) {
    stop(basename(path), ": unexpected columns. Missing: ",
         paste(c(if (is.na(name_col)) "name column", missing), collapse = ", "),
         "\nColumns found: ", paste(names(df), collapse = ", "))
  }
  df |>
    transmute(player_id = as.integer(player_id),
              name      = tidy_name(.data[[name_col]]),
              year      = as.integer(year),
              pa        = as.integer(pa),
              bip       = as.integer(bip),
              woba      = as.numeric(woba),
              est_woba  = as.numeric(est_woba))
}

files <- list.files(RAW_DIR, pattern = "^savant_expected_\\d{4}\\.csv$", full.names = TRUE)
if (length(files) == 0) stop("No raw data found. Run R/01_download_data.R first.")

batting <- bind_rows(lapply(files, read_season)) |>
  filter(!is.na(woba), !is.na(est_woba), bip > 0) |>
  distinct(player_id, year, .keep_all = TRUE) |>
  mutate(gap = woba - est_woba)           # actual minus expected: positive = overperformed

# Basic data-quality checks
stopifnot(!anyDuplicated(batting[c("player_id", "year")]))
if (any(batting$woba < 0 | batting$woba > 1.5)) warning("Some wOBA values look out of range")
message("Loaded ", nrow(batting), " player-seasons across ",
        n_distinct(batting$year), " seasons")

roster_path <- file.path(RAW_DIR, "bluejays_roster.csv")
if (!file.exists(roster_path)) stop("Roster file missing. Re-run R/01_download_data.R")
roster <- read_csv(roster_path, show_col_types = FALSE)

dir.create(dirname(DB_PATH), recursive = TRUE, showWarnings = FALSE)
con <- dbConnect(SQLite(), DB_PATH)
dbWriteTable(con, "batting", batting, overwrite = TRUE)
dbWriteTable(con, "roster",  roster,  overwrite = TRUE)
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_batting ON batting (player_id, year)")
dbDisconnect(con)
message("Database written to ", DB_PATH)

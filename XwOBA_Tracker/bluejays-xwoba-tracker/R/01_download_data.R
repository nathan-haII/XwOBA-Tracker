# Step 1: DATA ACQUISITION
# Downloads (a) Baseball Savant expected-stats leaderboards for every season in YEARS
# and (b) the current Blue Jays 40-man roster from the MLB Stats API.
# Files that already exist are skipped, so the script is safe to re-run.

source("R/00_config.R")
library(readr)
library(jsonlite)

dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)
options(timeout = 120)

download_year <- function(year) {
  dest <- file.path(RAW_DIR, sprintf("savant_expected_%d.csv", year))
  if (file.exists(dest)) {
    message(year, ": already downloaded")
    return(TRUE)
  }
  url <- sprintf(paste0("https://baseballsavant.mlb.com/leaderboard/expected_statistics",
                        "?type=batter&year=%d&position=&team=&min=25&csv=true"), year)
  tryCatch({
    df <- read_csv(url, show_col_types = FALSE)
    if (nrow(df) == 0) stop("empty response")
    write_csv(df, dest)
    message(year, ": downloaded ", nrow(df), " rows")
    TRUE
  }, error = function(e) {
    message(year, ": FAILED (", conditionMessage(e), ")")
    FALSE
  })
}

ok <- vapply(YEARS, download_year, logical(1))

# Roster (current season = last year in YEARS)
roster_url <- sprintf(
  "https://statsapi.mlb.com/api/v1/teams/%d/roster?rosterType=40Man&season=%d",
  TEAM_ID, max(YEARS))
tryCatch({
  r <- fromJSON(roster_url, flatten = TRUE)$roster
  roster <- data.frame(player_id     = r$person.id,
                       player        = r$person.fullName,
                       position_type = r$position.type)
  write_csv(roster, file.path(RAW_DIR, "bluejays_roster.csv"))
  message("Roster: saved ", nrow(roster), " players")
}, error = function(e) message("Roster: FAILED (", conditionMessage(e), ")"))

if (!all(ok)) {
  message("\nSome seasons failed to download. Manual fallback: on baseballsavant.mlb.com go to",
          "\nLeaderboards > Expected Statistics, pick Batters + the season, click the CSV button,",
          "\nand save it as data/raw/savant_expected_<year>.csv")
}

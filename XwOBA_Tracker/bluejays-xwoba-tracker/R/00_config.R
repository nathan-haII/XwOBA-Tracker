# Shared settings used by every script. Run all scripts from the project root.

YEARS    <- c(2016:2019, 2021:2026)   # 2020 skipped (60-game season)
TEAM_ID  <- 141                       # Toronto Blue Jays in the MLB Stats API
MIN_BIP  <- 100                       # min. batted balls for a season to count in the model
MIN_BIP_DISPLAY <- 50                 # min. batted balls to show a player in the app

RAW_DIR  <- "data/raw"
DB_PATH  <- "data/processed/baseball.sqlite"

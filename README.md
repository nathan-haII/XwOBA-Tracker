# Blue Jays Luck Tracker: do results beat quality of contact, and does it last?

An end-to-end baseball analytics project in R: data acquisition, cleaning, a SQL database,
statistical modelling, visualization, and an interactive Shiny app.

## Questions
1. Which Blue Jays hitters are getting better or worse results than their quality of contact suggests (wOBA vs. xwOBA)?
2. Does that "luck gap" carry over to the next season, or is it mostly noise?
3. Which stat best predicts a hitter's next-season wOBA: last season's wOBA, last season's xwOBA, or a blend?

## Results

![Gap persistence](XwOBA_figure_3.png)
![Model comparison](XwOBA_figure_1.png)
![Blue Jays gap](XwOBA_figure_2.png)

## How it works
| Step | Script | What it does |
|---|---|---|
| 1 | `R/01_download_data.R` | Downloads Baseball Savant expected-stats leaderboards (2016-2026, excluding 2020) and the Blue Jays roster from the MLB Stats API |
| 2 | `R/02_build_database.R` | Cleans and validates the data, loads it into a SQLite database |
| 3 | `R/03_model.R` | SQL self-join to pair each season with the next, trains and tests models on a held-out season, makes charts, exports data for the app |
| 4 | `app/app.R` | Shiny app: team chart, per-player history, model comparison |

## Run it
```r
install.packages(c("tidyverse", "jsonlite", "DBI", "RSQLite", "shiny"))
source("run_all.R")          # run from the project root
shiny::runApp("app")
```
If a Savant download fails, download the CSV manually (Leaderboards > Expected Statistics > Batters)
and save it as `data/raw/savant_expected_<year>.csv`, then run steps 2 and 3.
To use another team, change `TEAM_ID` in `R/00_config.R`.

## Method notes
- **wOBA** measures the value of a hitter's results. **xwOBA** estimates it from exit velocity and launch angle.
- The model's training seasons are everything before the last season pair; the last pair is held out for testing, so the comparison is not scored on data the model has seen.
- Season pairs require at least 100 batted balls in both seasons.

## Limitations
- xwOBA ignores sprint speed, defensive shifts and ballpark effects, so a persistent gap can reflect real skill.
- The model uses only two inputs and no age or aging curve.
- Small samples are noisy. The app hides hitters with fewer than 50 batted balls.
- Players traded midseason appear with their full-season stats, including time with other teams.

## Data sources
Baseball Savant (Statcast) and the MLB Stats API.

## Ideas for next steps
- Add age and an aging curve to the model.
- Use pitch-level Statcast data to look at specific batted-ball profiles.
- Repeat the analysis for pitchers.

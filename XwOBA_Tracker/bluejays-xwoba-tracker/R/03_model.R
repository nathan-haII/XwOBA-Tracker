# Step 3: SQL + STATISTICAL MODELLING + VISUALIZATION
#
# Question 1: Does a hitter's "luck gap" (wOBA minus xwOBA) carry over to next season?
# Question 2: Which is the better predictor of next season's wOBA:
#             last season's wOBA, last season's xwOBA, or a blend of both?
#
# Method: pair every hitter-season with the same hitter's following season (SQL
# self-join), train on older seasons, and test on the most recent season pair.

source("R/00_config.R")
library(dplyr)
library(ggplot2)
library(DBI)
library(RSQLite)

dir.create("figures", showWarnings = FALSE)
dir.create("results", showWarnings = FALSE)

con <- dbConnect(SQLite(), DB_PATH)

# ---- 1. SQL: build year-over-year pairs --------------------------------------
pairs_sql <- sprintf("
  SELECT a.player_id, a.name, a.year AS year_t,
         a.bip      AS bip_t,
         a.woba     AS woba_t,
         a.est_woba AS xwoba_t,
         b.woba     AS woba_next,
         b.est_woba AS xwoba_next
  FROM batting a
  JOIN batting b
    ON b.player_id = a.player_id AND b.year = a.year + 1
  WHERE a.bip >= %d AND b.bip >= %d", MIN_BIP, MIN_BIP)

pairs <- dbGetQuery(con, pairs_sql) |>
  mutate(gap_t = woba_t - xwoba_t, gap_next = woba_next - xwoba_next)

if (nrow(pairs) < 50) stop("Only ", nrow(pairs), " season pairs found. Check the downloads.")
message("Season pairs: ", nrow(pairs))

# ---- 2. Does the luck gap persist? -------------------------------------------
gap_fit <- lm(gap_next ~ gap_t, data = pairs)
gap_slope <- unname(coef(gap_fit)["gap_t"])
gap_r2    <- summary(gap_fit)$r.squared
message(sprintf("Gap persistence: slope = %.2f, R^2 = %.3f", gap_slope, gap_r2))

p1 <- ggplot(pairs, aes(gap_t, gap_next)) +
  geom_point(alpha = 0.35) +
  geom_smooth(method = "lm", se = TRUE, colour = "#134A8E") +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_vline(xintercept = 0, linetype = "dashed") +
  labs(title = "Does overperforming xwOBA carry over to next season?",
       subtitle = sprintf("Each point is one hitter, season t vs t+1 (slope = %.2f, R\u00b2 = %.2f)",
                          gap_slope, gap_r2),
       x = "Season t: wOBA - xwOBA", y = "Season t+1: wOBA - xwOBA")
ggsave("figures/gap_persistence.png", p1, width = 8, height = 5, dpi = 150)

# ---- 3. Which predictor forecasts next-year wOBA best? ------------------------
test_year <- max(pairs$year_t)
train <- filter(pairs, year_t <  test_year)
test  <- filter(pairs, year_t == test_year)
rmse  <- function(pred, actual) sqrt(mean((pred - actual)^2))

blend_fit <- lm(woba_next ~ woba_t + xwoba_t, data = train)

comparison <- data.frame(
  model = c("League average", "Last season's wOBA", "Last season's xwOBA",
            "Blend of wOBA and xwOBA (regression)"),
  rmse  = c(rmse(mean(train$woba_next), test$woba_next),
            rmse(test$woba_t,  test$woba_next),
            rmse(test$xwoba_t, test$woba_next),
            rmse(predict(blend_fit, test), test$woba_next))
) |> mutate(rmse = round(rmse, 4)) |> arrange(rmse)

message("Held-out test: season ", test_year, " -> ", test_year + 1,
        " (", nrow(test), " hitters)")
print(comparison)
write.csv(comparison, "results/model_comparison.csv", row.names = FALSE)

p2 <- ggplot(comparison, aes(reorder(model, -rmse), rmse)) +
  geom_col(fill = "#134A8E") +
  geom_text(aes(label = sprintf("%.4f", rmse)), hjust = -0.1) +
  coord_flip(ylim = c(0, max(comparison$rmse) * 1.15)) +
  labs(title = "Predicting next season's wOBA (lower error is better)",
       subtitle = sprintf("Trained on earlier seasons, tested on %d \u2192 %d (%d hitters)",
                          test_year, test_year + 1, nrow(test)),
       x = NULL, y = "RMSE")
ggsave("figures/model_comparison.png", p2, width = 8, height = 4, dpi = 150)

# ---- 4. Apply the final model to the current Blue Jays hitters ----------------
final_fit <- lm(woba_next ~ woba_t + xwoba_t, data = pairs)   # trained on all pairs
latest    <- as.integer(dbGetQuery(con, "SELECT MAX(year) AS y FROM batting")$y)

jays_sql <- sprintf("
  SELECT b.player_id, b.name AS player, b.bip, b.woba, b.est_woba AS xwoba, b.gap
  FROM batting b
  JOIN roster r ON r.player_id = b.player_id
  WHERE b.year = %d AND b.bip >= %d AND r.position_type <> 'Pitcher'",
  latest, MIN_BIP_DISPLAY)

jays <- dbGetQuery(con, jays_sql)
if (nrow(jays) == 0) stop("No Blue Jays hitters matched. Check the roster file and player IDs.")
jays$pred_next_woba <- predict(final_fit,
                               newdata = data.frame(woba_t = jays$woba, xwoba_t = jays$xwoba))

history <- dbGetQuery(con, sprintf("
  SELECT player_id, name AS player, year, bip, woba, est_woba AS xwoba
  FROM batting
  WHERE player_id IN (%s) ORDER BY player_id, year",
  paste(jays$player_id, collapse = ",")))

dbDisconnect(con)

p3 <- ggplot(jays, aes(reorder(player, gap), gap, fill = gap > 0)) +
  geom_col(show.legend = FALSE) +
  coord_flip() +
  scale_fill_manual(values = c("TRUE" = "#134A8E", "FALSE" = "#E8291C")) +
  labs(title = sprintf("Blue Jays hitters, %d: actual minus expected wOBA", latest),
       subtitle = sprintf("Minimum %d batted balls. Blue = outperformed contact quality.", MIN_BIP_DISPLAY),
       x = NULL, y = "wOBA - xwOBA")
ggsave("figures/bluejays_gap.png", p3, width = 8, height = 6, dpi = 150)

# ---- 5. Save everything the Shiny app needs -----------------------------------
saveRDS(list(jays = jays, history = history, comparison = comparison,
             gap_slope = gap_slope, gap_r2 = gap_r2,
             latest = latest, test_year = test_year, n_pairs = nrow(pairs)),
        "app/app_data.rds")
message("Done. Charts are in figures/, app data saved to app/app_data.rds")

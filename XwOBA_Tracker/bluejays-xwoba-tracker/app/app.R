# Shiny app: explore Blue Jays hitters' results vs. quality of contact.
# Run R/03_model.R first (it creates app_data.rds), then: shiny::runApp("app")

library(shiny)
library(ggplot2)
library(dplyr)

d <- readRDS("app_data.rds")

ui <- fluidPage(
  titlePanel("Blue Jays hitters: results vs. quality of contact"),
  sidebarLayout(
    sidebarPanel(
      selectInput("player", "Player", choices = sort(d$jays$player)),
      helpText("wOBA measures how much a hitter's results are worth. xwOBA estimates what",
               "those results 'should' have been from exit velocity and launch angle.",
               "A positive gap means results beat the quality of contact."),
      width = 3
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Team", plotOutput("team_plot", height = 550)),
        tabPanel("Player",
                 plotOutput("player_plot", height = 350),
                 tableOutput("player_tbl"),
                 textOutput("player_pred")),
        tabPanel("Model",
                 h4("Which stat best predicts next season's wOBA?"),
                 tableOutput("model_tbl"),
                 textOutput("model_note"))
      )
    )
  )
)

server <- function(input, output, session) {

  output$team_plot <- renderPlot({
    ggplot(d$jays, aes(reorder(player, gap), gap, fill = gap > 0)) +
      geom_col(show.legend = FALSE) +
      coord_flip() +
      scale_fill_manual(values = c("TRUE" = "#134A8E", "FALSE" = "#E8291C")) +
      labs(title = sprintf("%d: actual minus expected wOBA", d$latest),
           x = NULL, y = "wOBA - xwOBA")
  })

  player_hist <- reactive(filter(d$history, player == input$player))

  output$player_plot <- renderPlot({
    h <- player_hist()
    ggplot(h, aes(year)) +
      geom_line(aes(y = woba,  colour = "wOBA (actual)"),    linewidth = 1) +
      geom_point(aes(y = woba,  colour = "wOBA (actual)")) +
      geom_line(aes(y = xwoba, colour = "xwOBA (expected)"), linewidth = 1, linetype = "dashed") +
      geom_point(aes(y = xwoba, colour = "xwOBA (expected)")) +
      scale_colour_manual(values = c("wOBA (actual)" = "#134A8E", "xwOBA (expected)" = "#E8291C")) +
      scale_x_continuous(breaks = unique(h$year)) +
      labs(title = input$player, x = NULL, y = "wOBA", colour = NULL)
  })

  output$player_tbl <- renderTable({
    player_hist() |>
      transmute(Season = as.integer(year), `Batted balls` = as.integer(bip),
                wOBA = round(woba, 3), xwOBA = round(xwoba, 3),
                Gap = round(woba - xwoba, 3))
  })

  output$player_pred <- renderText({
    p <- filter(d$jays, player == input$player)
    sprintf("Model-based projection of %s's %d wOBA: %.3f (based on his %d wOBA of %.3f and xwOBA of %.3f).",
            input$player, d$latest + 1, p$pred_next_woba, d$latest, p$woba, p$xwoba)
  })

  output$model_tbl <- renderTable({
    transmute(d$comparison, Model = model, `Error (RMSE)` = rmse)
  })

  output$model_note <- renderText({
    sprintf(paste("Trained on earlier seasons and tested on %d to %d. Across %d hitter-season pairs,",
                  "a hitter's wOBA-minus-xwOBA gap carried over to the next season with slope %.2f",
                  "(R-squared %.2f); a slope near 0 means the gap is mostly noise."),
            d$test_year, d$test_year + 1, d$n_pairs, d$gap_slope, d$gap_r2)
  })
}

shinyApp(ui, server)

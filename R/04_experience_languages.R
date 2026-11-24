# ------------------------------------------------------------------------------
# 04_experience_languages.R   |   Question 4: language trends and experience
# Needs: objects from 03_databases_languages.R (or runs it)
# ------------------------------------------------------------------------------
source("R/helpers.R")
if (!exists("survey")) survey <- readRDS("data/processed/survey_clean.rds")
if (!exists("lang_have")) source("R/03_databases_languages.R")

# ---- 4a. Trend of the top-5 languages in current use -----------------------------------
lang_trend <- lang_have |> filter(tech %in% top5_lang_have)

p_lang_trend <- ggplot(lang_trend, aes(Year, pct, colour = tech, group = tech)) +
  geom_line(linewidth = 1.3) + geom_point(size = 3) +
  geom_text_repel(data = ~ filter(.x, Year == 2023),
                  aes(label = paste0(tech, "  ", percent(pct, 1))),
                  nudge_x = 0.1, direction = "y", hjust = 0, size = 3.8,
                  min.segment.length = Inf, show.legend = FALSE) +
  scale_x_continuous(breaks = 2021:2023, expand = expansion(mult = c(0.03, 0.4))) +
  scale_y_continuous(labels = percent, limits = c(0.3, 0.7)) +
  scale_colour_manual(values = pal[1:5]) +
  labs(title = "Top 5 programming languages in current use, 2021-2023",
       subtitle = "Share of respondents who answered the question",
       x = NULL, y = NULL, caption = caption_so) +
  theme_so() + theme(legend.position = "none")

# ---- 4b. Experience (YearsCode) vs the top-5 languages and databases ---------------------
# For each experience band: what share of those respondents use each technology?
experience_share <- function(data, col, techs) {
  d <- data |> filter(!is.na(ExperienceBand), !is.na({{ col }}))
  band_n <- d |> count(ExperienceBand, name = "band_n")
  split_multi(d, {{ col }}, ExperienceBand) |>
    filter(tech %in% techs) |>
    count(ExperienceBand, tech, name = "n") |>
    left_join(band_n, by = "ExperienceBand") |>
    mutate(pct = n / band_n)
}

heatmap_exp <- function(df, title, low, high) {
  df |>
    mutate(tech = factor(tech, levels = rev(unique(tech[order(-pct)]))),
           label_colour = if_else(pct > 0.5, "white", "grey15")) |>
    ggplot(aes(ExperienceBand, tech, fill = pct)) +
    geom_tile(colour = "white", linewidth = 0.8) +
    geom_text(aes(label = percent(pct, 1), colour = label_colour), size = 3.6,
              show.legend = FALSE) +
    scale_colour_identity() +
    scale_fill_gradient(low = low, high = high, labels = percent, limits = c(0, 1),
                        name = "Share using it") +
    labs(title = title, x = "Years of coding experience", y = NULL) +
    theme_so(11) + theme(panel.grid = element_blank(), legend.position = "right")
}

exp_lang <- experience_share(survey, LanguageHaveWorkedWith, top5_lang_have)
exp_db   <- experience_share(survey, DatabaseHaveWorkedWith, top5_db_have)

p_exp_lang <- heatmap_exp(exp_lang, "Top 5 languages", "#EAF3FA", "#0072B2")
p_exp_db   <- heatmap_exp(exp_db,   "Top 5 databases", "#FDF1DC", "#C77D00")

p_experience <- (p_exp_lang / p_exp_db) +
  plot_annotation(
    title = "What developers use, by years of coding experience",
    subtitle = "Each cell: share of respondents in that experience band who use the technology",
    caption = caption_so,
    theme = theme(plot.title = element_text(face = "bold", size = 15),
                  plot.caption = element_text(colour = "grey45"))
  )

# Number of different technologies used, by experience (breadth of stack)
breadth <- function(data, col, label) {
  d <- data |> filter(!is.na(ExperienceBand), !is.na({{ col }}))
  split_multi(d, {{ col }}, ExperienceBand) |>
    count(id, ExperienceBand, name = "k") |>
    group_by(ExperienceBand) |>
    summarise(avg = mean(k), .groups = "drop") |>
    mutate(type = label)
}
stack_breadth <- bind_rows(
  breadth(survey, LanguageHaveWorkedWith, "Languages"),
  breadth(survey, DatabaseHaveWorkedWith, "Databases")
)

save_fig(p_lang_trend,  "q4a_language_trend",   width = 10, height = 5.5)
save_fig(p_experience,  "q4b_experience_heatmaps", width = 10, height = 9)
save_table(lang_trend |> select(tech, Year, n, n_answered, pct), "q4a_language_trend")
save_table(bind_rows(mutate(exp_lang, type = "Language"), mutate(exp_db, type = "Database")),
           "q4b_experience_by_technology")
save_table(stack_breadth, "q4b_stack_breadth_by_experience")
message("04 complete")

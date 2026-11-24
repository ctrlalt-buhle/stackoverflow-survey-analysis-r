# ------------------------------------------------------------------------------
# 03_databases_languages.R   |   Question 3 (and the data behind Question 4)
# Needs: `survey` from 01_import_clean.R
# ------------------------------------------------------------------------------
source("R/helpers.R")
if (!exists("survey")) survey <- readRDS("data/processed/survey_clean.rds")

# ---- 3a/3b. Popularity of each technology (share of respondents who answered) -------
lang_have <- tech_popularity(survey, LanguageHaveWorkedWith)
lang_want <- tech_popularity(survey, LanguageWantToWorkWith)
db_have   <- tech_popularity(survey, DatabaseHaveWorkedWith)
db_want   <- tech_popularity(survey, DatabaseWantToWorkWith)

top5_lang_have <- top_techs(lang_have)
top5_lang_want <- top_techs(lang_want)
top5_db_have   <- top_techs(db_have)
top5_db_want   <- top_techs(db_want)

# Pooled (3-year) ranking table: rank, count and share of those who answered
pooled_top5 <- function(pop, col, type, status) {
  answered_total <- survey |> filter(!is.na({{ col }})) |> nrow()
  pop |>
    group_by(tech) |>
    summarise(respondents = sum(n), .groups = "drop") |>
    slice_max(respondents, n = 5, with_ties = FALSE) |>
    mutate(rank = row_number(), type = type, status = status,
           pct_of_answerers = respondents / answered_total)
}

top5_table <- bind_rows(
  pooled_top5(db_have,   DatabaseHaveWorkedWith, "Database", "Use now"),
  pooled_top5(db_want,   DatabaseWantToWorkWith, "Database", "Want to use"),
  pooled_top5(lang_have, LanguageHaveWorkedWith, "Language", "Use now"),
  pooled_top5(lang_want, LanguageWantToWorkWith, "Language", "Want to use")
) |>
  select(type, status, rank, tech, respondents, pct_of_answerers)

plot_top5 <- function(tbl, title) {
  tbl |>
    mutate(tech = fct_reorder(tech, pct_of_answerers)) |>
    ggplot(aes(pct_of_answerers, tech, fill = status)) +
    geom_col(width = 0.7, show.legend = FALSE) +
    geom_text(aes(label = percent(pct_of_answerers, 1)), hjust = -0.15, size = 3.4) +
    facet_wrap(~ status, scales = "free_y") +
    scale_x_continuous(labels = percent, expand = expansion(mult = c(0, 0.18))) +
    scale_fill_manual(values = c("Use now" = pal[1], "Want to use" = pal[2])) +
    labs(title = title, x = "Share of respondents who answered", y = NULL,
         caption = caption_so) +
    theme_so() + theme(panel.grid.major.y = element_blank())
}

p_top5_db   <- plot_top5(filter(top5_table, type == "Database"),
                         "Top 5 databases: used now vs. wanted (2021-2023 pooled)")
p_top5_lang <- plot_top5(filter(top5_table, type == "Language"),
                         "Top 5 languages: used now vs. wanted (2021-2023 pooled)")

# ---- 3c. Trend of the top-5 databases over the three years ----------------------------
trend_data <- function(have, want, techs_have, techs_want) {
  bind_rows(
    have |> filter(tech %in% techs_have) |> mutate(status = "Use now"),
    want |> filter(tech %in% techs_want) |> mutate(status = "Want to use")
  ) |>
    mutate(status = factor(status, levels = c("Use now", "Want to use")))
}

plot_trend <- function(data, title, subtitle) {
  ggplot(data, aes(Year, pct, colour = tech, group = tech)) +
    geom_line(linewidth = 1.2) + geom_point(size = 2.6) +
    geom_text_repel(data = ~ filter(.x, Year == 2023), aes(label = tech),
                    nudge_x = 0.15, direction = "y", hjust = 0, size = 3.4,
                    min.segment.length = Inf, show.legend = FALSE) +
    facet_wrap(~ status) +
    scale_x_continuous(breaks = 2021:2023, expand = expansion(mult = c(0.05, 0.38))) +
    scale_y_continuous(labels = percent) +
    scale_colour_manual(values = rep(pal, length.out = n_distinct(data$tech))) +
    labs(title = title, subtitle = subtitle, x = NULL, y = "Share of respondents who answered",
         caption = caption_so) +
    theme_so() + theme(legend.position = "none")
}

db_trend <- trend_data(db_have, db_want, top5_db_have, top5_db_want)
p_db_trend <- plot_trend(db_trend, "Database popularity, 2021-2023",
                         "Top 5 databases by current use and by wish-to-use")

# ---- Extra: technologies people WANT but have NOT yet used -------------------------------
# Brief (Q3 intro): "which databases and languages users have not used yet but would like to".
# For each respondent: wanted technologies minus technologies they already use.
want_not_used <- function(data, have_col, want_col) {
  answered_both <- data |> filter(!is.na({{ have_col }}), !is.na({{ want_col }}))
  have <- split_multi(answered_both, {{ have_col }})
  want <- split_multi(answered_both, {{ want_col }})
  anti_join(want, have, by = c("id", "tech")) |>
    count(tech, name = "n") |>
    mutate(pct = n / nrow(answered_both)) |>
    arrange(desc(n))
}

db_wnu   <- want_not_used(survey, DatabaseHaveWorkedWith, DatabaseWantToWorkWith)
lang_wnu <- want_not_used(survey, LanguageHaveWorkedWith, LanguageWantToWorkWith)

plot_wnu <- function(tbl, title) {
  tbl |> slice_head(n = 8) |>
    mutate(tech = fct_reorder(tech, pct)) |>
    ggplot(aes(pct, tech)) +
    geom_col(fill = pal[4], width = 0.7) +
    geom_text(aes(label = percent(pct, 0.1)), hjust = -0.15, size = 3.4) +
    scale_x_continuous(labels = percent, expand = expansion(mult = c(0, 0.15))) +
    labs(title = title, subtitle = "Wanted by the respondent but not yet used",
         x = "Share of respondents who answered both questions", y = NULL,
         caption = caption_so) +
    theme_so() + theme(panel.grid.major.y = element_blank())
}
p_db_wnu   <- plot_wnu(db_wnu,   "Databases people want to try")
p_lang_wnu <- plot_wnu(lang_wnu, "Languages people want to try")

# ---- Extra: retention ("would you keep using it?") ------------------------------------------
retention <- function(data, have_col, want_col, min_users = 2000) {
  answered_both <- data |> filter(!is.na({{ have_col }}), !is.na({{ want_col }}))
  have <- split_multi(answered_both, {{ have_col }})
  want <- split_multi(answered_both, {{ want_col }})
  have |>
    mutate(keeps = paste(id, tech) %in% paste(want$id, want$tech)) |>
    group_by(tech) |>
    summarise(users = n(), retention = mean(keeps), .groups = "drop") |>
    filter(users >= min_users) |>
    arrange(desc(retention))
}
lang_retention <- retention(survey, LanguageHaveWorkedWith, LanguageWantToWorkWith)
db_retention   <- retention(survey, DatabaseHaveWorkedWith, DatabaseWantToWorkWith)

save_fig(p_top5_db,   "q3a_top5_databases",  width = 10, height = 4.5)
save_fig(p_top5_lang, "q3b_top5_languages",  width = 10, height = 4.5)
save_fig(p_db_trend,  "q3c_database_trend",  width = 11, height = 5)
save_fig(p_db_wnu / p_lang_wnu, "q3x_want_but_not_used", width = 9, height = 9)
save_table(top5_table,     "q3ab_top5_databases_languages")
save_table(db_trend |> select(status, tech, Year, n, n_answered, pct), "q3c_database_trend")
save_table(db_wnu,         "q3x_databases_want_not_used")
save_table(lang_wnu,       "q3x_languages_want_not_used")
save_table(lang_retention, "q3x_language_retention")
save_table(db_retention,   "q3x_database_retention")
message("03 complete")

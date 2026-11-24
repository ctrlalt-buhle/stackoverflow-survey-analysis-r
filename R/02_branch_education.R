# ------------------------------------------------------------------------------
# 02_branch_education.R   |   Question 2: branches, education, relationships
# Needs: `survey` from 01_import_clean.R
# ------------------------------------------------------------------------------
source("R/helpers.R")
if (!exists("survey")) survey <- readRDS("data/processed/survey_clean.rds")

branch_pal <- setNames(pal[c(1, 6, 2, 3, 5)], levels(survey$Branch))

# ---- 2a/2b. Category tables (what each original label became) ---------------------
branch_map <- survey |> count(MainBranch, Branch) |> arrange(Branch, desc(n))
edu_map    <- survey |> count(EdLevel, Education) |> arrange(Education, desc(n))

# ---- 2c. Participants per branch per year -------------------------------------------
branch_year <- survey |>
  count(Year, Branch, name = "n") |>
  group_by(Year) |>
  mutate(pct = n / sum(n)) |>
  ungroup()

p_branch_counts <- ggplot(branch_year, aes(Year, n, colour = Branch)) +
  geom_line(linewidth = 1.1) + geom_point(size = 2.5) +
  scale_x_continuous(breaks = 2021:2023) +
  scale_y_continuous(labels = comma) +
  scale_colour_manual(values = branch_pal) +
  labs(title = "Respondents by branch", subtitle = "Number of participants",
       x = NULL, y = NULL, colour = NULL) +
  theme_so() + guides(colour = guide_legend(nrow = 2))

p_branch_share <- branch_year |>
  filter(Branch != "Professional developer") |>   # dominant group would squash the rest
  ggplot(aes(Year, pct, colour = Branch)) +
  geom_line(linewidth = 1.1) + geom_point(size = 2.5) +
  geom_text_repel(data = ~ filter(.x, Year == 2023),
                  aes(label = percent(pct, 0.1)), nudge_x = 0.12,
                  direction = "y", size = 3.3, show.legend = FALSE,
                  min.segment.length = Inf) +
  scale_x_continuous(breaks = 2021:2023, expand = expansion(mult = c(0.05, 0.2))) +
  scale_y_continuous(labels = percent) +
  scale_colour_manual(values = branch_pal) +
  labs(title = "Share of all respondents", subtitle = "Professional developers excluded to show detail",
       x = NULL, y = NULL, colour = NULL) +
  theme_so() + guides(colour = guide_legend(nrow = 2))

p_branch_trend <- (p_branch_counts | p_branch_share) +
  plot_annotation(caption = caption_so, theme = theme(plot.caption = element_text(colour = "grey45")))

# ---- 2d. Relationships between Branch and Age / Country / EdLevel / YearsCode ---------
stack_pct <- function(data, y_var, title, y_lab = NULL) {
  data |>
    filter(!is.na({{ y_var }})) |>
    count({{ y_var }}, Branch) |>
    group_by({{ y_var }}) |>
    mutate(pct = n / sum(n)) |>
    ungroup() |>
    ggplot(aes(pct, {{ y_var }}, fill = Branch)) +
    geom_col(width = 0.75) +
    scale_x_continuous(labels = percent, expand = expansion(mult = c(0, 0.01))) +
    scale_fill_manual(values = branch_pal) +
    labs(title = title, x = NULL, y = y_lab, fill = NULL) +
    theme_so(11) + theme(panel.grid.major.y = element_blank())
}

p_rel_age <- stack_pct(survey, AgeGroup, "Age group") +
  scale_y_discrete(limits = rev(levels(survey$AgeGroup)))

p_rel_edu <- stack_pct(survey, Education, "Education level") +
  scale_y_discrete(limits = rev(levels(survey$Education)),
                   labels = \(x) str_wrap(x, 24))

country_order <- top_countries_order <- survey |> count(Country, sort = TRUE) |> pull(Country)
p_rel_country <- stack_pct(survey, Country, "Country") +
  scale_y_discrete(limits = rev(country_order))

p_rel_years <- survey |>
  filter(!is.na(YearsCodeNum)) |>
  ggplot(aes(Branch, YearsCodeNum, fill = Branch)) +
  geom_boxplot(outlier.alpha = 0.15, outlier.size = 0.8, show.legend = FALSE) +
  scale_fill_manual(values = branch_pal) +
  scale_x_discrete(labels = \(x) str_wrap(x, 12)) +
  labs(title = "Years of coding experience", x = NULL, y = "Years coding") +
  theme_so(11)

p_branch_relationships <- (p_rel_age + p_rel_edu) / (p_rel_country + p_rel_years) +
  plot_layout(guides = "collect") +
  plot_annotation(
    title = "How branch relates to age, education, country and experience",
    caption = caption_so,
    theme = theme(plot.title = element_text(face = "bold", size = 15),
                  plot.caption = element_text(colour = "grey45"),
                  legend.position = "bottom")
  ) & theme(legend.position = "bottom")

# Quantify the visual impression: association strength between Branch and each variable
cramers_tbl <- tibble(
  variable = c("Age group", "Education level", "Country"),
  measure  = "Cramer's V (0 = none, 1 = perfect)",
  strength = c(
    cramers_v(survey$Branch[!is.na(survey$AgeGroup)],  survey$AgeGroup[!is.na(survey$AgeGroup)]),
    cramers_v(survey$Branch[!is.na(survey$Education)], survey$Education[!is.na(survey$Education)]),
    cramers_v(survey$Branch, survey$Country)
  )
) |>
  bind_rows(tibble(
    variable = "Years of coding", measure = "Eta-squared (share of variance explained)",
    strength = summary(lm(YearsCodeNum ~ Branch, data = survey))$r.squared
  )) |>
  arrange(desc(strength))

median_years <- survey |>
  filter(!is.na(YearsCodeNum)) |>
  group_by(Branch) |>
  summarise(median_years = median(YearsCodeNum), n = n(), .groups = "drop")

branch_age <- survey |>
  filter(!is.na(AgeGroup)) |>
  count(Branch, AgeGroup) |>
  group_by(Branch) |>
  mutate(pct = n / sum(n)) |>
  ungroup()

share_within <- function(data, group_var) {
  data |>
    filter(!is.na({{ group_var }})) |>
    count({{ group_var }}, Branch, name = "n") |>
    group_by({{ group_var }}) |>
    mutate(pct = n / sum(n)) |>
    ungroup()
}
branch_country <- share_within(survey, Country)
branch_edu     <- share_within(survey, Education)

save_fig(p_branch_trend,         "q2c_branch_trend",         width = 12, height = 5)
save_fig(p_branch_relationships, "q2d_branch_relationships", width = 13, height = 10)
save_table(branch_map,    "q2a_branch_categories")
save_table(edu_map,       "q2b_education_categories")
save_table(branch_year,   "q2c_branch_by_year")
save_table(cramers_tbl,   "q2d_association_strength")
save_table(branch_age,    "q2d_branch_by_age")
save_table(branch_edu,    "q2d_branch_by_education")
save_table(branch_country,"q2d_branch_by_country")
save_table(median_years,  "q2d_median_years_by_branch")
message("02 complete")

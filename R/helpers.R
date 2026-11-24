# ------------------------------------------------------------------------------
# helpers.R
# Reusable functions and plotting theme for the Stack Overflow survey project.
# Keeping the logic in small, named functions (instead of copy-pasted blocks)
# means each cleaning rule is written once, tested once, and easy to explain.
# ------------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(tidyverse)   # dplyr, tidyr, ggplot2, purrr, stringr, forcats, readr
  library(scales)      # percent / comma label formatters
  library(patchwork)   # combining several ggplots into one figure
  library(ggrepel)     # non-overlapping direct labels on line charts
})

# ---- Constants ---------------------------------------------------------------

# The only columns the brief asks us to work with
keep_cols <- c(
  "YearsCode", "MainBranch", "Country", "EdLevel",
  "LanguageHaveWorkedWith", "LanguageWantToWorkWith",
  "DatabaseHaveWorkedWith", "DatabaseWantToWorkWith", "Age"
)

# Colour-blind-friendly palette (Okabe-Ito)
pal <- c("#0072B2", "#E69F00", "#009E73", "#D55E00", "#CC79A7",
         "#56B4E9", "#F0E442", "#999999")

# ---- Cleaning functions -------------------------------------------------------

#' Give every country one common name.
#' The survey uses formal UN-style names in some places ("Republic of Korea")
#' and common names in others ("South Korea"), and the formal names change
#' between years. Pattern matching (rather than exact strings) keeps this robust
#' to apostrophe styles. "Nomadic" is not a country, so it becomes NA.
standardise_country <- function(x) {
  case_when(
    str_detect(x, "^United States")                      ~ "United States",
    str_detect(x, "^United Kingdom")                     ~ "United Kingdom",
    str_detect(x, "^Russian Federation")                 ~ "Russia",
    str_detect(x, "^Republic of Korea")                  ~ "South Korea",
    str_detect(x, "^Democratic People.s Republic of Korea") ~ "North Korea",
    str_detect(x, "^Iran")                               ~ "Iran",
    str_detect(x, "^Viet Nam")                           ~ "Vietnam",
    str_detect(x, "^Venezuela")                          ~ "Venezuela",
    str_detect(x, "^Hong Kong")                          ~ "Hong Kong",
    str_detect(x, "^Syrian Arab Republic")               ~ "Syria",
    str_detect(x, "^Libyan Arab Jamahiriya")             ~ "Libya",
    str_detect(x, "^United Republic of Tanzania")        ~ "Tanzania",
    str_detect(x, "^The former Yugoslav Republic of Macedonia") ~ "North Macedonia",
    str_detect(x, "^Republic of Moldova")                ~ "Moldova",
    str_detect(x, "^Congo, Republic")                    ~ "Republic of the Congo",
    str_detect(x, "^Lao People")                         ~ "Laos",
    str_detect(x, "^Micronesia")                         ~ "Micronesia",
    str_detect(x, "^Brunei")                             ~ "Brunei",
    x == "Swaziland"                                     ~ "Eswatini",
    x == "Cape Verde"                                    ~ "Cabo Verde",
    x == "Nomadic"                                       ~ NA_character_,
    .default = x
  )
}

#' Collapse the MainBranch wording (which changed between survey years) into
#' five stable categories ("None of these" is folded into "Former developer or
#' other": those respondents were not asked for a country in 2022-23, so they
#' vanish from the country-filtered data and cannot be tracked as their own group). NOTE: 2021 says "a student who is learning to code"
#' while 2022-23 say "learning to code", so matching on "student" alone would
#' silently drop learners from 2022 and 2023.
recode_branch <- function(x) {
  out <- case_when(
    str_detect(x, "^I am a developer by profession")         ~ "Professional developer",
    str_detect(x, "learning to code")                        ~ "Learning to code",
    str_detect(x, "hobby")                                   ~ "Hobbyist",
    str_detect(x, "not primarily a developer")               ~ "Codes as part of work",
    str_detect(x, "used to be a developer|None of these")    ~ "Former developer or other",
    .default = NA_character_
  )
  factor(out, levels = c("Professional developer", "Codes as part of work",
                         "Learning to code", "Hobbyist",
                         "Former developer or other"))
}

#' Collapse eleven EdLevel labels into seven ordered, concise categories.
recode_education <- function(x) {
  out <- case_when(
    str_detect(x, "^Primary|^Secondary")            ~ "School (primary / secondary)",
    str_detect(x, "^Some college")                  ~ "Some college, no degree",
    str_detect(x, "^Associate")                     ~ "Associate degree",
    str_detect(x, "^Bachelor")                      ~ "Bachelor's degree",
    str_detect(x, "^Master")                        ~ "Master's degree",
    str_detect(x, "doctoral|^Professional degree")  ~ "Doctoral / professional degree",
    str_detect(x, "^Something else")                ~ "Other",
    .default = NA_character_
  )
  factor(out, ordered = TRUE,
         levels = c("School (primary / secondary)", "Some college, no degree",
                    "Associate degree", "Bachelor's degree", "Master's degree",
                    "Doctoral / professional degree", "Other"))
}

#' Age is a *range label*, not a number, so it becomes an ordered factor.
#' "Prefer not to say" carries no information about age, so it becomes NA.
clean_age <- function(x) {
  x <- na_if(x, "Prefer not to say")
  factor(x, ordered = TRUE,
         levels = c("Under 18 years old", "18-24 years old", "25-34 years old",
                    "35-44 years old", "45-54 years old", "55-64 years old",
                    "65 years or older"))
}

#' YearsCode is stored as text because two answers are words.
#' "Less than 1 year" -> 0.5 and "More than 50 years" -> 50 (capped).
years_code_to_numeric <- function(x) {
  case_when(
    x == "Less than 1 year"  ~ 0.5,
    x == "More than 50 years" ~ 50,
    .default = suppressWarnings(as.numeric(x))
  )
}

#' Group years of coding into readable experience bands.
experience_band <- function(years) {
  cut(years, breaks = c(-Inf, 2, 5, 10, 20, Inf),
      labels = c("0-2 yrs", "3-5 yrs", "6-10 yrs", "11-20 yrs", "20+ yrs"),
      right = TRUE, ordered_result = TRUE)
}

# ---- Multi-select ("A;B;C") helpers --------------------------------------------

#' Technology names are spelled inconsistently between survey years
#' (e.g. "Dynamodb" vs "DynamoDB", "Matlab" vs "MATLAB", "Bash/Shell" vs
#' "Bash/Shell (all shells)"). If left alone, one technology would look like two
#' and its trend line would break. This maps each variant to one name.
clean_tech <- function(x) {
  case_when(
    str_to_lower(x) == "dynamodb"           ~ "DynamoDB",
    str_to_lower(x) == "matlab"             ~ "MATLAB",
    str_to_lower(x) == "cobol"              ~ "COBOL",
    str_to_lower(x) == "lisp"               ~ "Lisp",
    str_to_lower(x) == "neo4j"              ~ "Neo4j",
    str_to_lower(x) %in% c("couch db", "couchdb") ~ "CouchDB",
    str_starts(x, "Bash/Shell")             ~ "Bash/Shell",
    x == "Firebase"                         ~ "Firebase Realtime Database",
    .default = x
  )
}

#' Turn a semicolon-separated multi-select column into one row per technology.
#' Rows where the respondent skipped the question (NA) are dropped here, so a
#' missing answer is never counted as if it were a technology.
split_multi <- function(data, col, ...) {
  data |>
    select(id, Year, ..., tech = {{ col }}) |>
    filter(!is.na(tech)) |>
    separate_longer_delim(tech, delim = ";") |>
    filter(tech != "") |>
    mutate(tech = clean_tech(tech)) |>
    distinct(id, tech, .keep_all = TRUE)   # a respondent counts once per technology
}

#' Popularity = share of respondents *who answered the question that year*.
#' Using shares (not raw counts) matters because the number of respondents
#' differs each year (73k in 2022 vs 89k in 2023).
tech_popularity <- function(data, col) {
  answered <- data |> filter(!is.na({{ col }})) |> count(Year, name = "n_answered")
  split_multi(data, {{ col }}) |>
    count(Year, tech, name = "n") |>
    left_join(answered, by = "Year") |>
    mutate(pct = n / n_answered)
}

#' Top-n technologies by pooled share across all three years.
top_techs <- function(popularity, n = 5) {
  popularity |>
    group_by(tech) |>
    summarise(total = sum(n), .groups = "drop") |>
    slice_max(total, n = n, with_ties = FALSE) |>
    pull(tech)
}

# ---- Statistics helpers ---------------------------------------------------------

#' Cramer's V: strength of association between two categorical variables (0-1).
cramers_v <- function(x, y) {
  tbl <- table(x, y)
  chi <- suppressWarnings(chisq.test(tbl)$statistic)
  unname(sqrt(chi / (sum(tbl) * (min(dim(tbl)) - 1))))
}

# ---- Plot theme and saving --------------------------------------------------------

theme_so <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title       = element_text(face = "bold", size = base_size + 3),
      plot.subtitle    = element_text(colour = "grey35", margin = margin(b = 8)),
      plot.caption     = element_text(colour = "grey45", size = base_size - 3),
      legend.position  = "bottom",
      panel.grid.minor = element_blank(),
      strip.text       = element_text(face = "bold")
    )
}

caption_so <- "Source: Stack Overflow Developer Survey 2021-2023 (top 10 countries by respondents)"

save_fig <- function(plot, name, width = 9, height = 5.5) {
  dir.create("figures", showWarnings = FALSE)
  ggsave(file.path("figures", paste0(name, ".png")), plot,
         width = width, height = height, dpi = 150, bg = "white")
  invisible(plot)
}

save_table <- function(df, name) {
  dir.create("outputs", showWarnings = FALSE)
  write_csv(df, file.path("outputs", paste0(name, ".csv")))
  invisible(df)
}

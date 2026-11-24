# ------------------------------------------------------------------------------
# 01_import_clean.R   |   Question 1: import, combine, standardise, handle NAs
# Input : data/raw/survey_2021.csv, survey_2022.csv, survey_2023.csv
# Output: `survey_raw`, `survey` (analysis-ready), `cleaning_log`, `top_countries`
# ------------------------------------------------------------------------------
source("R/helpers.R")

# ---- 1a. Import all three years and bind them into one data frame --------------
survey_files <- tibble(
  year = 2021:2023,
  path = file.path("data", "raw", sprintf("survey_%d.csv", year))
)

if (!all(file.exists(survey_files$path))) {
  stop("Survey CSVs not found in data/raw/. See data/README.md for download links.")
}

# col_select reads ONLY the nine required columns (the raw files are 80+ columns
# and up to 160 MB). Everything is read as text so we control every conversion.
read_survey <- function(path, year) {
  read_csv(path, col_select = all_of(keep_cols),
           col_types = cols(.default = col_character()),
           progress = FALSE) |>
    mutate(Year = year, .before = 1)        # indicator column for the survey year
}

survey_raw <- map2(survey_files$path, survey_files$year, read_survey) |>
  list_rbind() |>
  mutate(id = row_number(), .before = 1)    # unique respondent key used later

# ---- 1b. Standardise country names ---------------------------------------------
country_changes <- survey_raw |>
  filter(!is.na(Country)) |>
  distinct(Country) |>
  mutate(Standardised = standardise_country(Country)) |>
  filter(is.na(Standardised) | Country != Standardised) |>
  arrange(Standardised, Country)

survey_std <- survey_raw |>
  mutate(
    Country        = standardise_country(Country),
    Branch         = recode_branch(MainBranch),
    Education      = recode_education(EdLevel),
    AgeGroup       = clean_age(Age),
    YearsCodeNum   = years_code_to_numeric(YearsCode),
    ExperienceBand = experience_band(YearsCodeNum)
  )

# ---- 1c. Missing values and country subset ---------------------------------------
# Missing-value summary BEFORE any rows are removed (used in the report)
missing_summary <- survey_std |>
  select(all_of(keep_cols), Country_std = Country) |>
  summarise(across(everything(), ~ sum(is.na(.x)))) |>
  pivot_longer(everything(), names_to = "column", values_to = "n_missing") |>
  mutate(pct_missing = n_missing / nrow(survey_std)) |>
  arrange(desc(n_missing))

# Top 10 countries by number of respondents across all three years
top_countries <- survey_std |>
  filter(!is.na(Country)) |>
  count(Country, sort = TRUE, name = "n") |>
  slice_head(n = 10) |>
  mutate(pct_of_valid = n / sum(!is.na(survey_std$Country)))

# Decision rules:
#  * Country is the subsetting key, so rows without one cannot be kept.
#  * Every other column is kept as NA and excluded only from the specific
#    calculation that needs it (available-case analysis). This avoids throwing
#    away a respondent's valid language answers just because they skipped Age.
survey <- survey_std |>
  filter(Country %in% top_countries$Country)

cleaning_log <- tibble(
  step = c("Rows read (3 surveys combined)",
           "Rows with a missing / non-country value removed",
           "Rows outside the top 10 countries removed",
           "Rows in the analysis dataset"),
  rows = c(nrow(survey_raw),
           sum(is.na(survey_std$Country)),
           sum(!is.na(survey_std$Country)) - nrow(survey),
           nrow(survey))
)

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
saveRDS(survey, "data/processed/survey_clean.rds")
save_table(country_changes, "country_name_standardisation")
save_table(missing_summary, "missing_values_summary")
save_table(top_countries,   "top10_countries")
save_table(cleaning_log,    "cleaning_log")

message("01 complete: ", format(nrow(survey), big.mark = ","), " rows in analysis dataset")

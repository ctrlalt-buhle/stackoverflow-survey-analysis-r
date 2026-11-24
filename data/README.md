# Data

The raw survey files are **not** stored in this repository: together they are about 350 MB, and the 2022 and 2023 files are above GitHub's 100 MB file limit.

## How to get them

1. Download the public results for each year from Stack Overflow:
   - 2021: <https://survey.stackoverflow.co/2021/>
   - 2022: <https://survey.stackoverflow.co/2022/>
   - 2023: <https://survey.stackoverflow.co/2023/>
2. Save the main survey CSV of each year in `data/raw/` with exactly these names:
   - `survey_2021.csv`
   - `survey_2022.csv`
   - `survey_2023.csv`

The pipeline only needs these nine columns: `YearsCode`, `MainBranch`, `Country`, `EdLevel`, `LanguageHaveWorkedWith`, `LanguageWantToWorkWith`, `DatabaseHaveWorkedWith`, `DatabaseWantToWorkWith` and `Age`.

## Licence

The Stack Overflow Developer Survey data is published by Stack Overflow under the Open Database Licence (ODbL). Check the licence on each survey page before reusing or redistributing the data.

`data/processed/` is created by `R/01_import_clean.R` and is git-ignored. The small summary tables that the report uses are saved in `outputs/`, so the report can be re-rendered without the raw data.

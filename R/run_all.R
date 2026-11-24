# Run the whole pipeline from the project root:  Rscript R/run_all.R
source("R/01_import_clean.R")
source("R/02_branch_education.R")
source("R/03_databases_languages.R")
source("R/04_experience_languages.R")
message("Pipeline finished. Figures in figures/, tables in outputs/.")

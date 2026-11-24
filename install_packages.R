# Install the packages used by the project (run once)
pkgs <- c("tidyverse", "scales", "patchwork", "ggrepel", "knitr", "rmarkdown")
install.packages(setdiff(pkgs, rownames(installed.packages())))

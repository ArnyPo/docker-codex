# R package installation script
# Runs on first container start if packages not yet installed

lib <- file.path(Sys.getenv("HOME"), "R", "library")
.libPaths(c(lib, .libPaths()))

# Ensure library directory exists
dir.create(lib, recursive = TRUE, showWarnings = FALSE)

message("Installing CRAN packages...")
pkgs <- c("remotes", "tidyverse", "BiocManager", "leidenbase", "Seurat")
pkgs_missing <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
if (length(pkgs_missing)) install.packages(pkgs_missing, lib = lib)

message("Installing Bioconductor packages...")
BiocManager::install(
    c("ComplexHeatmap", "celda", "scDblFinder", "scRepertoire",
      "SpatialFeatureExperiment", "Voyager",
      # spatial
      "alabaster.base", "alabaster.sce", "alabaster.sfe"),
    lib = lib,
    update = FALSE,
    ask = FALSE
)

message("Installing GitHub packages...")
remotes::install_github("traversc/qs", lib = lib)
remotes::install_github("mojaveazure/seurat-disk", lib = lib)
remotes::install_github("immunogenomics/lisi", lib = lib)
remotes::install_github("pwwang/scplotter", lib = lib)

remotes::install_github("qfes/rdeck@*release", lib = lib)

message("R package installation complete.")

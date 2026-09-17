# ============================================================
# 01_load_clean_sites.R
# DAIT Pilot — Nagpur-Chandrapur Compression-Stratified MaxEnt Test
# Purpose: Load raw site table, clean column names, save derived copy
# ============================================================

library(here)
library(readxl)
library(dplyr)

# ---- Load raw site data ----
sites_raw <- read_excel(here("data", "raw", "site_data", "Nagpur Chandrapur Palaeolithic Site Raw Data.xlsx"))

# ---- Clean column names (locked, reproducible) ----
names(sites_raw) <- make.names(names(sites_raw))

# ---- Identify key columns by pattern (robust to header formatting quirks) ----
sitetype_col    <- names(sites_raw)[grep("^Site\\.Type", names(sites_raw))]
datasource_col  <- names(sites_raw)[grep("^Data\\.Source\\.Type", names(sites_raw))]
context_col     <- names(sites_raw)[grep("^Reported\\.Surface\\.Context", names(sites_raw))]

stopifnot(length(sitetype_col) == 1, length(datasource_col) == 1, length(context_col) == 1)

# ---- Basic cleaning ----
sites <- sites_raw %>%
  mutate(
    SiteType_clean    = tolower(trimws(.data[[sitetype_col]])),
    DataSource_clean  = tolower(trimws(.data[[datasource_col]])),
    RawMaterial_reported   = !is.na(Raw.Material) & Raw.Material != "Not Reported",
    Lithic_reported        = !is.na(Lithic.Assemblage) & Lithic.Assemblage != "Not Reported",
    Context_reported       = !is.na(.data[[context_col]]) & .data[[context_col]] != "Not Reported"
  )

# ---- Sanity checks ----
cat("N sites loaded:", nrow(sites), "\n")
cat("N with valid coordinates:", sum(!is.na(sites$Latitude) & !is.na(sites$Longitude)), "\n")
print(table(sites$SiteType_clean, useNA = "always"))
print(table(sites$DataSource_clean, useNA = "always"))

# ---- Save cleaned derived table ----
dir.create(here("data", "derived"), showWarnings = FALSE, recursive = TRUE)
write.csv(sites, here("data", "derived", "sites_cleaned.csv"), row.names = FALSE)

cat("\nSaved: data/derived/sites_cleaned.csv\n")
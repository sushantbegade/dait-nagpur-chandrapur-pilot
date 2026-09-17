# ============================================================
# 02_compression_proxy.R
# DAIT Pilot — Compression Proxy Construction (6-signal composite)
# Purpose: Build provisional CT score per site, assign 3-tier
#          Compression classification (Low/Moderate/High)
#
# NOTE ON METHOD: This dataset (Begade 2026/2027) was not built to
# measure DAIT's compression variable directly (IE/IR is not
# observable). This script constructs a documented, reproducible
# PROXY from independently available site-record fields, following
# the operationalisation logic of Chang (2004) discussed in the
# manuscript (Section 3). This proxy supports a provisional 3-tier
# collapse of DAIT's 5-class schema (Table 3), NOT a full 5-class
# stratification — reserved for the dedicated measurement paper
# ("Measuring Deep-Time Compression").
# ============================================================

library(here)
library(dplyr)

sites <- read.csv(here("data", "derived", "sites_cleaned.csv"), stringsAsFactors = FALSE)

# ---- Six signals contributing to CT_raw ----
# 1. Depositional disturbance (Site Type) — 0 (least) to 3 (most disturbed)
# 2. Locational precision — 0 (field-verified) to 2 (GIS-estimated)
# 3. Recovery method — 0 (excavation) / 1 (survey)
# 4-6. Reporting completeness (raw material, lithic assemblage, surface context)
#      — 0 if reported, 1 if not (absence of reporting treated as a weak
#        observability signal, not equated with absence of compression itself;
#        stated explicitly as a limitation in Section 6)

sites <- sites %>%
  mutate(
    disturbance_score = case_when(
      grepl("insitu", SiteType_clean) ~ 0,
      grepl("factory", SiteType_clean) ~ 1,
      grepl("lake", SiteType_clean) ~ 1,
      grepl("open-air|open air", SiteType_clean) ~ 2,
      grepl("riverbed", SiteType_clean) ~ 3,
      TRUE ~ NA_real_
    ),
    precision_score = case_when(
      grepl("Field Verified", Location.Precision) ~ 0,
      grepl("Reported By Referenced Author", Location.Precision) ~ 1,
      grepl("GIS Map Based", Location.Precision) ~ 2,
      TRUE ~ NA_real_
    ),
    method_score = if_else(grepl("excavation", DataSource_clean), 0, 1),
    rawmat_score  = if_else(RawMaterial_reported, 0, 1),
    lithic_score  = if_else(Lithic_reported, 0, 1),
    context_score = if_else(Context_reported, 0, 1),
    
    CT_raw = disturbance_score + precision_score + method_score +
      rawmat_score + lithic_score + context_score
  )

cat("CT_raw distribution:\n")
print(table(sites$CT_raw, useNA = "always"))

# ---- Normalize to [0,1] ----
sites$CT <- (sites$CT_raw - min(sites$CT_raw, na.rm = TRUE)) /
  (max(sites$CT_raw, na.rm = TRUE) - min(sites$CT_raw, na.rm = TRUE))

# ---- Tertile split (quantile-based, documented cutoffs) ----
q <- quantile(sites$CT, probs = c(1/3, 2/3), na.rm = TRUE)
cat("\nTertile cutoffs (normalized CT scale):\n")
print(q)

sites <- sites %>%
  mutate(CompressionTier = case_when(
    is.na(CT) ~ NA_character_,
    CT <= q[1] ~ "Low",
    CT <= q[2] ~ "Moderate",
    TRUE ~ "High"
  ))

cat("\nCompression Tier distribution:\n")
print(table(sites$CompressionTier, useNA = "always"))

# ---- Save ----
write.csv(sites, here("data", "derived", "sites_with_compression.csv"), row.names = FALSE)

# ---- Save methods documentation as text (for Section 6 + SI) ----
methods_note <- sprintf(
  "Compression proxy (CT_raw) range: %d-%d\nNormalized tertile cutoffs: Low <= %.4f, Moderate <= %.4f, High > %.4f\nN per tier: %s",
  min(sites$CT_raw, na.rm = TRUE), max(sites$CT_raw, na.rm = TRUE),
  q[1], q[2], q[2],
  paste(names(table(sites$CompressionTier)), table(sites$CompressionTier), sep = "=", collapse = ", ")
)
writeLines(methods_note, here("outputs", "tables", "compression_proxy_methods.txt"))
cat("\nSaved: data/derived/sites_with_compression.csv\n")
cat("Saved: outputs/tables/compression_proxy_methods.txt\n")
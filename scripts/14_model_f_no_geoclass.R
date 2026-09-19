# ============================================================
# 14_model_f_no_geoclass.R
# DAIT Pilot — Overlap-sensitivity test: does the Cop-suitability
# correlation survive removing geo_class, the covariate most
# conceptually related to Cop's disturbance_score component?
# ============================================================

library(here); library(dplyr); library(maxnet)
set.seed(42)

sites <- read.csv(here("data","derived","sites_cleaned.csv"), stringsAsFactors = FALSE)
sites <- sites %>%
  mutate(
    disturbance_score = case_when(
      grepl("insitu", SiteType_clean) ~ 0, grepl("factory", SiteType_clean) ~ 1,
      grepl("lake", SiteType_clean) ~ 1, grepl("open-air|open air", SiteType_clean) ~ 2,
      grepl("riverbed", SiteType_clean) ~ 3, TRUE ~ NA_real_),
    precision_score = case_when(
      grepl("Field Verified", Location.Precision) ~ 0,
      grepl("Reported By Referenced Author", Location.Precision) ~ 1,
      grepl("GIS Map Based", Location.Precision) ~ 2, TRUE ~ NA_real_),
    method_score = if_else(grepl("excavation", DataSource_clean), 0, 1),
    rawmat_score  = if_else(RawMaterial_reported, 0, 1),
    lithic_score  = if_else(Lithic_reported, 0, 1),
    context_score = if_else(Context_reported, 0, 1),
    Cop_raw = disturbance_score + precision_score + method_score + rawmat_score + lithic_score + context_score
  )
sites$Cop <- (sites$Cop_raw - min(sites$Cop_raw, na.rm=TRUE)) / (max(sites$Cop_raw, na.rm=TRUE) - min(sites$Cop_raw, na.rm=TRUE))

# ---- Covariates WITHOUT geo_class ----
covariate_cols_noGeo <- c("elevation","slope","tri","dist_river","dist_water","lith_class")

pres_vals <- read.csv(here("data","derived","presence_covariates_finegrid.csv"), stringsAsFactors = FALSE)
bg_vals   <- read.csv(here("data","derived","background_covariates_finegrid.csv"), stringsAsFactors = FALSE)
pres_vals$lith_class <- as.factor(pres_vals$lith_class)
bg_vals$lith_class <- as.factor(bg_vals$lith_class)

pres_vals <- pres_vals %>% left_join(sites %>% select(Site.ID, Cop), by = "Site.ID")

pres_clean <- pres_vals %>% filter(complete.cases(select(., all_of(covariate_cols_noGeo))), !is.na(Cop))
bg_clean <- bg_vals %>% filter(complete.cases(select(., all_of(covariate_cols_noGeo))))

cat("Model F - N presence:", nrow(pres_clean), "| N background:", nrow(bg_clean), "\n")

model_data <- bind_rows(
  pres_clean %>% select(all_of(covariate_cols_noGeo)) %>% mutate(pa = 1),
  bg_clean %>% select(all_of(covariate_cols_noGeo)) %>% mutate(pa = 0)
)
mod_F <- maxnet(p = model_data$pa, data = model_data %>% select(-pa))

preds_F <- predict(mod_F, pres_clean %>% select(all_of(covariate_cols_noGeo)), type = "logistic")
cor_F <- cor.test(as.vector(preds_F), pres_clean$Cop, method = "spearman")

cat("\n=== MODEL F: geo_class EXCLUDED ===\n")
cat("Spearman rho =", round(cor_F$estimate, 3), " p =", round(cor_F$p.value, 4), " N =", nrow(pres_clean), "\n")

cat("\n=== COMPARISON TO MODEL A (geo_class included, from script 11) ===\n")
cat("Model A: rho = -0.209, p = 0.0053, N = 181\n")
cat("Model F: rho =", round(cor_F$estimate, 3), ", p =", round(cor_F$p.value, 4), ", N =", nrow(pres_clean), "\n")

saveRDS(list(model = mod_F, cor_test = cor_F), here("data","derived","model_F_results.rds"))
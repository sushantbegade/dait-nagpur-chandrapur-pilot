library(here); library(dplyr); library(maxnet); library(pROC)
set.seed(42)

sites <- read.csv(here("data","derived","sites_cleaned.csv"), stringsAsFactors = FALSE)
covs_fine <- terra::rast(here("data","derived","covariate_stack_finegrid.tif"))

# ---- Rebuild component scores (from script 02) ----
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
    context_score = if_else(Context_reported, 0, 1)
  )

# ---- Define five Cop model variants ----
cop_variants <- list(
  A_full           = c("disturbance_score","precision_score","method_score","rawmat_score","lithic_score","context_score"),
  B_preservation   = c("disturbance_score","precision_score"),
  C_no_method      = c("disturbance_score","precision_score","rawmat_score","lithic_score","context_score"),
  D_no_location    = c("disturbance_score","method_score","rawmat_score","lithic_score","context_score"),
  E_no_documentation = c("disturbance_score","precision_score","method_score")
)

covariate_cols <- c("elevation","slope","tri","dist_river","dist_water","geo_class","lith_class")
pres_vals <- read.csv(here("data","derived","presence_covariates_finegrid.csv"), stringsAsFactors = FALSE)
bg_vals   <- read.csv(here("data","derived","background_covariates_finegrid.csv"), stringsAsFactors = FALSE)
pres_vals$geo_class <- as.factor(pres_vals$geo_class); pres_vals$lith_class <- as.factor(pres_vals$lith_class)
bg_vals$geo_class <- as.factor(bg_vals$geo_class); bg_vals$lith_class <- as.factor(bg_vals$lith_class)

results_all <- list()

for (model_name in names(cop_variants)) {
  vars <- cop_variants[[model_name]]
  cat("\n=== Model:", model_name, "( variables:", paste(vars, collapse=", "), ") ===\n")
  
  s <- sites
  s$Cop_raw <- rowSums(s[, vars], na.rm = FALSE)
  s$Cop <- (s$Cop_raw - min(s$Cop_raw, na.rm=TRUE)) / (max(s$Cop_raw, na.rm=TRUE) - min(s$Cop_raw, na.rm=TRUE))
  q <- quantile(s$Cop, probs = c(1/3, 2/3), na.rm = TRUE)
  s$Tier <- case_when(is.na(s$Cop) ~ NA_character_, s$Cop <= q[1] ~ "Low", s$Cop <= q[2] ~ "Moderate", TRUE ~ "High")
  
  pres_m <- pres_vals %>% left_join(s %>% select(Site.ID, Cop, Tier), by = "Site.ID")
  pres_clean <- pres_m %>% filter(complete.cases(select(., all_of(covariate_cols))), !is.na(Tier))
  bg_clean <- bg_vals %>% filter(complete.cases(select(., all_of(covariate_cols))))
  
  model_data <- bind_rows(pres_clean %>% select(all_of(covariate_cols)) %>% mutate(pa=1),
                          bg_clean %>% select(all_of(covariate_cols)) %>% mutate(pa=0))
  mod <- maxnet(p = model_data$pa, data = model_data %>% select(-pa))
  
  # Continuous Cop regression: does model prediction correlate with Cop directly?
  pres_preds <- predict(mod, pres_clean %>% select(all_of(covariate_cols)), type="logistic")
  cont_cor <- cor.test(as.vector(pres_preds), pres_clean$Cop, method = "spearman")
  cat("Continuous Cop vs. predicted suitability, Spearman rho =", round(cont_cor$estimate,3),
      "p =", round(cont_cor$p.value,4), "\n")
  
  tier_aucs <- list()
  for (tier in c("Low","Moderate","High")) {
    tp <- pres_clean %>% filter(Tier == tier)
    if (nrow(tp) < 5) next
    n_bg <- min(nrow(bg_clean), nrow(tp)*5)
    tb <- bg_clean %>% sample_n(n_bg)
    test_data <- bind_rows(tp %>% select(all_of(covariate_cols)), tb %>% select(all_of(covariate_cols)))
    labels <- c(rep(1,nrow(tp)), rep(0,n_bg))
    preds <- predict(mod, test_data, type="logistic")
    auc_val <- auc(roc(labels, as.vector(preds), quiet=TRUE))
    cat(sprintf("  Tier %s: N=%d, AUC=%.3f\n", tier, nrow(tp), as.numeric(auc_val)))
    tier_aucs[[tier]] <- as.numeric(auc_val)
  }
  results_all[[model_name]] <- list(spearman_rho = cont_cor$estimate, spearman_p = cont_cor$p.value, tier_aucs = tier_aucs)
}

cat("\n\n=== SUMMARY ACROSS ALL FIVE MODELS ===\n")
for (m in names(results_all)) {
  cat(m, ": rho=", round(results_all[[m]]$spearman_rho,3), " AUCs=", 
      paste(names(results_all[[m]]$tier_aucs), round(unlist(results_all[[m]]$tier_aucs),3), sep="=", collapse=", "), "\n")
}
saveRDS(results_all, here("data","derived","sensitivity_models_results.rds"))
# ============================================================
# 06_stratified_evaluation.R
# DAIT Pilot — Core Test: MaxEnt accuracy stratified by
# Compression Tier (Cluster I prediction: Model Accuracy ∝ O = 1-C)
# ============================================================

library(here)
library(maxnet)
library(dplyr)
library(pROC)

set.seed(42)

mod <- readRDS(here("data", "derived", "maxent_model.rds"))
pres_vals <- read.csv(here("data", "derived", "presence_covariates.csv"), stringsAsFactors = FALSE)
bg_vals <- read.csv(here("data", "derived", "background_covariates.csv"), stringsAsFactors = FALSE)

pres_vals$geo_class  <- as.factor(pres_vals$geo_class)
pres_vals$lith_class <- as.factor(pres_vals$lith_class)
bg_vals$geo_class  <- as.factor(bg_vals$geo_class)
bg_vals$lith_class <- as.factor(bg_vals$lith_class)

pres_clean <- pres_vals %>% filter(complete.cases(select(., elevation, slope, tri, dist_river, dist_water, geo_class, lith_class)))
bg_clean <- bg_vals %>% filter(complete.cases(select(., elevation, slope, tri, dist_river, dist_water, geo_class, lith_class)))

cat("Usable presence points:", nrow(pres_clean), "\n")
cat("Usable background points:", nrow(bg_clean), "\n")

# ---- Overall model AUC (all sites, sanity check baseline) ----
covariate_cols <- c("elevation","slope","tri","dist_river","dist_water","geo_class","lith_class")

all_test <- bind_rows(
  pres_clean %>% select(all_of(covariate_cols)),
  bg_clean %>% select(all_of(covariate_cols))
)
all_labels <- c(rep(1, nrow(pres_clean)), rep(0, nrow(bg_clean)))
all_preds <- predict(mod, all_test, type = "logistic")
overall_auc <- auc(roc(all_labels, as.vector(all_preds), quiet = TRUE))
cat("\nOVERALL AUC (all sites, not stratified):", round(as.numeric(overall_auc), 3), "\n")

# ---- Stratified AUC by Compression Tier ----
cat("\n=== STRATIFIED EVALUATION BY COMPRESSION TIER ===\n")

results <- data.frame(Tier = character(), N_presence = integer(),
                      N_background_used = integer(), AUC = numeric(),
                      AUC_CI_low = numeric(), AUC_CI_high = numeric())

for (tier in c("Low", "Moderate", "High")) {
  tier_pres <- pres_clean %>% filter(CompressionTier == tier)
  n_pres <- nrow(tier_pres)
  
  if (n_pres < 5) {
    cat(sprintf("\nTier '%s': N too small (%d), skipping.\n", tier, n_pres))
    next
  }
  
  n_bg_use <- min(nrow(bg_clean), n_pres * 5)
  tier_bg <- bg_clean %>% sample_n(n_bg_use)
  
  test_data <- bind_rows(
    tier_pres %>% select(all_of(covariate_cols)),
    tier_bg %>% select(all_of(covariate_cols))
  )
  test_labels <- c(rep(1, n_pres), rep(0, n_bg_use))
  
  preds <- predict(mod, test_data, type = "logistic")
  roc_obj <- roc(test_labels, as.vector(preds), quiet = TRUE)
  auc_val <- auc(roc_obj)
  ci_val <- ci.auc(roc_obj)
  
  cat(sprintf("\nTier '%s': N_presence=%d, N_background=%d, AUC=%.3f (95%% CI: %.3f-%.3f)\n",
              tier, n_pres, n_bg_use, as.numeric(auc_val), ci_val[1], ci_val[3]))
  
  results <- rbind(results, data.frame(
    Tier = tier, N_presence = n_pres, N_background_used = n_bg_use,
    AUC = round(as.numeric(auc_val), 3),
    AUC_CI_low = round(ci_val[1], 3), AUC_CI_high = round(ci_val[3], 3)
  ))
}

cat("\n=== SUMMARY TABLE ===\n")
print(results)

# ---- DAIT prediction check ----
cat("\n=== DAIT PREDICTION CHECK (Equation 17: Accuracy ∝ Observability = 1-C) ===\n")
cat("Prediction: AUC(Low) > AUC(Moderate) > AUC(High)\n")
if (nrow(results) == 3) {
  low_auc <- results$AUC[results$Tier == "Low"]
  mod_auc <- results$AUC[results$Tier == "Moderate"]
  high_auc <- results$AUC[results$Tier == "High"]
  cat(sprintf("Observed: Low=%.3f, Moderate=%.3f, High=%.3f\n", low_auc, mod_auc, high_auc))
  cat("Monotonic decline observed:", (low_auc > mod_auc) && (mod_auc > high_auc), "\n")
}

# ---- Save results ----
write.csv(results, here("outputs", "tables", "stratified_auc_results.csv"), row.names = FALSE)
cat("\nSaved: outputs/tables/stratified_auc_results.csv\n")
# ============================================================
# 09_finegrid_maxent_and_evaluation.R
# DAIT Pilot — Sensitivity check: MaxEnt fit + stratified AUC
# at fine-grid (~150m) resolution
# ============================================================

library(here); library(maxnet); library(dplyr); library(pROC)
set.seed(42)

model_data <- read.csv(here("data", "derived", "model_data_finegrid.csv"), stringsAsFactors = FALSE)
model_data$geo_class  <- as.factor(model_data$geo_class)
model_data$lith_class <- as.factor(model_data$lith_class)

cat("Presence/background counts:\n"); print(table(model_data$pa))

mod <- maxnet(p = model_data$pa, data = model_data %>% select(-pa))
cat("\nNon-zero coefficients:\n")
print(mod$betas[mod$betas != 0])

saveRDS(mod, here("data", "derived", "maxent_model_finegrid.rds"))

# ---- Stratified evaluation ----
pres_vals <- read.csv(here("data", "derived", "presence_covariates_finegrid.csv"), stringsAsFactors = FALSE)
bg_vals   <- read.csv(here("data", "derived", "background_covariates_finegrid.csv"), stringsAsFactors = FALSE)
pres_vals$geo_class  <- as.factor(pres_vals$geo_class)
pres_vals$lith_class <- as.factor(pres_vals$lith_class)
bg_vals$geo_class  <- as.factor(bg_vals$geo_class)
bg_vals$lith_class <- as.factor(bg_vals$lith_class)

covariate_cols <- c("elevation","slope","tri","dist_river","dist_water","geo_class","lith_class")
pres_clean <- pres_vals %>% filter(complete.cases(select(., all_of(covariate_cols))))
bg_clean   <- bg_vals %>% filter(complete.cases(select(., all_of(covariate_cols))))

all_test <- bind_rows(pres_clean %>% select(all_of(covariate_cols)), bg_clean %>% select(all_of(covariate_cols)))
all_labels <- c(rep(1, nrow(pres_clean)), rep(0, nrow(bg_clean)))
all_preds <- predict(mod, all_test, type = "logistic")
overall_auc <- auc(roc(all_labels, as.vector(all_preds), quiet = TRUE))
cat("\nOVERALL AUC (fine grid):", round(as.numeric(overall_auc), 3), "\n")

cat("\n=== STRATIFIED EVALUATION (FINE GRID) ===\n")
results <- data.frame(Tier = character(), N_presence = integer(),
                      N_background_used = integer(), AUC = numeric(),
                      AUC_CI_low = numeric(), AUC_CI_high = numeric())

for (tier in c("Low", "Moderate", "High")) {
  tier_pres <- pres_clean %>% filter(CompressionTier == tier)
  n_pres <- nrow(tier_pres)
  if (n_pres < 5) { cat(sprintf("Tier '%s': N too small, skipping.\n", tier)); next }
  
  n_bg_use <- min(nrow(bg_clean), n_pres * 5)
  tier_bg <- bg_clean %>% sample_n(n_bg_use)
  
  test_data <- bind_rows(tier_pres %>% select(all_of(covariate_cols)), tier_bg %>% select(all_of(covariate_cols)))
  test_labels <- c(rep(1, n_pres), rep(0, n_bg_use))
  preds <- predict(mod, test_data, type = "logistic")
  roc_obj <- roc(test_labels, as.vector(preds), quiet = TRUE)
  auc_val <- auc(roc_obj); ci_val <- ci.auc(roc_obj)
  
  cat(sprintf("Tier '%s': N=%d, AUC=%.3f (95%% CI: %.3f-%.3f)\n",
              tier, n_pres, as.numeric(auc_val), ci_val[1], ci_val[3]))
  
  results <- rbind(results, data.frame(Tier = tier, N_presence = n_pres,
                                       N_background_used = n_bg_use, AUC = round(as.numeric(auc_val),3),
                                       AUC_CI_low = round(ci_val[1],3), AUC_CI_high = round(ci_val[3],3)))
}

cat("\n=== SUMMARY (FINE GRID) ===\n"); print(results)

cat("\n=== DAIT PREDICTION CHECK ===\n")
if (nrow(results) == 3) {
  low <- results$AUC[results$Tier=="Low"]; mod_ <- results$AUC[results$Tier=="Moderate"]; high <- results$AUC[results$Tier=="High"]
  cat(sprintf("Low=%.3f, Moderate=%.3f, High=%.3f | Monotonic decline: %s\n",
              low, mod_, high, (low > mod_) && (mod_ > high)))
}

write.csv(results, here("outputs", "tables", "stratified_auc_results_finegrid.csv"), row.names = FALSE)
cat("\nSaved: outputs/tables/stratified_auc_results_finegrid.csv\n")
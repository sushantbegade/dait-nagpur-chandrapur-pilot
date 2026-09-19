# ============================================================
# 13_calibration.R
# DAIT Pilot — Calibration metrics (Brier score, calibration
# slope/intercept) supplementing AUC-based evaluation.
# ============================================================

library(here); library(dplyr); library(maxnet)   # <-- added maxnet

mod <- readRDS(here("data","derived","maxent_model_finegrid.rds"))
pres_vals <- read.csv(here("data","derived","presence_covariates_finegrid.csv"))
bg_vals <- read.csv(here("data","derived","background_covariates_finegrid.csv"))
pres_vals$geo_class <- as.factor(pres_vals$geo_class)
pres_vals$lith_class <- as.factor(pres_vals$lith_class)
bg_vals$geo_class <- as.factor(bg_vals$geo_class)
bg_vals$lith_class <- as.factor(bg_vals$lith_class)
covariate_cols <- c("elevation","slope","tri","dist_river","dist_water","geo_class","lith_class")

set.seed(42)

calib_results <- data.frame()

for (tier in c("Low","Moderate","High")) {
  
  tp <- pres_vals %>% filter(CompressionTier == tier, complete.cases(select(., all_of(covariate_cols))))
  n_bg <- min(nrow(bg_vals), nrow(tp) * 5)
  tb <- bg_vals %>% sample_n(n_bg) %>% filter(complete.cases(select(., all_of(covariate_cols))))
  
  # Build test set and labels TOGETHER, from the same filtered frames
  test_data <- bind_rows(
    tp %>% select(all_of(covariate_cols)) %>% mutate(pa = 1),
    tb %>% select(all_of(covariate_cols)) %>% mutate(pa = 0)
  )
  test_data <- test_data[complete.cases(test_data), ]   # final safety filter
  
  labels <- test_data$pa
  preds <- as.vector(predict(mod, test_data %>% select(-pa), type = "logistic"))
  
  cat("Tier", tier, "- N test rows:", length(labels), "| N preds:", length(preds), "\n")
  
  brier <- mean((preds - labels)^2)
  
  logit_p <- log(preds / (1 - preds))
  finite_idx <- is.finite(logit_p)
  cal_mod <- glm(labels[finite_idx] ~ logit_p[finite_idx], family = binomial)
  
  cat(sprintf("Tier %s: Brier=%.4f, Cal.Intercept=%.3f, Cal.Slope=%.3f\n\n",
              tier, brier, coef(cal_mod)[1], coef(cal_mod)[2]))
  
  calib_results <- rbind(calib_results, data.frame(
    Tier = tier, N = length(labels), Brier = round(brier, 4),
    Cal_Intercept = round(coef(cal_mod)[1], 3), Cal_Slope = round(coef(cal_mod)[2], 3)
  ))
}

cat("=== CALIBRATION SUMMARY ===\n")
print(calib_results)
write.csv(calib_results, here("outputs","tables","calibration_results.csv"), row.names = FALSE)
cat("\nSaved: outputs/tables/calibration_results.csv\n")
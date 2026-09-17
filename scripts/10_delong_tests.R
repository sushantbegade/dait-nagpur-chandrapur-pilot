library(pROC)

# Rebuild ROC objects for pairwise DeLong test (proper way to compare AUCs)
get_roc <- function(tier, pres_clean, bg_clean, mod, covariate_cols) {
  tier_pres <- pres_clean %>% filter(CompressionTier == tier)
  n_bg_use <- min(nrow(bg_clean), nrow(tier_pres) * 5)
  set.seed(42)
  tier_bg <- bg_clean %>% sample_n(n_bg_use)
  test_data <- bind_rows(tier_pres %>% select(all_of(covariate_cols)), tier_bg %>% select(all_of(covariate_cols)))
  labels <- c(rep(1, nrow(tier_pres)), rep(0, n_bg_use))
  preds <- predict(mod, test_data, type = "logistic")
  roc(labels, as.vector(preds), quiet = TRUE)
}

roc_low <- get_roc("Low", pres_clean, bg_clean, mod, covariate_cols)
roc_mod <- get_roc("Moderate", pres_clean, bg_clean, mod, covariate_cols)
roc_high <- get_roc("High", pres_clean, bg_clean, mod, covariate_cols)

cat("DeLong test, Low vs High AUC:\n")
print(roc.test(roc_low, roc_high, method = "delong"))

cat("\nDeLong test, Low vs Moderate AUC:\n")
print(roc.test(roc_low, roc_mod, method = "delong"))

cat("\nDeLong test, Moderate vs High AUC:\n")
print(roc.test(roc_mod, roc_high, method = "delong"))
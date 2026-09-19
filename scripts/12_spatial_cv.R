# ============================================================
# 12_spatial_cv.R
# DAIT Pilot — Spatial-block cross-validation
# Tests whether the compression-stratified accuracy gradient
# survives spatially independent validation (addresses risk of
# spatial leakage from randomly sampled background points near
# clustered presence sites).
# ============================================================

library(here); library(terra); library(dplyr); library(blockCV); library(maxnet); library(pROC)
set.seed(42)

sites <- read.csv(here("data","derived","sites_with_compression.csv"))
covs <- rast(here("data","derived","covariate_stack_finegrid.tif"))
pts <- vect(sites %>% filter(!is.na(CompressionTier)), geom=c("Longitude","Latitude"), crs="EPSG:4326")
pts <- project(pts, crs(covs))

# ---- Spatial blocks (~10km) ----
sb <- cv_spatial(x = pts, column = "CompressionTier", k = 5, size = 10000, selection = "random")

cat("Fold sizes:\n"); print(table(sb$folds_ids))

# ---- Load covariate extracts ----
pres_vals <- read.csv(here("data","derived","presence_covariates_finegrid.csv"))
pres_vals$geo_class <- as.factor(pres_vals$geo_class)
pres_vals$lith_class <- as.factor(pres_vals$lith_class)
bg_vals <- read.csv(here("data","derived","background_covariates_finegrid.csv"))
bg_vals$geo_class <- as.factor(bg_vals$geo_class)
bg_vals$lith_class <- as.factor(bg_vals$lith_class)
covariate_cols <- c("elevation","slope","tri","dist_river","dist_water","geo_class","lith_class")

# ---- Align fold assignment to presence rows ----
# pts was built from sites (filtered to non-NA CompressionTier); pres_vals is a
# separate extraction with its own row order, so join on Site.ID to attach folds.
sites_with_fold <- sites %>%
  filter(!is.na(CompressionTier)) %>%
  mutate(fold = sb$folds_ids)

pres_vals <- pres_vals %>%
  left_join(sites_with_fold %>% select(Site.ID, fold), by = "Site.ID")

cat("\nPresence rows with fold assigned:", sum(!is.na(pres_vals$fold)), "of", nrow(pres_vals), "\n")

# ---- Cross-validation loop ----
fold_results <- data.frame()

for (k in 1:5) {
  
  train_pres <- pres_vals %>% filter(fold != k, complete.cases(select(., all_of(covariate_cols))))
  test_pres  <- pres_vals %>% filter(fold == k, complete.cases(select(., all_of(covariate_cols))))
  
  if (nrow(test_pres) < 3 | nrow(train_pres) < 10) {
    cat("Fold", k, "- skipped (insufficient N)\n")
    next
  }
  
  # ---- Training data: presence + background, NA-filtered ----
  train_bg <- bg_vals %>% sample_n(min(nrow(bg_vals), nrow(train_pres) * 5))
  train_data <- bind_rows(
    train_pres %>% select(all_of(covariate_cols)) %>% mutate(pa = 1),
    train_bg   %>% select(all_of(covariate_cols)) %>% mutate(pa = 0)
  )
  train_data <- train_data[complete.cases(train_data), ]
  
  mod <- maxnet(p = train_data$pa, data = train_data %>% select(-pa))
  
  # ---- Test data: held-out spatial fold + fresh background, NA-filtered ----
  test_bg <- bg_vals %>% sample_n(min(nrow(bg_vals), nrow(test_pres) * 5))
  test_full <- bind_rows(
    test_pres %>% select(all_of(covariate_cols)) %>% mutate(pa = 1),
    test_bg   %>% select(all_of(covariate_cols)) %>% mutate(pa = 0)
  )
  test_full <- test_full[complete.cases(test_full), ]
  
  preds <- predict(mod, test_full %>% select(-pa), type = "logistic")
  auc_val <- tryCatch(
    as.numeric(auc(roc(test_full$pa, as.vector(preds), quiet = TRUE))),
    error = function(e) NA
  )
  
  cat(sprintf("Fold %d - Train N=%d, Test N presence=%d, AUC=%.3f\n",
              k, nrow(train_pres), nrow(test_pres), auc_val))
  
  fold_results <- rbind(fold_results, data.frame(
    fold = k, n_train = nrow(train_pres), n_test = nrow(test_pres), auc = auc_val
  ))
}

cat("\n=== SPATIAL CROSS-VALIDATION SUMMARY ===\n")
print(fold_results)
cat("\nMean spatial-CV AUC:", round(mean(fold_results$auc, na.rm = TRUE), 3),
    "| SD:", round(sd(fold_results$auc, na.rm = TRUE), 3), "\n")

write.csv(fold_results, here("outputs", "tables", "spatial_cv_results.csv"), row.names = FALSE)
cat("\nSaved: outputs/tables/spatial_cv_results.csv\n")
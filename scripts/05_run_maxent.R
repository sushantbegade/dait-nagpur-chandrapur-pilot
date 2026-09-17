# ============================================================
# 05_run_maxent.R
# DAIT Pilot — Fit MaxEnt model (maxnet, no Java dependency)
# ============================================================

library(here)
library(maxnet)
library(dplyr)

model_data <- read.csv(here("data", "derived", "model_data.csv"), stringsAsFactors = FALSE)

# ---- Convert categorical covariates to factors ----
model_data$geo_class  <- as.factor(model_data$geo_class)
model_data$lith_class <- as.factor(model_data$lith_class)

cat("Model data summary:\n")
str(model_data)
cat("\nPresence/background counts:\n")
print(table(model_data$pa))

# ---- Fit MaxEnt (maxnet) ----
predictors <- model_data %>% select(-pa)
response <- model_data$pa

mod <- maxnet(p = response, data = predictors)

cat("\nMaxEnt model fitted.\n")
print(mod)

# ---- Save model + model data ----
saveRDS(mod, here("data", "derived", "maxent_model.rds"))
cat("\nSaved: data/derived/maxent_model.rds\n")

# ---- Variable importance (permutation-style, basic check) ----
cat("\nCoefficients (non-zero terms):\n")
print(mod$betas[mod$betas != 0])
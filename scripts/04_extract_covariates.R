# ============================================================
# 04_extract_covariates.R
# DAIT Pilot — Extract covariates at presence + background points
# ============================================================

library(here)
library(terra)
library(dplyr)

set.seed(42)  # reproducibility for background sampling

# ---- Load covariate stack + site data ----
covs <- rast(here("data", "derived", "covariate_stack.tif"))
sites <- read.csv(here("data", "derived", "sites_with_compression.csv"))

# ---- Presence points ----
pres_pts <- vect(sites, geom = c("Longitude", "Latitude"), crs = "EPSG:4326")
pres_pts <- project(pres_pts, crs(covs))

pres_vals <- extract(covs, pres_pts, ID = FALSE)
pres_vals$Site.ID <- sites$Site.ID
pres_vals$CompressionTier <- sites$CompressionTier
pres_vals$pa <- 1

cat("Presence points extracted:", nrow(pres_vals), "\n")
cat("Missing values per column:\n")
print(colSums(is.na(pres_vals)))

# ---- Background points (random, within covariate extent, excluding NA cells) ----
n_bg <- 1000
bg_pts <- spatSample(covs[[1]], size = n_bg, method = "random", na.rm = TRUE, as.points = TRUE)
bg_vals <- extract(covs, bg_pts, ID = FALSE)
bg_vals$pa <- 0

cat("\nBackground points extracted:", nrow(bg_vals), "\n")
cat("Missing values per column:\n")
print(colSums(is.na(bg_vals)))

# ---- Combine for full modelling dataset ----
model_data <- bind_rows(
  pres_vals %>% select(-Site.ID, -CompressionTier),
  bg_vals
)
model_data <- model_data[complete.cases(model_data), ]

cat("\nFinal modelling dataset rows (presence + background, complete cases):", nrow(model_data), "\n")
cat("Presence rows retained:", sum(model_data$pa == 1), "of", sum(pres_vals$pa == 1), "\n")

# ---- Save all pieces ----
write.csv(pres_vals, here("data", "derived", "presence_covariates.csv"), row.names = FALSE)
write.csv(bg_vals, here("data", "derived", "background_covariates.csv"), row.names = FALSE)
write.csv(model_data, here("data", "derived", "model_data.csv"), row.names = FALSE)

cat("\nSaved: presence_covariates.csv, background_covariates.csv, model_data.csv\n")
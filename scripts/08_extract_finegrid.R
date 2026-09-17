library(here); library(terra); library(dplyr)
set.seed(42)

covs <- rast(here("data", "derived", "covariate_stack_finegrid.tif"))
sites <- read.csv(here("data", "derived", "sites_with_compression.csv"))

pres_pts <- vect(sites, geom = c("Longitude", "Latitude"), crs = "EPSG:4326")
pres_pts <- project(pres_pts, crs(covs))

pres_vals <- extract(covs, pres_pts, ID = FALSE)
pres_vals$Site.ID <- sites$Site.ID
pres_vals$CompressionTier <- sites$CompressionTier
pres_vals$pa <- 1

cat("Presence extracted:", nrow(pres_vals), "| Missing per col:\n")
print(colSums(is.na(pres_vals)))

n_bg <- 1000
bg_pts <- spatSample(covs[[1]], size = n_bg, method = "random", na.rm = TRUE, as.points = TRUE)
bg_vals <- extract(covs, bg_pts, ID = FALSE)
bg_vals$pa <- 0

cat("\nBackground extracted:", nrow(bg_vals), "| Missing per col:\n")
print(colSums(is.na(bg_vals)))

model_data <- bind_rows(
  pres_vals %>% select(-Site.ID, -CompressionTier),
  bg_vals
)
model_data <- model_data[complete.cases(model_data), ]
cat("\nModel data rows:", nrow(model_data), "| Presence retained:", sum(model_data$pa==1), "of", sum(pres_vals$pa==1), "\n")

write.csv(pres_vals, here("data", "derived", "presence_covariates_finegrid.csv"), row.names = FALSE)
write.csv(bg_vals, here("data", "derived", "background_covariates_finegrid.csv"), row.names = FALSE)
write.csv(model_data, here("data", "derived", "model_data_finegrid.csv"), row.names = FALSE)
cat("\nSaved fine-grid extraction files.\n")
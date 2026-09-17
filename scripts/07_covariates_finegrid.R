# ============================================================
# 07_covariates_finegrid.R
# DAIT Pilot — SENSITIVITY CHECK at finer spatial resolution
#
# RATIONALE (documented before seeing results): the original
# pilot (03_prepare_covariates.R) aggregated the DEM at fact=10
# (~300m) for computational tractability. lith_class showed zero
# non-zero coefficients in the fitted MaxEnt model (05_run_maxent.R
# output), consistent with bedrock-boundary information being
# blurred by this aggregation. Since the crop+simplify approach
# resolved the original computational bottleneck, this script
# re-runs covariate preparation at fact=5 (~150m) as a legitimate
# sensitivity check on whether spatial resolution, rather than the
# underlying prediction, explains the null result in
# 06_stratified_evaluation.R. This script was written and its
# rationale documented BEFORE re-running the stratified evaluation
# at this resolution.
# ============================================================

library(here); library(terra); library(dplyr)

sites <- read.csv(here("data", "derived", "sites_with_compression.csv"))
pts <- vect(sites, geom = c("Longitude", "Latitude"), crs = "EPSG:4326")
ext_box <- ext(pts) + 0.05

dem_full <- rast(here("data", "raw", "DEM", "DEM.tif"))
dem <- crop(dem_full, ext_box)
dem <- aggregate(dem, fact = 5, fun = "mean")   # <-- CHANGED: fact=5 not 10
cat("Fine-grid DEM cells:", ncell(dem), "\n")

slope <- terrain(dem, v = "slope", unit = "degrees")
tri   <- terrain(dem, v = "TRI")

geomorph <- vect(here("data", "raw", "Geomorphology", "Geomorphology.shp"))
geomorph <- crop(geomorph, ext_box)
geomorph <- simplifyGeom(geomorph, tolerance = 0.0005)
geomorph$geo_class <- case_when(
  geomorph$legend_sho %in% c("Alluvial Plain", "Flood Plain", "Anthropogenic terrain",
                             "Quarry and Mine Dump", "Dam and Reservoir") ~ "Depositional_Unstable",
  geomorph$legend_sho %in% c("Moderately Dissected Hills and Valleys", "Highly Dissected Hills and Valleys",
                             "Low Dissected Hills and Valleys", "Moderately Dissected Plateau",
                             "Low Dissected Plateau", "Pediment Pediplain Complex") ~ "Stable_Bedrock",
  TRUE ~ NA_character_
)
geomorph_r <- rasterize(geomorph, dem, field = "geo_class")

lithology <- vect(here("data", "raw", "Lithology", "Lithology.shp"))
lithology <- crop(lithology, ext_box)
lithology <- simplifyGeom(lithology, tolerance = 0.0005)
hard_rock <- c("BASALT","QUARTZITE","GRANITE","GNEISS/MIGMATITE","GRANITE GNEISS/MIGMATITE",
               "AMPHIBOLITE","GRANULITE","CHERT","MARBLE","CALC GNEISS","CALC SILICATE ROCK",
               "FOLIATED GRANITE","GREY HORNBLENDE BIOTITE GNEISS","QUARTZ VEIN",
               "QUARTZ VEIN/SILICIFIED ZONE","META BASALT","META GABBRO","META RHYOLITE/TUFF",
               "META ULTRAMAFITE","BIF","DOLOMITIC LIMESTONE","LIMESTONE","CHERTY LIMESTONE",
               "MANGANIFEROUS MARBLE","COTICULE","GONDITE/MANGANESE ORE")
soft_rock <- c("ALLUVIUM","CLAY","LATERITE","SHALE","SANDSTONE","FINE GRAINED SANDSTONE",
               "FERRUGINOUS SANDSTONE","SANDSTONE WITH COAL","PHYLLITE","SCHIST",
               "CHLORITE SCHIST","MUSCOVITE SCHIST","QUARTZ MICA SCHIST","QUARTZ MUSCOVITE SCHIST",
               "ANDALUSITE MICA SCHIST","MANGANIFEROUS MICA SCHIST")
lithology$lith_class <- case_when(
  lithology$lithologic %in% hard_rock ~ "Hard_Bedrock",
  lithology$lithologic %in% soft_rock ~ "Soft_Unconsolidated",
  TRUE ~ NA_character_
)
lithology_r <- rasterize(lithology, dem, field = "lith_class")

rivers <- vect(here("data", "raw", "Rivers", "Rivers.shp"))
rivers <- project(rivers, crs(dem))
rivers <- crop(rivers, ext_box)
rivers <- simplifyGeom(rivers, tolerance = 0.0005)
dist_river <- distance(rasterize(rivers, dem, background = NA))

waterbody <- vect(here("data", "raw", "Waterbody", "Waterbody.shp"))
waterbody <- project(waterbody, crs(dem))
waterbody <- crop(waterbody, ext_box)
waterbody <- simplifyGeom(waterbody, tolerance = 0.0005)
dist_water <- distance(rasterize(waterbody, dem, background = NA))

covs <- c(dem, slope, tri, dist_river, dist_water)
names(covs) <- c("elevation", "slope", "tri", "dist_river", "dist_water")
geomorph_r  <- resample(geomorph_r, dem, method = "near")
lithology_r <- resample(lithology_r, dem, method = "near")
names(geomorph_r) <- "geo_class"
names(lithology_r) <- "lith_class"
covs_full <- c(covs, geomorph_r, lithology_r)
print(covs_full)

writeRaster(covs_full, here("data", "derived", "covariate_stack_finegrid.tif"), overwrite = TRUE)
cat("\nSaved: data/derived/covariate_stack_finegrid.tif\n")
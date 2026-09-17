# ============================================================
# 03_prepare_covariates.R
# DAIT Pilot — Time-Stable Covariate Preparation
#
# Cropped to site extent (+0.05 deg buffer) and aggregated to
# ~300m resolution (fact=10) for pilot-scale tractability.
# Complex polygon layers (Geomorphology, Lithology, Rivers,
# Waterbody) simplified (tolerance=0.0005) before rasterization
# to keep rasterize/distance computation fast.
#
# CRS NOTE: Rivers and Waterbody source shapefiles are in
# UTM Zone 44N (EPSG:32644); all other layers and the DEM are in
# WGS84 (EPSG:4326). Both are reprojected to match the DEM before
# any spatial operation.
#
# COVARIATE NOTE: Modern bioclimatic variables (WorldClim/CHELSA
# current) and Sentinel-2 vegetation indices (NDVI/BSI) are
# deliberately excluded. These reflect present-day (1981-2010 or
# current) conditions and bear no defensible relationship to
# depositional conditions at the time of Palaeolithic occupation,
# which may predate them by 10^4-10^6 years. Only time-stable,
# geology- and terrain-derived covariates are used: elevation,
# slope, terrain ruggedness index (TRI), bedrock lithology class,
# geomorphological unit class, and distance to river/waterbody.
# ============================================================

library(here)
library(terra)
library(dplyr)

# ---- 1. Site extent + buffer ----
sites <- read.csv(here("data", "derived", "sites_with_compression.csv"))
pts <- vect(sites, geom = c("Longitude", "Latitude"), crs = "EPSG:4326")
ext_box <- ext(pts) + 0.05
cat("Site extent + buffer:\n"); print(ext_box)

# ---- 2. DEM: load, crop, aggregate ----
dem_full <- rast(here("data", "raw", "DEM", "DEM.tif"))
dem <- crop(dem_full, ext_box)
dem <- aggregate(dem, fact = 10, fun = "mean")
cat("DEM ready | cells:", ncell(dem), "\n")

slope <- terrain(dem, v = "slope", unit = "degrees")
tri   <- terrain(dem, v = "TRI")

# ---- 3. Geomorphology: load, crop, simplify, classify, rasterize ----
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
cat("Geomorphology raster done.\n")

# ---- 4. Lithology: load, crop, simplify, classify, rasterize ----
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
cat("Lithology raster done.\n")

# ---- 5. Rivers: reproject (UTM44N -> DEM CRS), crop, simplify, distance ----
rivers <- vect(here("data", "raw", "Rivers", "Rivers.shp"))
rivers <- project(rivers, crs(dem))
rivers <- crop(rivers, ext_box)
rivers <- simplifyGeom(rivers, tolerance = 0.0005)
river_r <- rasterize(rivers, dem, background = NA)
dist_river <- distance(river_r)
cat("dist_river done | features used:", nrow(rivers), "\n")

# ---- 6. Waterbody: reproject (UTM44N -> DEM CRS), crop, simplify, distance ----
waterbody <- vect(here("data", "raw", "Waterbody", "Waterbody.shp"))
waterbody <- project(waterbody, crs(dem))
waterbody <- crop(waterbody, ext_box)
waterbody <- simplifyGeom(waterbody, tolerance = 0.0005)
waterbody_r <- rasterize(waterbody, dem, background = NA)
dist_water <- distance(waterbody_r)
cat("dist_water done | features used:", nrow(waterbody), "\n")

# ---- 7. Assemble final covariate stack ----
covs <- c(dem, slope, tri, dist_river, dist_water)
names(covs) <- c("elevation", "slope", "tri", "dist_river", "dist_water")

geomorph_r  <- resample(geomorph_r, dem, method = "near")
lithology_r <- resample(lithology_r, dem, method = "near")
names(geomorph_r) <- "geo_class"
names(lithology_r) <- "lith_class"

covs_full <- c(covs, geomorph_r, lithology_r)
cat("\nFinal covariate stack:\n")
print(covs_full)

# ---- 8. Save ----
dir.create(here("data", "derived"), showWarnings = FALSE, recursive = TRUE)
writeRaster(covs_full, here("data", "derived", "covariate_stack.tif"), overwrite = TRUE)
cat("\nSaved: data/derived/covariate_stack.tif — pipeline complete.\n")
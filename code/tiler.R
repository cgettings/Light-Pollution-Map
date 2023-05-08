library(tidyverse)
library(tiler)
library(terra)
library(fs)
library(stars)

tile_dir <- dir_create(path_abs("plots/sky_brightness_geotiff/tiles"))
map <- "plots/sky_brightness_geotiff/sky_brightness_geotiff.tif"

(r <- rast(map))
plot(r)

crs(r, proj = TRUE)

tile(map, tile_dir, 7)

dir_ls(tile_dir)

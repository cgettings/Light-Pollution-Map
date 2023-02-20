

library(tidyverse)
library(sf)
library(terra)
library(gdalUtilities)
library(fs)

sky_brightness_2 <- rast(sky_brightness)

sky_brightness_2 <-
    rast(
        "C:/Users/Chris/Documents/Projects/light_pollution/data/sky_brightness_geotiff.tif"
    )

writeRaster(
    sky_brightness_2,
    "data/sky_brightness_geotiff.tif",
    filetype = "GTiff",
    overwrite = TRUE
)

writeRaster(
    sky_brightness_2,
    "data/sky_brightness_COG.tif",
    filetype = "COG",
    overwrite = TRUE
)

sky_brightness_COG <-
    rast("data/sky_brightness_COG.tif") %>% st_as_stars()

# gdalUtilities::gdal_translate(
#     src_dataset = "data/sky_brightness_geotiff.tif",
#     dst_dataset = "docs/cog/sky_brightness_geotiff_1.tif",
#     co = matrix(
#         c("TILED=YES",
#           "COPY_SRC_OVERVIEWS=YES",
#           "COMPRESS=DEFLATE"),
#         ncol = 1
#     )
# )


gdalUtilities::gdal_translate(
    src_dataset = "data/sky_brightness_geotiff.tif",
    dst_dataset = "data/sky_brightness_geotiff_1.tif",
    co = matrix(
        c("TILED=YES",
          "COPY_SRC_OVERVIEWS=YES",
          "COMPRESS=DEFLATE"),
        ncol = 1
    )
)

file_copy("data/sky_brightness_geotiff.tif", "data/sky_brightness_geotiff_2.tif")

gdal_addo(
    file = "data/sky_brightness_geotiff_2.tif",
    overviews = c(2, 4, 8, 16),
    method = "NEAREST"
)

gdalUtilities::gdal_translate(
    src_dataset = "data/sky_brightness_geotiff_2.tif",
    dst_dataset = "data/sky_brightness_geotiff_3.tif",
    co = matrix(
        c("TILED=YES",
          "COPY_SRC_OVERVIEWS=YES",
          "COMPRESS=DEFLATE"),
        ncol = 1
    )
)


# gdal_addo(
#     file = "docs/reg/sky_brightness_geotiff.tif",
#     method = "average"
# )
# 
# gdalUtilities::gdal_translate(
#     src_dataset = "docs/reg/sky_brightness_geotiff.tif",
#     dst_dataset = "docs/reg/sky_brightness_geotiff_1.tif",
#     co = matrix(c("TILED=YES",
#                   "COPY_SRC_OVERVIEWS=YES"),
#                 ncol = 1)
# )


# gdal_utils(
#     util = "translate",
#     source = "docs/cog/sky_brightness_geotiff.tif",
#     destination = "docs/cog/sky_brightness_cog_4.tif",
#     options = c("TILED=YES", "COPY_SRC_OVERVIEWS=YES"),
#     quiet = FALSE
# )
# 
# gdal_utils(
#     util = "translate",
#     source = "docs/cog/sky_brightness_geotiff.tif",
#     destination = "docs/cog/sky_brightness_cog_3.tif",
#     options = c("COPY_SRC_OVERVIEWS=YES"),
#     quiet = FALSE
# )


gdal_utils(
    util = "translate",
    source = "data/sky_brightness_geotiff.tif",
    destination = "data/sky_brightness_geotiff_4.tif",
    options = c("TILED=YES", "COPY_SRC_OVERVIEWS=YES"),
    quiet = FALSE
)

gdal_utils(
    util = "translate",
    source = "data/sky_brightness_geotiff_2.tif",
    destination = "data/sky_brightness_geotiff_5.tif",
    options = c("TILED=YES", "COPY_SRC_OVERVIEWS=YES"),
    quiet = FALSE
)


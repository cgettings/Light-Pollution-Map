###########################################################################################-
###########################################################################################-
##
## Mapping loght pollution ----
##
###########################################################################################-
###########################################################################################-

#=========================================================================================#
# Setting up ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Loading libraries
#-----------------------------------------------------------------------------------------#

library(jsonlite)
library(terra)
library(tidyverse)
library(sf)
library(gdalUtilities)
library(leaflet)
library(leaflet.extras)
library(leafem)
library(stars)
library(viridisLite)
library(here)
library(glue)
library(tigris)
library(fs)
library(geojsonio)
library(palr)
library(reticulate)
library(rstudioapi)

use_condaenv("r-reticulate")

#-----------------------------------------------------------------------------------------#
# Loading data ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# border for states
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

state_border <- 
    states(cb = TRUE, resolution = "500k", year = 2021) %>% 
    filter(as.integer(STATEFP) < 60, !STUSPS %in% c("AK", "HI")) %>% 
    arrange(STUSPS)

usa_border_sf <- 
    state_border %>% 
    st_transform(st_crs(2263)) %>% 
    st_union() %>% 
    st_transform(st_crs(4326))

usa_bbox <- st_bbox(usa_border_sf)

usa_bbox_vect <-
    usa_bbox %>% 
    st_as_sfc() %>%
    vect()


# usa_border_sf %>% ggplot() + geom_sf()

# save as GeoJSON, then load in HTML as "mask" option to "GeoRasterLayer"

geojson_write(
    usa_border_sf, 
    geometry = "polygon",
    file = "data/usa_border.geojson"
)


sky_brightness_breaks <- 
    sqrt(sqrt(sqrt(sqrt(
        seq(17 ^ 16, 22 ^ 16, length.out = 64)
    ))))

#-----------------------------------------------------------------------------------------#
# splitting country into 5 boxes ----
#-----------------------------------------------------------------------------------------#

usa_bbox_grid <- st_make_grid(usa_bbox, n = 2)

# usa_bbox_grid_sf <- usa_bbox_grid %>% st_as_sf() %>% as_tibble() %>% mutate(num = 1:nrow(.))
# 
# ggplot() +
#     geom_sf(data = usa_bbox_grid_sf, aes(geometry = x, fill = as.character(num))) +
#     geom_sf(data = usa_border_sf, fill = NA)


for (i in 1:length(usa_bbox_grid)) {
    
    print(i)
    
    block_box_vect <-
        usa_bbox_grid[i] %>% 
        vect()
    
    crop_vect <- crop(block_box_vect, usa_bbox_vect)
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # luminance & finding which points are within specified borders
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    # downloaded from http://doi.org/10.5880/GFZ.1.4.2016.001
    
    luminance <- 
        rast(here("data/World_Atlas_2015.tif")) %>% 
        # crop(block_box_vect, mask = TRUE)
        # crop(usa_bbox_vect, mask = TRUE)
        crop(crop_vect, mask = TRUE)
    
    #-----------------------------------------------------------------------------------------#
    # Subsetting and computing
    #-----------------------------------------------------------------------------------------#
    
    sky_brightness <- 
        
        luminance %>% 
        
        # turn into stars object, so that as_tibble returns all 3 columns
        
        st_as_stars() %>% 
        
        # turning into a tbl to compute sky brightness
        
        as_tibble() %>% 
        
        # renaming to something that makes sense
        
        rename(luminance = World_Atlas_2015) %>% 
        
        # drop NAs representing cropped/masked values
        
        drop_na(luminance) %>% 
        
        # Computing mag/arcsec^2
        
        mutate(
            
            # adding 0.171168465 to each value. ensuring that a luminance of 0 produces 
            #   sky_brightness of 22.0 (which is considered the darkest a dark sky gets), 
            #   and also keeps `log10()` happy
            # 
            # This replicates the procedure done by lightpollution.info when displaying
            #   luminance values
            
            sky_brightness = (log10(((as.numeric(luminance)+0.171168465)/1000)/10.8e4))/-0.4
            
        ) %>% 
        
        select(-luminance) %>%
        
        # transforming to stars object, to make adding to leaflet easier
        
        st_as_stars() %>%
        
        # re-setting CRS to original data
        
        st_set_crs(value = st_crs(4326))
    
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # getting bbox for setting map bounds
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    sky_brightness_bbox <- st_bbox(sky_brightness)
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # converting to tbl, to pass to onRender
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    sky_brightness_coords <- 
        sky_brightness %>% 
        as_tibble() %>% 
        drop_na(sky_brightness)
    
    # saving as JSON to avoid embedding in document
    
    sky_brightness_coords %>% 
        toJSON(pretty = FALSE, dataframe = "columns") %>% 
        write_lines(glue("data/sky_brightness_coords_{i}.json"))

    
    # collecting garbage, because `stars` object is huge
    
    invisible(gc())
    
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # setting colors
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    sky_brightness_colored <-
        image_stars(
            sky_brightness, 
            col = inferno(64, direction = -1),
            breaks = sky_brightness_breaks
        )
    
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # saving cropped raster
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    # sky_brightness_geotiff <- rast(sky_brightness)
    
    write_stars(
        sky_brightness_colored,
        glue("plots/sky_brightness_geotiff/sky_brightness_geotiff_{i}.tif"),
        type = "Byte"
    )
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # saving tiles ----
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    term <- terminalCreate(show = FALSE)

    terminalSend(
        term,
        paste(
            'conda activate r-reticulate',
            '\r\n',
            'python C:/Users/Chris/AppData/Local/r-miniconda/envs/r-reticulate/Lib/site-packages/osgeo_utils/gdal2tiles.py',
            # '--webviewer=leaflet --xyz --zoom="6-13" --verbose --srcnodata=255 --exclude --processes=1 --s_srs=EPSG:4326',
            '--webviewer=leaflet --xyz --zoom="6-13" --verbose --srcnodata=255 --exclude -e --processes=1 --s_srs=EPSG:4326',
            # '--xyz --zoom="6-13" --verbose --srcnodata=255 --exclude --processes=4',
            paste0('plots/sky_brightness_geotiff/sky_brightness_geotiff_', i, '.tif'),
            'plots/sky_brightness_geotiff/tiles',
            '\r\n'
        )
    )
    
}

# terminalKill(term)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# saving tiles ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

for (i in 1:length(usa_bbox_grid)) {
    
    print(i)
    
    term <- terminalCreate(show = FALSE)
    
    terminalSend(
        term,
        paste(
            'conda activate r-reticulate',
            '\r\n',
            'python C:/Users/Chris/AppData/Local/r-miniconda/envs/r-reticulate/Lib/site-packages/osgeo_utils/gdal2tiles.py',
            # '--webviewer=leaflet --xyz --zoom="6-13" --verbose --srcnodata=255 --exclude --processes=1 --s_srs=EPSG:4326',
            '--webviewer=leaflet --xyz --zoom="6-13" --verbose --srcnodata=255 --exclude -e --processes=1 --s_srs=EPSG:4326',
            # '--xyz --zoom="6-13" --verbose --srcnodata=255 --exclude --processes=4',
            paste0('plots/sky_brightness_geotiff/sky_brightness_geotiff_', i, '.tif'),
            'plots/sky_brightness_geotiff/tiles',
            '\r\n'
        )
    )
    
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

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

#-----------------------------------------------------------------------------------------#
# Loading data
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# border for states
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

state_border_sf <- 
    states(cb = TRUE, resolution = "500k", year = 2021) %>% 
    filter(as.integer(STATEFP) < 60) %>%
    # filter(STUSPS %in% c("NY", "CT", "NH", "VT", "MA", "ME", "RI", "PA", "NJ", "MD", "DE", "MD", "WV", "OH")) %>%
    st_transform(st_crs(2263)) %>% 
    st_union() %>% 
    st_transform(st_crs(4326))

state_border <- 
    state_border_sf %>% 
    vect()

# save as GeoJSON, then load in HTML as "mask" option to "GeoRasterLayer"

geojson_write(
    state_border_sf, 
    geometry = "polygon",
    file = "data/state_border.geojson"
)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# luminance & finding which points are within specified borders
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# downloaded from http://doi.org/10.5880/GFZ.1.4.2016.001

luminance <- 
    rast(here("data/World_Atlas_2015.tif")) %>% 
    crop(state_border, mask = TRUE)

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
        
        sky_brightness = (log10(((luminance+0.171168465)/1000)/10.8e4))/-0.4
        
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
    write_lines("data/sky_brightness_coords.json")

sky_brightness_breaks <- 
    sqrt(sqrt(sqrt(sqrt(
        seq(
            min(sky_brightness$sky_brightness, na.rm = TRUE) ^ 16,
            max(sky_brightness$sky_brightness, na.rm = TRUE) ^ 16,
            length.out = 64
        )
    ))))

sky_brightness_breaks %>% 
    toJSON() %>% 
    str_c("let breaks = ", .) %>% 
    write_lines("data/sky_brightness_breaks.js")

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
    "plots/sky_brightness_geotiff.tif",
    type = "Byte"
)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# saving tiles ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

term <- rstudioapi::terminalCreate(show = FALSE)

rstudioapi::terminalSend(
    term,
    paste(
        'conda activate r-reticulate',
        '\r\n',
        'python C:/Users/Chris/AppData/Local/r-miniconda/envs/r-reticulate/Lib/site-packages/osgeo_utils/gdal2tiles.py',
        '--webviewer=leaflet --xyz --zoom="6-13" --verbose --srcnodata=255 --exclude --processes=4',
        'plots/sky_brightness_geotiff/sky_brightness_geotiff.tif',
        'plots/sky_brightness_geotiff/tiles',
        '\r\n'
    )
)

repeat({
    
    if(!rstudioapi::terminalBusy(term)) {
        
        print("Done!")
        
        term_buff <- rstudioapi::terminalBuffer(term)
        
        # rstudioapi::terminalKill(term)
        
        break
        
    } else {
        
        print("Busy")
        
        Sys.sleep(2)
        
    }
    
})


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

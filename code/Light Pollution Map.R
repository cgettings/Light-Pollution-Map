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

library(raster)
library(tidyverse)
library(sf)
library(rgdal)
library(stars)
library(leaflet)
library(leaflet.extras)
library(leaflet.providers)
library(leafem)
library(viridisLite)
library(htmlwidgets)
library(here)
library(glue)

#-----------------------------------------------------------------------------------------#
# Loading custom functions
#-----------------------------------------------------------------------------------------#

# `addResetMapButton` from {leaflet.extras}, but allowing specification of position

source("code/functions/addResetMapButtonPosition.R")

#-----------------------------------------------------------------------------------------#
# Loading data
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# luminance
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# downloaded from http://doi.org/10.5880/GFZ.1.4.2016.001

luminance <- 
    raster(here("data/World_Atlas_2015.tif")) %>% 
    st_as_stars(ignore_file = TRUE)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# bounding boxes for states
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# downloaded from https://anthonylouisdagostino.com/bounding-boxes-for-all-us-states/

state_bbox <- 
    read_csv(here("data/US_State_Bounding_Boxes.csv")) %>% 
    filter(STUSPS == "NY") %>% 
    mutate(
        map_center_x = rowMeans(select(., xmin, xmax)),
        map_center_y = rowMeans(select(., ymin, ymax))
    )


#-----------------------------------------------------------------------------------------#
# Subsetting data
#-----------------------------------------------------------------------------------------#

# the raster can get very large, so restricting it to specified states

luminance_state <- 
    luminance %>% 
    filter(x >= state_bbox$xmin) %>% 
    filter(x <= state_bbox$xmax) %>% 
    filter(y >= state_bbox$ymin) %>% 
    filter(y <= state_bbox$ymax) %>% 
    as_tibble()

gc()


#-----------------------------------------------------------------------------------------#
# Computing mag/arcsec^2
#-----------------------------------------------------------------------------------------#

# raw data values are in mcd/m^2

sky_brightness <- 
    luminance_state %>% 
    rename(luminance = World_Atlas_2015) %>% 
    mutate(
        
        # replacing 0's with tiny value, so log10 will not give -Inf
        
        luminance_no0 = if_else(luminance == 0, 1e-08, luminance),
        sky_brightness = (log10((luminance_no0/1000)/10.8e4))/-0.4
        
    ) %>% 
    
    select(-luminance, -luminance_no0) %>% 
    
    # transforming to stars object, to make adding to leaflet easier
    
    st_as_stars() %>%
    
    # re-setting CRS to original data
    
    st_set_crs(value = st_crs(luminance))


#=========================================================================================#
# Mapping ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Constructing map
#-----------------------------------------------------------------------------------------#

light_pollution_heatmap <- 
    
    # basemap
    
    leaflet() %>%
    
    # tiles
    
    enableTileCaching() %>%
    
    addProviderTiles(providers$Stamen.TonerHybrid, group = "Streets") %>%
    
    addTiles(
        urlTemplate = 
            paste0(
                "//services.arcgisonline.com/ArcGIS/rest/services/",
                "USA_Topo_Maps/MapServer/tile/{z}/{y}/{x}"
            ), 
        group = "Topo",
        attribution = 
            glue(
                "Map tiles by <a href='http://goto.arcgisonline.com/maps/USA_Topo_Maps'>Esri</a> - ",
                "Map Data © 2013 National Geographic Society, i-cubed"
            )
    ) %>% 
    
    # sky brightness raster
    
    addStarsImage(
        x = sky_brightness,
        colors = inferno(256, alpha = .7, direction = -1),
        project = TRUE, 
        group = "Sky Brightness (mag per arcsec^2)",
        layerId = "Sky Brightness (mag per arcsec^2)",
        attribution = 
            glue(
                "Sky Brightness Data from <a href='http://doi.org/10.5880/GFZ.1.4.2016.001'>",
                "'Supplement to: The New World Atlas of Artificial Night Sky Brightness'</a>"
            )
    ) %>%
    
    # adding controls
    
    addLayersControl(
        baseGroups = c("Streets", "Topo"),
        overlayGroups = "Sky Brightness (mag per arcsec^2)",
        options = layersControlOptions(collapsed = FALSE),
        position = "topright"
    ) %>%
    
    # sky brightness raster mouseover values
    
    addImageQuery(
        x = sky_brightness,
        group = "Sky Brightness (mag per arcsec^2)",
        layerId = "Sky Brightness (mag per arcsec^2)",
        position = "topright",
        digits = 1,
        type = "mousemove",
        prefix = "",
        project = TRUE
    ) %>% 
    
    # setting view params based on state
    
    setView(
        lng = state_bbox$map_center_x,
        lat = state_bbox$map_center_y,
        zoom = 7
    ) %>%
    
    # allowing user to place a marker
    
    addDrawToolbar(
        polylineOptions = FALSE,
        polygonOptions = FALSE,
        circleOptions = FALSE,
        rectangleOptions = FALSE,
        markerOptions = drawMarkerOptions(),
        circleMarkerOptions = FALSE,
        position = "topleft",
        editOptions = editToolbarOptions()
    ) %>% 
    
    # allowing user to search for locations
    
    addSearchOSM(
        options = 
            searchFeaturesOptions(
                zoom = 9, 
                openPopup = TRUE, 
                propertyName = "marker", 
                autoType = FALSE,
                position = "topleft",
                hideMarkerOnCollapse = TRUE
            )
    ) %>% 
    
    # reset button
    
    addResetMapButtonPosition(position = "bottomleft") %>%
    
    addMouseCoordinates(native.crs = TRUE)
    

#-----------------------------------------------------------------------------------------#
# Saving map ----
#-----------------------------------------------------------------------------------------#

saveWidget(
    widget = light_pollution_heatmap,
    file = here("plots", "light_pollution_heatmap.html"),
    selfcontained = TRUE,
    title = "Light Pollution Heat Map"
)


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

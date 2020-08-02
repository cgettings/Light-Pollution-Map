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
library(stars)
library(leaflet)
library(leaflet.extras)
library(leaflet.providers)
library(leafem)
library(viridisLite)
library(htmlwidgets)
library(here)
library(glue)
library(tmap)
library(tigris)

#-----------------------------------------------------------------------------------------#
# Loading custom functions
#-----------------------------------------------------------------------------------------#

# `addResetMapButton` from {leaflet.extras}, but allowing specification of position

source("code/functions/addResetMapButtonPosition.R")

#-----------------------------------------------------------------------------------------#
# Loading data
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Closest dark points
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

closest_dark_points <- read_rds(here("data/closest_dark_points.rds"))

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# bounding boxes for states
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# downloaded from https://anthonylouisdagostino.com/bounding-boxes-for-all-us-states/

# the raster can get very large, so restricting it to specified states

state_bbox <- 
    read_csv(here("data/US_State_Bounding_Boxes.csv")) %>% 
    filter(STUSPS %in% c("NY", "CT", "NH", "VT", "MA", "ME", "RI")) %>% 
    mutate(
        map_center_x = rowMeans(select(., xmin, xmax)),
        map_center_y = rowMeans(select(., ymin, ymax))
    )

state_extent <- 
    with(
        state_bbox, 
        extent(min(xmin), max(xmax), min(ymin), max(ymax))
    )

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# border for states
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

state_border <- 
    states(cb = TRUE) %>% 
    st_as_sf() %>% 
    filter(STUSPS %in% c("NY", "CT", "NH", "VT", "MA", "ME", "RI")) %>% 
    st_transform(crs = st_crs(4326)) %>%
    as_tibble()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# luminance
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# downloaded from http://doi.org/10.5880/GFZ.1.4.2016.001

# clipping to within state's bounding box as raster (b/c on disk), to limit the massive 
#   amount of memory a whole-world raster takes up

luminance <- 
    raster(here("data/World_Atlas_2015.tif")) %>% 
    crop(state_extent) %>% 
    st_as_stars(ignore_file = TRUE) %>% 
    st_set_crs(st_crs(4326))

#-----------------------------------------------------------------------------------------#
# Subsetting and computing
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# finding which points are within state border
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

luminance_in_state <- 
    st_intersects(
        luminance, 
        state_border$geometry %>% st_combine(), 
        sparse = FALSE, 
        as_points = TRUE,
        model = "closed"
    ) %>% 
    as.logical()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# subsetting and computing
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

sky_brightness <- 
    
    luminance %>% 
    
    # turning into a tbl to compute sky brightness
    
    as_tibble() %>% 
    
    # use logical vector to filter rows
    
    filter(luminance_in_state) %>% 
    
    # renaming to something that makes sense
    
    rename(luminance = World_Atlas_2015) %>% 
    
    # Computing mag/arcsec^2
    
    mutate(
        
        # replacing 0's with tiny value, so log10 will not give -Inf
        
        luminance_no0 = if_else(luminance == 0, 1e-08, luminance),
        sky_brightness = (log10((luminance_no0/1000)/10.8e4))/-0.4
        
    ) %>% 
    
    select(-luminance, -luminance_no0) %>% 
    
    # transforming to stars object, to make adding to leaflet easier
    
    st_as_stars() %>%
    
    # re-setting CRS to original data
    
    st_set_crs(value = st_crs(4326))


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
    
    addProviderTiles(providers$Stamen.TonerBackground, group = "Minimal") %>%
    addProviderTiles(providers$Stamen.TonerHybrid, group = "Minimal") %>%
    addProviderTiles(providers$OpenStreetMap.HOT, group = "Streets") %>%
    
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
                "Sky Brightness Data: <a href='http://doi.org/10.5880/GFZ.1.4.2016.001'>",
                "doi.org/10.5880/GFZ.1.4.2016.001</a>"
            )
    ) %>%
    
    # adding controls
    
    addLayersControl(
        baseGroups = c("Minimal", "Streets", "Topo"),
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
        lng = mean(c(state_extent@xmin, state_extent@xmax)),
        lat = mean(c(state_extent@ymin, state_extent@ymax)),
        zoom = 6
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
    
    # adding mouse coordinates
    
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

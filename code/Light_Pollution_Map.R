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
library(leaflet)
library(leaflet.extras)
library(leafem)
library(stars)
library(viridisLite)
library(htmlwidgets)
library(htmltools)
library(here)
library(glue)
library(tigris)

#-----------------------------------------------------------------------------------------#
# Loading data
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# bounding boxes for states
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# downloaded from https://anthonylouisdagostino.com/bounding-boxes-for-all-us-states/

state_bbox <- 
    read_csv(here("data/US_State_Bounding_Boxes.csv")) %>% 
    filter(STUSPS %in% c("NY", "CT", "NH", "VT", "MA", "ME", "RI", "PA", "NJ", "MD", "DE")) %>%
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
    filter(STUSPS %in% c("NY", "CT", "NH", "VT", "MA", "ME", "RI", "PA", "NJ", "MD", "DE")) %>%
    st_transform(crs = st_crs(4326)) %>%
    as_tibble()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# luminance
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# downloaded from http://doi.org/10.5880/GFZ.1.4.2016.001

luminance <- 
    raster(here("data/World_Atlas_2015.tif")) %>% 
    crop(state_extent) %>% 
    st_as_stars(ignore_file = TRUE) %>% 
    st_set_crs(st_crs(4326))

#-----------------------------------------------------------------------------------------#
# Subsetting and computing
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# finding which points are within specified borders
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

# converting to tbl, to pass to onRender

sky_brightness_coords <- sky_brightness %>% as_tibble()

# getting bbox for setting map bounds

sky_brightness_bbox <- st_bbox(sky_brightness)


#-----------------------------------------------------------------------------------------#
# Adding extras ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# plugins & dependencies
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

registerPlugin <- 
    function(map, plugin) {
        map$dependencies <- c(map$dependencies, list(plugin))
        map
    }

geoblaze_plugin <-
    htmlDependency(
        "geoblaze", "1",
        src = c(file = here("code/functions/geotiff")),
        script = "geoblaze.web.min.js",
        all_files = FALSE
    )

monospace_style <-
    htmlDependency(
        "monospace", "1",
        src = c(file = here("code/functions")),
        stylesheet = "monospace.css",
        all_files = FALSE
    )

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# `addResetMapButton` from {leaflet.extras}, but allowing specification of position
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

source("code/functions/addResetMapButtonPosition.R")

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Custom JavaScript for `onRender`
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

closest_dark_place <- read_file(here("code/closest_dark_place.js"))

#=========================================================================================#
# Mapping
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Constructing map
#-----------------------------------------------------------------------------------------#

light_pollution_heatmap <- 
    
    # basemap
    
    leaflet(
        options = list(
            "duration" = 0.375,
            "zoomSnap" = 0.5,
            "padding" = c(10, 10)
        )
    ) %>%
    
    fitBounds(
        lng1 = sky_brightness_bbox[[1]],
        lat1 = sky_brightness_bbox[[2]],
        lng2 = sky_brightness_bbox[[3]],
        lat2 = sky_brightness_bbox[[4]]
    ) %>%
    
    # tiles
    
    enableTileCaching() %>%
    
    addProviderTiles(
        providers$Stamen.TonerBackground, 
        group = "Minimal", 
        options = providerTileOptions(zIndex = -1000)
    ) %>%
    addProviderTiles(
        providers$Stamen.TonerHybrid, 
        group = "Minimal", 
        options = providerTileOptions(zIndex = -1000)
    ) %>%
    addProviderTiles(
        providers$OpenStreetMap.HOT, 
        group = "Streets", 
        options = providerTileOptions(zIndex = -1000)
    ) %>%
    
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
            ), 
        options = tileOptions(zIndex = -1000)
    ) %>% 
    
    # sky brightness raster
    
    addGeoRaster(
        x = sky_brightness,
        project = TRUE,
        group = "Sky Brightness (mag per arcsec^2)",
        layerId = "raster",
        resolution = 72,
        colorOptions =
            colorOptions(
                palette = inferno(256, direction = -1),
                na.color = "#00000000"
            ),
        options = tileOptions(zIndex = 1000)
    ) %>%
    
    # adding controls
    
    addLayersControl(
        baseGroups = c("Minimal", "Streets", "Topo"),
        overlayGroups = "Sky Brightness (mag per arcsec^2)",
        options = layersControlOptions(collapsed = FALSE, autoZIndex = FALSE),
        position = "topright"
    ) %>%
    
    # sky brightness raster mouseover values
    
    addImageQuery(
        x = sky_brightness,
        group = "Sky Brightness (mag per arcsec^2)",
        position = "topright",
        digits = 1,
        type = "mousemove",
        prefix = "",
        project = TRUE
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
    
    # registering dependencies
    
    addAwesomeMarkersDependencies(libs = "fa") %>%
    
    registerPlugin(geoblaze_plugin) %>%
    registerPlugin(monospace_style) %>% 
    
    # adding specialty JavaScript to find closest dark place to click
    
    onRender(
        str_c(
            "function(el, x, data) {\n",
            closest_dark_place,
            "}"
        ), 
        data = sky_brightness_coords %>% drop_na()
    )


#-----------------------------------------------------------------------------------------#
# Saving map ----
#-----------------------------------------------------------------------------------------#

saveWidget(
    widget = light_pollution_heatmap,
    file = here("plots", "light_pollution_heatmap_georaster.html"),
    selfcontained = TRUE,
    title = "Light Pollution Heat Map, from Maryland to Maine"
)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

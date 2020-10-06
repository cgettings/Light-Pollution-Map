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
library(fs)

#-----------------------------------------------------------------------------------------#
# Loading data
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# bounding boxes for states
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# downloaded from https://anthonylouisdagostino.com/bounding-boxes-for-all-us-states/

state_bbox <- 
    read_csv(here("data/US_State_Bounding_Boxes.csv")) %>% 
    filter(STUSPS %in% c("NY", "CT", "NH", "VT", "MA", "ME", "RI", "PA", "NJ", "MD", "DE"))

state_extent <- 
    with(
        state_bbox, 
        extent(min(xmin), max(xmax), min(ymin), max(ymax))
    )

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# border for states
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

state_border <- 
    states(cb = TRUE, resolution = "500k") %>% 
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
        as_points = FALSE
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

sky_brightness_coords <- sky_brightness %>% as_tibble() %>% drop_na()

gc()

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

# my own FA library

fa_dir <- path(path_home(), "node_modules/@fortawesome/fontawesome-free")

fa_plugin <-
    htmlDependency(
        name = "fontawesome", 
        version = fromJSON(path(fa_dir, "package.json"))$version,
        src = c(file = fa_dir),
        stylesheet = "css/all.css",
        all_files = TRUE
    )


# geoblaze raster computation

geoblaze_dir <- path(path_home(), "node_modules/geoblaze")

geoblaze_plugin <-
    htmlDependency(
        name = "geoblaze", 
        version = fromJSON(path(geoblaze_dir, "package.json"))$version,
        src = c(file = path(geoblaze_dir, "dist")),
        script = "geoblaze.web.min.js",
        all_files = FALSE
    )


# extramarkers

ExtraMarkers_dir <- path(path_home_r(), "R", "Leaflet.ExtraMarkers")

ExtraMarkers_plugin <-
    htmlDependency(
        name = "ExtraMarkers", 
        version = fromJSON(path(ExtraMarkers_dir, "package.json"))$version,
        src = c(file = path(ExtraMarkers_dir, "dist")),
        stylesheet = "css/leaflet.extra-markers.min.css",
        script = "js/leaflet.extra-markers.min.js",
        all_files = TRUE
    )


# geocoder

Geocoder_plugin <- 
    htmlDependency(
        name = "geocoder", 
        version = 1,
        src = list(href = "https://unpkg.com/leaflet-control-geocoder/dist"),
        stylesheet = "Control.Geocoder.css",
        script = "Control.Geocoder.js",
        all_files = TRUE
    )

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# modifications of {leaflet} functions
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# `addResetMapButton` from {leaflet.extras}, but allowing specification of position

source("code/functions/addResetMapButtonPosition.R")

# `addEasyButton` from {leaflet}, but removing fontawesome dependency (so I can use the current 
#   version from node repo)

source("code/functions/addEasyButtonNoFaDeps.R")

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Custom JavaScript and HTML for `onRender`
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

closest_dark_place_js <- read_file(here("code/js/closest_dark_place.js"))
dark_point_control    <- read_file(here("code/html/dark_point_control.html"))


# Replacing "####" in JavaScript with HTML

closest_dark_place <- 
    str_replace(
        closest_dark_place_js, 
        "####",
        dark_point_control
    )


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
            "padding" = c(10, 10),
            "preferCanvas" = FALSE, 
            "updateWhenZooming" = FALSE,
            "updateWhenIdle" = TRUE
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
        providers$OpenStreetMap.HOT, 
        group = "Streets", 
        options = providerTileOptions(zIndex = -1000)
    ) %>%
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
        group = "Sky Brightness",
        layerId = "raster",
        resolution = 64,
        colorOptions =
            colorOptions(
                palette = inferno(64, direction = -1),
                
                # modifying breaks to get a better mapping of visual differences to
                #   photometric categories
                # 
                # 16 = 2^4, so need 4 `sqrt()` calls to reverse:
                
                breaks = 
                    sqrt(sqrt(sqrt(sqrt(
                        seq(
                            min(sky_brightness$sky_brightness, na.rm = TRUE)^16, 
                            max(sky_brightness$sky_brightness, na.rm = TRUE)^16, 
                            length.out = 64
                        )
                    )))),
                na.color = "#00000000"
            ),
        options = 
            tileOptions(
                zIndex = 1000, 
                updateWhenZooming = FALSE,
                updateWhenIdle = TRUE
            )
    ) %>%
    
    # adding controls
    
    addLayersControl(
        baseGroups = c("Streets", "Minimal", "Topo"),
        overlayGroups = "Sky Brightness",
        options = layersControlOptions(collapsed = FALSE, autoZIndex = FALSE),
        position = "topright"
    ) %>%
    
    # sky brightness raster mouseover values
    
    addImageQuery(
        x = sky_brightness,
        group = "Sky Brightness",
        position = "topright",
        digits = 2,
        type = "mousemove",
        prefix = "",
        project = TRUE
    ) %>%
    
    # reset buttons
    
    addResetMapButtonPosition(position = "bottomleft") %>%
    
    # registering dependencies
    
    addAwesomeMarkersDependencies(libs = c("ion", "glyphicon")) %>%
    
    registerPlugin(fa_plugin) %>%
    registerPlugin(geoblaze_plugin) %>%
    registerPlugin(ExtraMarkers_plugin) %>%
    registerPlugin(Geocoder_plugin) %>%
    
    # adding specialty JavaScript to find closest dark place to click
    
    onRender(
        str_c(
            "function(el, x, data) {\n",
            closest_dark_place,
            "}"
        ), 
        data = sky_brightness_coords
    )
    

light_pollution_heatmap

#-----------------------------------------------------------------------------------------#
# Saving map ----
#-----------------------------------------------------------------------------------------#

saveWidget(
    widget = light_pollution_heatmap,
    file = here("plots", "light_pollution_heatmap_georaster.html"),
    selfcontained = TRUE,
    title = "Light Pollution Heat Map for the Northeast US"
)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

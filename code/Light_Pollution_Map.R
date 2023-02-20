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
# library(raster)
library(terra)
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
# border for states
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

state_border <- 
    states(cb = TRUE, resolution = "500k", year = 2021) %>% 
    # filter(GEOID < 60, !STUSPS %in% c("AK", "HI")) %>%
    # st_as_sf() %>% 
    filter(STUSPS %in% c("NY", "CT", "NH", "VT", "MA", "ME", "RI", "PA", "NJ", "MD", "DE", "MD", "WV", "OH")) %>%
    st_transform(st_crs(2263)) %>% 
    st_union() %>% 
    st_transform(st_crs(4326)) %>% 
    vect()

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
# saving cropped raster
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# sky_brightness_geotiff <- rast(sky_brightness)

write_stars(
    sky_brightness,
    "plots/sky_brightness_geotiff.tif"
)

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
    write_lines("plots/sky_brightness_coords.json")

# collecting garbage, because `stars` object is huge

invisible(gc())

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

fa_dir <- here("node_modules/@fortawesome/fontawesome-free")

fa_plugin <-
    htmlDependency(
        name = "fontawesome", 
        version = fromJSON(path(fa_dir, "package.json"))$version,
        src = c(file = fa_dir),
        stylesheet = "css/all.css",
        all_files = TRUE
    )


# geoblaze raster computation

geoblaze_dir <- here("node_modules/geoblaze")

geoblaze_plugin <-
    htmlDependency(
        name = "geoblaze", 
        version = fromJSON(path(geoblaze_dir, "package.json"))$version,
        src = c(file = path(geoblaze_dir, "dist")),
        script = "geoblaze.web.min.js",
        all_files = FALSE
    )


# extramarkers

ExtraMarkers_dir <- here("code/plugins/Leaflet.ExtraMarkers")

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

Geocoder_dir <- here("code/plugins/Control.Geocoder")

Geocoder_plugin <-
    htmlDependency(
        name = "geocoder",
        version = fromJSON(path(Geocoder_dir, "package.json"))$version,
        src = list(file = path(Geocoder_dir, "dist")),
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
# Mapping ----
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
    # addGeotiff(
        # url = "https://cgettings.github.io/Light-Pollution-Map/cog_with_cog/sky_brightness_COG.tif",
        # file = "plots/sky_brightness_geotiff.tif",
        x = sky_brightness,
        # x = sky_brightness_COG,
        project = TRUE,
        group = "Sky_Brightness",
        layerId = "the_raster",
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
                            # min(sky_brightness_COG$sky_brightness_COG.tif, na.rm = TRUE)^16,
                            # max(sky_brightness_COG$sky_brightness_COG.tif, na.rm = TRUE)^16,
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
        # x = sky_brightness_COG,
        group = "Sky_Brightness",
        layerId = "the_raster",
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
        )
        # data = sky_brightness_coords
    )
    

# light_pollution_heatmap

#-----------------------------------------------------------------------------------------#
# Saving map ----
#-----------------------------------------------------------------------------------------#

saveWidget(
    widget = light_pollution_heatmap,
    # file = here("plots", "light_pollution_heatmap_georaster_FALSE_noraster.html"),
    # file = here("plots", "light_pollution_heatmap_georaster_FALSE_noq.html"),
    # file = here("plots", "light_pollution_heatmap_georaster_TRUE_noq.html"),
    # file = here("plots", "light_pollution_heatmap_lower48_TRUE.html"),
    # file = here("plots", "light_pollution_heatmap_lower48_FALSE.html"),
    # file = here("plots", "light_pollution_heatmap_georaster_TRUE_q.html"),
    file = here("plots", "light_pollution_heatmap_georaster_FALSE_q.html"),
    # file = here("plots", "light_pollution_heatmap_georaster_url_2.html"),
    # file = here("plots", "light_pollution_heatmap_georaster_COG.html"),
    selfcontained = FALSE,
    # selfcontained = TRUE,
    title = "Light Pollution Heat Map for the US Northeast"
)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

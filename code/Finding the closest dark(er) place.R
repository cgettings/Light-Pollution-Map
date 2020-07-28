###########################################################################################-
###########################################################################################-
##
## Closest dark(er) place ----
##
###########################################################################################-
###########################################################################################-

# This script finds the closest place which is 1 mag/arcsec^2 darker than each point
#   (on a ~ 600m x 600m grid) in NYS.

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
library(leafem)
library(here)
library(glue)
library(foreach)
library(geosphere)
library(doParallel)
library(tictoc)

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
# Subsetting and computing
#-----------------------------------------------------------------------------------------#

# the raster can get very large, so restricting it to specified states

sky_brightness_df <- 
    luminance %>% 
    filter(x >= state_bbox$xmin) %>% 
    filter(x <= state_bbox$xmax) %>% 
    filter(y >= state_bbox$ymin) %>% 
    filter(y <= state_bbox$ymax) %>% 
    as_tibble() %>% 
    rename(luminance = World_Atlas_2015) %>% 
    
    # Computing mag/arcsec^2
    
    mutate(
        
        # replacing 0's with tiny value, so log10 will not give -Inf
        
        luminance_no0 = if_else(luminance == 0, 1e-08, luminance),
        sky_brightness = (log10((luminance_no0/1000)/10.8e4))/-0.4
        
    ) %>% 
    
    select(-luminance, -luminance_no0)

rm(luminance)

gc()


#=========================================================================================#
# Computing ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Creating SOCK cluster for parallel
#-----------------------------------------------------------------------------------------#

# use all cores

cl <- makePSOCKcluster(detectCores())

registerDoParallel(cl)

#-----------------------------------------------------------------------------------------#
# Computing
#-----------------------------------------------------------------------------------------#

tic()

closest_dark_points <- 
    
    foreach(
        i = 1:nrow(sky_brightness_df), 
        .combine = "bind_rows",
        .inorder = FALSE,
        .packages = c("dplyr", "tibble", "geosphere")
        
    ) %dopar% {
        
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
        # Each row
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
        
        selected_point <- sky_brightness_df[i,]
        
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
        # Winnowing down points to search through
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
        
        sky_brightness_df_dark_candidates <- 
            
            sky_brightness_df %>% 
            
            filter(round(sky_brightness, 1) == (round(selected_point$sky_brightness, 1) + 1))
        
        if (nrow(sky_brightness_df_dark_candidates) == 0) {
            
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
            # If no darker point, return NA
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
            
            sky_brightness_df_dark <- 
                tibble(
                    x_dark = NA_real_,
                    y_dark = NA_real_,
                    sky_brightness_dark = NA_real_
                ) %>% 
                bind_cols(selected_point, .)
            
        } else {
            
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
            # Compute distance between selected point and ~1 mag/arcsec^2 darker
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
            
            sky_brightness_df_dark <- 
                
                sky_brightness_df_dark_candidates %>% 
                
                mutate(
                    dist_from_loc = 
                        distGeo(
                            select(selected_point, x, y),
                            select(., x, y)
                        )
                ) %>% 
                
                # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
                # Keeping only the closest point
                # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
                
                arrange(dist_from_loc) %>% 
                slice(1) %>% 
                rename(x_dark = x, y_dark = y, sky_brightness_dark = sky_brightness) %>% 
                
                # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
                # Combining with selected point
                # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
                
                bind_cols(selected_point, .)
            
        }
        
    }

toc(log = TRUE)

gc()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Stopping cluster
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

stopCluster(cl)

#-----------------------------------------------------------------------------------------#
# Saving list of darker points
#-----------------------------------------------------------------------------------------#

write_rds(closest_dark_points, "data/closest_dark_points.rds", compress = "gz")

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

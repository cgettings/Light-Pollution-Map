
addEasyButtonNoFaDeps <- 
    function (map, button) {
        if (!inherits(button, "leaflet_easybutton")) {
            stop("button should be created with easyButton()")
        }
        map$dependencies <- c(map$dependencies, leaflet:::leafletEasyButtonDependencies())
        if (is.null(button$states)) {
            # if (grepl("fa-", button$icon)) 
            #     map$dependencies <- c(map$dependencies, leaflet:::leafletAmFontAwesomeDependencies())
            if (grepl("glyphicon-", button$icon)) 
                map$dependencies <- c(map$dependencies, leaflet:::leafletAmBootstrapDependencies())
            if (grepl("ion-", button$icon)) 
                map$dependencies <- c(map$dependencies, leaflet:::leafletAmIonIconDependencies())
        }
        else {
            # if (any(sapply(button$states, function(x) grepl("fa-", 
            #                                                 x$icon)))) 
            #     map$dependencies <- c(map$dependencies, leaflet:::leafletAmFontAwesomeDependencies())
            if (any(sapply(button$states, function(x) grepl("glyphicon-", 
                                                            x$icon)))) 
                map$dependencies <- c(map$dependencies, leaflet:::leafletAmBootstrapDependencies())
            if (any(sapply(button$states, function(x) grepl("ion-", 
                                                            x$icon)))) 
                map$dependencies <- c(map$dependencies, leaflet:::leafletAmIonIconDependencies())
        }
        invokeMethod(map, getMapData(map), "addEasyButton", button)
    }

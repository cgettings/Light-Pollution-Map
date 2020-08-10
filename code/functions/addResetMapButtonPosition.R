
addResetMapButtonPosition <- 
    function(map, position = "topleft") {
        map %>% 
            addEasyButtonNoFaDeps(
                easyButton(
                    icon = "fa-compress",
                    title = "Reset View",
                    onClick = JS("function(btn, map){ map.setView(map._initialCenter, map._initialZoom); }"),
                    position = position
                )) %>%
            htmlwidgets::onRender(
                JS(
                    paste0(
                        "function(el, x){ var map = this;",
                        "map._initialCenter = map.getCenter(); ",
                        "map._initialZoom = map.getZoom();",
                        "}"
                    )
                )
            )
    }


// renaming map object

var map = this;


// #=============================================================================#
// # processing  data
// #=============================================================================#

// creating variable to store grid coordinates pulled from data

var grid_coords = [];

// looping through all coords in data

for (var i = 0; i < data.x.length; i++) {
    
    grid_coords[i] = new L.LatLng(data.y[i], data.x[i], data.sky_brightness[i]);
    
}


// #=============================================================================#
// # processing raster data
// #=============================================================================#

// getting raster data from document via href, to identify the brightness value at the click point
//  (originally provided through `leafem::addGeoRaster`)

var data_fl = document.getElementById("raster" + "-1-attachment").href;

// parsing data, then passing it to a bunch of things

fetch(data_fl)
    
    // because data comes from HTML doc, need to get it from http response
    
    .then(response => response.arrayBuffer())
    .then(arrayBuffer => {
    
    // actually parsing
    
    parseGeoraster(arrayBuffer).then(georaster => {
        
        // `parseGeoraster` is asynchronous, and results in a promise, which all georaster docs 
        //  evaluate by means of sending it to the console. This makes it a local variable inside
        //  the `then` function environment.
        
        console.log("georaster:", georaster);
        
        // creating variables for markers and line here, outside the "on click" environment, so that i can 
        //  remove them when a new one is added
        
        var selected_point_marker = null;
        var dark_point_marker = null;
        var selected_dark_line = null;
        
        // #=============================================================================#
        // # doing a bunch of stuff on click.
        // #=============================================================================#
        
        //  the "on" function creates a click event, which creates an object (usually named "e") containing 
        //  all the information about that click event
        
        map.on("click", function(e) {
            
            // if there are already markers on the map (because it's already been clicked), then
            //  remove them before adding new ones on this click
            
            if (selected_point_marker) map.removeLayer(selected_point_marker);
            if (dark_point_marker) map.removeLayer(dark_point_marker);
            if (selected_dark_line) map.removeLayer(selected_dark_line);
            
            // setting icon properties for awesome marker
            
            var selected_point_icon = 
                L.ExtraMarkers.icon({
                    icon: "fa-bullseye",
                    iconColor: "#000000",
                    prefix: "fa",
                    markerColor: "#34FEF1",
                    shape: 'circle',
                    svg: true
            });            
            
            // getting the (interpolated) brightness value at the click point, in [lng, lat] form
            //  (it's an array, not a scalar, so you need to extract it with "[0]")
            
            const selected_brightness = geoblaze.identify(georaster, [e.latlng.lng, e.latlng.lat])[0];
            
            // adding a marker for the click point, and creating a Tooltip with details about the click point
            //  (toFixed(2) is how you round numbers to 2 decimal places)
            
            selected_point_marker = 
                L.marker(e.latlng, {"icon": selected_point_icon})
                    .addTo(map)
                    .bindTooltip(
                        
                        "<span style='font-family:sans-serif;font-size:130%;font-weight:bold'>" + 
                        "mag: " + selected_brightness.toFixed(2) + 
                        "</span>" + 
                        "<br>" +
                        
                        "<span style='font-family:monospace;font-size:115%;'>" + 
                        e.latlng.lat.toFixed(2) + ", " + e.latlng.lng.toFixed(2) +
                        "</span>", 
                        
                        {offset: [0, 0], sticky: false, permanent: true}
                        
                    ).openTooltip();
            
            
            // creating a function that will filter brightness values
            
            function dark_points (grid_coords) {
                
                return grid_coords.alt >= (selected_brightness + 1) && grid_coords.alt <= (selected_brightness + 1.75);
                
                // in R, i used dplyr::between() here
            }
            
            // applying the filtering function to the data
            
            var grid_coords_filtered = grid_coords.filter(dark_points);
            
            
            // #=============================================================================#
            // # distance calculations
            // #=============================================================================#
            
            // creating variables for computed distances
            
            var results = [];
            var distance;
            
            // looping through all filtered points to get the distance values (`push` appends an array)
            
            for (var i = 0; i < grid_coords_filtered.length; i++) {
                
                distance = grid_coords_filtered[i].distanceTo(e.latlng);
                
                results.push({"point": i, "grid_point": grid_coords_filtered[i], "distance": distance});
                
            }
            
            // sorting the results, so I can pull out the top [x] values
            
            results.sort(function(a, b) { return a.distance - b.distance });
            
            // pulling out the top [x] values
            
            var dark_point = results[0];
            
            // formatting icon for dark point marker(s)
            
            var dark_point_icon = 
                L.ExtraMarkers.icon({
                    icon: "ion-star",
                    iconColor: "#FFFFFF",
                    prefix: "ion",
                    markerColor: "black",
                    shape: 'square',
                    svg: true
            });
            
            
            // if there is no darker point than the one clicked, don't do anything
            
            if (typeof dark_point !== "undefined") {
                
                // Sending dark point info to console ---------------------------------------//
                
                console.log(
                    {
                        "Click point:": {
                            "lat": [e.latlng.lat], 
                            "lng": [e.latlng.lng],
                            "mag": [selected_brightness]
                        },
                        "Dark point:": {
                            "lat": [dark_point.grid_point.lat], 
                            "lng": [dark_point.grid_point.lng], 
                            "mag": [dark_point.grid_point.alt]
                        }
                    }
                );
                
                //---------------------------------------------------------------------------//
                
                // adding a marker at the darkest point(s)
                
                dark_point_marker = 
                    L.marker([dark_point.grid_point.lat, dark_point.grid_point.lng], {"icon": dark_point_icon})
                        .addTo(map)
                        .bindTooltip(
                            
                            "<span style='font-family:sans-serif;font-size:130%;font-weight:bold'>" + 
                            "mag: " + dark_point.grid_point.alt.toFixed(2) + 
                            "</span>" + 
                            "<br>" +
                            
                            "<span style='font-family:monospace;font-size:115%;'>" + 
                            dark_point.grid_point.lat.toFixed(2) + ", " + dark_point.grid_point.lng.toFixed(2), 
                            "</span>", 
                            
                            {offset: [0, 0], sticky: false, permanent: true}
                            
                        ).openTooltip();
                
                
                // adding polyline(s) between click point and dark point(s)
                
                selected_dark_line = 
                    L.polyline(
                        [
                            e.latlng, 
                            [dark_point.grid_point.lat, dark_point.grid_point.lng]
                        ], 
                        {"color": "black", "weight": 4, "opacity": 0.85}).addTo(map)
                        .bindTooltip(
                            
                            "<span style='font-family:sans-serif;font-size:115%'>" + 
                            (dark_point.distance/1000).toFixed(1) + " km", 
                            "</span>", 
                            
                            {sticky: false, permanent: true}
                            
                        ).openTooltip();
                
                // setting new bounds based on points
                
                both_points = [
                    e.latlng, 
                    [dark_point.grid_point.lat, dark_point.grid_point.lng]
                ];
                
                map.fitBounds(both_points, {"padding": [25, 25], "duration": 0.375, "zoomSnap": 0.5});
                
            }
            
        });
        
    // easyButton to clear the markers
    
    L.easyButton({
            position: "bottomleft",
            states: [{
                title: "Clear",
                icon: "fas fa-trash",
                
                onClick: function() {
                    if (selected_point_marker) map.removeLayer(selected_point_marker);
                    if (dark_point_marker) map.removeLayer(dark_point_marker);
                    if (selected_dark_line) map.removeLayer(selected_dark_line);
                }
                }]
    }).addTo(map);
    
    
    // easyButton to toggle the tooltips
    
    L.easyButton({
        position: "bottomleft",
        states: [{
            
            stateName: "tooltips-on",
            icon: "fa-comment-alt",
            title: "Tooltips: ON",
            
            onClick: function(control) {
                if (selected_point_marker && selected_point_marker.isTooltipOpen()) {
                    selected_point_marker.closeTooltip();
                }
                if (dark_point_marker && dark_point_marker.isTooltipOpen()) {
                    dark_point_marker.closeTooltip();
                }
                if (selected_dark_line && selected_dark_line.isTooltipOpen()) {
                    selected_dark_line.closeTooltip();
                }
                control.state("tooltips-off");
            }
        }, {
            
            stateName: "tooltips-off",
            icon: "<i class='fa' style='color:#BDBDBD'> &#xf27a </i>",
            title: "Tooltips: OFF",
            
            onClick: function(control) {
                if (selected_point_marker && !selected_point_marker.isTooltipOpen()) {
                    selected_point_marker.openTooltip();
                }
                if (dark_point_marker && !dark_point_marker.isTooltipOpen()) {
                    dark_point_marker.openTooltip();
                }
                if (selected_dark_line && !selected_dark_line.isTooltipOpen()) {
                    selected_dark_line.openTooltip();
                }
                control.state("tooltips-on");
            }
        }]
    }).addTo(map);

    });

});

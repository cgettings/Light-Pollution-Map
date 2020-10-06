
//=============================================================================//
// renaming map object
//=============================================================================//

map = this;

//=============================================================================//
// adding `div` for custom dark point control
//=============================================================================//

var controls = L.control({position: 'bottomright'});

controls.onAdd = function (map) {
    
    var div = L.DomUtil.create('div');
    
    // onclick = 'map.fire(\"change\");' fires an event called 'change' on button press, which is 
    //  picked up by a function that gets the values from the form fields
    
    // I will replace these 4 #'s with HTML in R'
    
    div.innerHTML = `####`;

    L.DomEvent.disableClickPropagation(div);
    
    return div;
    
};

controls.addTo(map);

//=============================================================================//
// processing raw data
//=============================================================================//

// creating variable to store grid coordinates pulled from data

grid_coords = [];

// looping through all coords in data

for (var i = 0; i < data.x.length; i++) {
    
    grid_coords[i] = new L.LatLng(data.y[i], data.x[i], data.sky_brightness[i]);
    
}


//=============================================================================//
// custom functions
//=============================================================================//

//------------------------------------------------------------------------------//
// selected point function
//------------------------------------------------------------------------------//

function selected_point_function(latlng, georaster) {
    
    //console.log(e);
    //console.log(latlng);
    //console.log(georaster);
    
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // clearing map
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    
    // if there are already markers on the map (because it's already been clicked), then
    //  remove them before adding new ones on this click
    
    if (map.layerManager.getLayerGroup('selected_point')) map.layerManager.clearGroup('selected_point');
    
    
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // setting icon properties for awesome marker
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    
    selected_point_icon = 
        L.ExtraMarkers.icon({
            icon: "fa-bullseye",
            iconColor: "#000000",
            prefix: "fa",
            markerColor: "#34FEF1",
            shape: 'circle',
            svg: true
    });
    
    
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // getting the (interpolated) brightness value at the click point, in [lng, lat]
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    
    //  (it's an array, not a scalar, so you need to extract it with "[0]")
    
    selected_brightness = 
        geoblaze.identify(
            georaster, 
            [latlng.lng, latlng.lat]
        )[0];
    
    
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // adding "Selected point" marker
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    
    // adding a marker for the click point, and creating a Tooltip with details about the click point
    //  (toFixed(2) is how you round numbers to 2 decimal places)
    
    map.layerManager.addLayer(
    
        L.marker(latlng, {"icon": selected_point_icon})
            .addTo(map)
            .bindTooltip(
                
                "<span style='font-family:sans-serif;font-size:120%;font-weight:bold;'>" + 
                "mag = " + selected_brightness.toFixed(2) + 
                "</span>" + 
                
                "<br>" +
                
                "<span style='font-family:monospace;font-size:115%;'>" + 
                latlng.lat.toFixed(2) + ", " + 
                latlng.lng.toFixed(2) +
                "</span>", 
                
                {offset: [0, 0], sticky: false, permanent: true, opacity: 0.9}
                
            ),
                
        'marker', 100, 'selected_point');
    
}

    
//------------------------------------------------------------------------------//
// Function to filter grid coords
//------------------------------------------------------------------------------//

// creating a function that will filter brightness values:
//
//  1 EV == 0.752575 mags (with K = 12.5), so I take however many EV's the
//  user wants the difference to be, and convert that into mags by multiplying
//  by 0.752575.
//
//  Returning all points that meet the threshold could return 10's of thousands of 
//  points, so to reduce proccessing overhead at the distance calculation step, 
//  I reduce the number of points by imposing a range of EV difference to return. 
//  It's very unlikely that the closest point will be +2 EVs away when there are points
//  that are +1 EV away, so I've made +2 EVs the top of the range. 
//
//  This is the subset of points that the script will search through to find the
//  closest point(s)


function grid_coords_filter_fun (grid_coords) {
    
    return grid_coords.alt >= 
            (selected_brightness + 
                (exposure_value * 0.752575)) && 
        
           grid_coords.alt <= 
            (selected_brightness + 
                (exposure_value * 0.752575) + (0.752575 * Math.sign(exposure_value))
            );
    
}

    
//------------------------------------------------------------------------------//
// Function to add dark points
//------------------------------------------------------------------------------//

function dark_point_function(e) {
    
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // getting value from controls (on click)
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    
    // This code will evaluate when the map is clicked, and when the "update" button is
    //  pressed on the custom control (which fires an event called "update" specified
    //  in the HTML)
    
    
    num_points_value = 
        document.getElementById('num_points').value !== '' ? 
        document.getElementById('num_points').value : 
        1;
    
    distance_value = 
        document.getElementById('distance').value !== '' ? 
        document.getElementById('distance').value : 
        Infinity;
    
    exposure_value = 
        document.getElementById('exposure').value !== '' ? 
        document.getElementById('exposure').value : 
        1;     

    num_points_value = Number(num_points_value);
    distance_value   = Number(distance_value);
    exposure_value   = Number(exposure_value);
    
    
    // applying the filtering function to the data
    
    grid_coords_filtered = grid_coords.filter(grid_coords_filter_fun);
    
    
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // distance calculations
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    
    // getting location of selected point
    
    selected_point_group = map.layerManager.getLayerGroup('selected_point');
    selected_point_loc = Object.values(selected_point_group._layers)[0].getLatLng();
    
    // creating variables for computed distances
    
    results = [];
    
    // looping through all filtered points to get the distance values (`push` appends an array)
    
    j = [];
    
    for (var j = 0; j < grid_coords_filtered.length; j++) {
        
        //distance = grid_coords_filtered[j].distanceTo(e.latlng);
        distance = grid_coords_filtered[j].distanceTo(selected_point_loc);
        
        results.push({"point": j, "grid_point": grid_coords_filtered[j], "distance": distance});
        
    }
    
    
    // sorting the results, so I can pull out the top [x] values
    
    results.sort(function(a, b) { return a.distance - b.distance });
    
    
    // filtering to get those within the requested distance
    
    results_filtered = [];
    
    results_filtered = results.filter(results => results.distance <= distance_value);
    
    
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // adding controls for # of points returned, distance to points, exposure diff
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    
    // pulling out the top [x] values
    
    dark_points = results.slice(0, num_points_value);
    
    
    // if there is no darker point than the one clicked, don't do anything
    
    if (typeof dark_points !== "undefined") {
        
        //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
        // adding "dark points" markers
        //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
        
        // formatting icon for dark point marker(s)
        
        dark_point_icon = 
            L.ExtraMarkers.icon({
                icon: "glyphicon-star",
                iconColor: "#34FEF1",
                prefix: "glyphicon",
                markerColor: "#595959",
                shape: "penta",
                svg: true
        });
        
        
        // clearing existing markers and lines
        
        if (map.layerManager.getLayerGroup('dark_points')) map.layerManager.clearGroup('dark_points');
        
        
        // adding dark points
        
        for (var k = 0; k < dark_points.length; k++) {
            
            // adding a marker at the darkest point(s)
            
            map.layerManager.addLayer(
                
                L.marker(
                    [dark_points[k].grid_point.lat, dark_points[k].grid_point.lng], 
                    {"icon": dark_point_icon})
                    .bindTooltip(
                        
                        "<span style='font-family:sans-serif;font-size:120%;font-weight:bold;'>" + 
                        "mag = " + dark_points[k].grid_point.alt.toFixed(2) + 
                        "</span>" + 
                        
                        "<br>" +
                        
                        "<span style='font-family:sans-serif;font-size:115%;font-weight:bold;'>" + 
                        "point: " + dark_points[k].point + 
                        "</span>" +
                        
                        "<br>" +
                        
                        "<span style='font-family:sans-serif;font-size:115%;'>" + 
                        (dark_points[k].distance/1000).toFixed(1) + " km" + 
                        "</span>" +
                        
                        "<br>" +
                        
                        "<span style='font-family:monospace;font-size:115%;'>" + 
                        dark_points[k].grid_point.lat.toFixed(2) + ", " + 
                        dark_points[k].grid_point.lng.toFixed(2) + 
                        "</span>", 
                        
                        {offset: [0, 0], sticky: false, permanent: true, opacity: 0.8}
                        
                    ),
            
                'marker', k, 'dark_points');
        
        }
        
        
        // sending dark point info to console
        
        console.log("dark_points:", dark_points);
        
        // opening all tooltips
        
        dark_points_group = map.layerManager.getLayerGroup('dark_points');
        dark_points_group.eachLayer(layer => layer.openTooltip());
        
    }
    
    selected_point_group.eachLayer(layer => layer.openTooltip());
    
    
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // on first click, set view to encompass all points
    //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    
    map.fitBounds(
        [
            map.layerManager.getLayerGroup('dark_points').getBounds(),
            map.layerManager.getLayerGroup('selected_point').getBounds()
        ], 
        {"padding": [25, 25], "duration": 0.5, "zoomSnap": 0.5}
    );
    
}


//=============================================================================//
// processing raster data
//=============================================================================//

// getting raster data from document via href, to identify the brightness value at the click point
//      (originally provided through `leafem::addGeoRaster`)

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
            
            
            //---------------------------------------------------------------------------//
            // adding selected point and dark points on click
            //---------------------------------------------------------------------------//
            
            //  the "on" function creates a click event, which creates an object (usually named "e") containing 
            //  all the information about that click event
            
            
            map.on("click", function (e) {
                
                selected_point_function(e.latlng, georaster);
                dark_point_function(e);
                    
            });
            
            
            //---------------------------------------------------------------------------//
            // updating dark points on 'update' event
            //---------------------------------------------------------------------------//
            
            // this is nexted inside the "click" event handler function, because that's
            //  the only way to expose the selected location tp the "update" event
            
            map.on('update', function (e) {
                                
                dark_point_function(e);
                
            });
            
            
            //---------------------------------------------------------------------------//
            // adding selected point based on location finding easyButton
            //---------------------------------------------------------------------------//
            
            L.easyButton({
                    position: "topleft",
                    states: [{
                        title: "Location",
                        icon: "fas fa-crosshairs",
                        
                        onClick: function(e) {
                        
                            map.locate();
                            
                            map.on(
                                'locationfound', 
                                function(e) {
                                    selected_point_function(e.latlng, georaster);
                                    dark_point_function(e);
                                });
                                
                            map.on(
                                'locationerror', 
                                function(e) {
                                    alert(e.message);
                                });
                        }
                    }]
            }).addTo(map);
            
            
            //---------------------------------------------------------------------------//
            // adding selected point based on OSM/Nominatim search
            //---------------------------------------------------------------------------//
            
            L.Control.geocoder(
                options = {
                    position: 'topleft',
                    showUniqueResult: false,
                    defaultMarkGeocode: false,
                    collapsed: true,
                    expand: "touch"
                }
            )
            .on(
                'markgeocode', 
                function(e) {
                    
                    console.log("selected search result:", e.geocode.properties);
                    
                    selected_point_function(e.geocode.center, georaster);
                    dark_point_function(e);
                    
                }
            )
            .addTo(map);
            
            
            //---------------------------------------------------------------------------//
            // easyButton focus on dark points
            //---------------------------------------------------------------------------//
            
            L.easyButton({
                position: "bottomleft",
                states: [{
                    
                    stateName: "all-zoom",
                    icon: "fas fa-star",
                    title: "Zoom to dark points",
                    
                    onClick: function(control) {
                        
                        if (map.layerManager.getLayerGroup('dark_points')) {
                            
                            map.fitBounds(
                                map.layerManager.getLayerGroup('dark_points').getBounds(), 
                                {"padding": [25, 25], "duration": 0.5, "zoomSnap": 0.5}
                            )}
                            
                        control.state("dark-point-zoom");
                        }
                }, {
                    
                    stateName: "dark-point-zoom",
                    icon: "far fa-circle",
                    title: "Zoom to all points",
                    
                    onClick: function(control) {
                        
                        if (map.layerManager.getLayerGroup('dark_points') && 
                            map.layerManager.getLayerGroup('selected_point')) {
                            
                            map.fitBounds(
                                [
                                    map.layerManager.getLayerGroup('dark_points').getBounds(),
                                    map.layerManager.getLayerGroup('selected_point').getBounds()
                                ], 
                                {"padding": [25, 25], "duration": 0.5, "zoomSnap": 0.5}
                            )}
                            
                        control.state("all-zoom");
                        }
                }]
            }).addTo(map);
            
    
            //---------------------------------------------------------------------------//
            // easyButton to clear the markers and lines
            //---------------------------------------------------------------------------//
            
            L.easyButton({
                    position: "bottomleft",
                    states: [{
                        title: "Clear",
                        icon: "fas fa-trash",
                        
                        onClick: function() {
                            
                            if (map.layerManager.getLayerGroup('selected_point')) {
                                map.layerManager.clearGroup('selected_point');
                                
                            }
                            if (map.layerManager.getLayerGroup('dark_points')) {
                                map.layerManager.clearGroup('dark_points');
                                
                            }
                        }
                    }]
            }).addTo(map);
            
            
            //---------------------------------------------------------------------------//
            // easyButton to toggle the tooltips
            //---------------------------------------------------------------------------//
            
            L.easyButton({
                position: "bottomleft",
                states: [{
                    
                    stateName: "tooltips-on",
                    icon: "fa-comment-alt",
                    title: "Tooltips: ON",
                    
                    onClick: function(control) {
                        
                        // checking if these layer groups exist
                        
                        var selected_point_group = map.layerManager.getLayerGroup('selected_point');
                        var dark_points_group = map.layerManager.getLayerGroup('dark_points');
                        
                        // close open tooltips if the layers exist
                        
                        if (selected_point_group) selected_point_group.eachLayer(layer => layer.closeTooltip());
                        if (dark_points_group) dark_points_group.eachLayer(layer => layer.closeTooltip());
                        
                        control.state("tooltips-off");
                        
                    }
                }, {
                    
                    stateName: "tooltips-off",
                    icon: "<i class='fa' style='color:#BDBDBD'> &#xf27a </i>",
                    title: "Tooltips: OFF",
                    
                    onClick: function(control) {
                        
                        // checking if these layer groups exist
                        
                        var selected_point_group = map.layerManager.getLayerGroup('selected_point');
                        var dark_points_group = map.layerManager.getLayerGroup('dark_points');
                        
                        // open closed tooltips if the layers exist
                        
                        if (selected_point_group) selected_point_group.eachLayer(layer => layer.openTooltip());
                        if (dark_points_group) dark_points_group.eachLayer(layer => layer.openTooltip());
                        
                        control.state("tooltips-on");
                    }
                }]
            }).addTo(map);

        });

});


// --------------------------------- THIS IS THE END! --------------------------------- //

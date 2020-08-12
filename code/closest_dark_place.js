
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
            
            var slider = null;
            
            // #=============================================================================#
            // # doing a bunch of stuff on click.
            // #=============================================================================#
            
            //  the "on" function creates a click event, which creates an object (usually named "e") containing 
            //  all the information about that click event
            
            map.on("click", function(e) {
                
                //------------------------------------------------------------------------------
                // clearing map
                //------------------------------------------------------------------------------
                
                // if there are already markers on the map (because it's already been clicked), then
                //  remove them before adding new ones on this click
                
                if (map.layerManager.getLayerGroup('selected_point')) map.layerManager.clearGroup('selected_point');
                if (map.layerManager.getLayerGroup('dark_points')) map.layerManager.clearGroup('dark_points');
                if (map.layerManager.getLayerGroup('dark_lines')) map.layerManager.clearGroup('dark_lines');
                if (slider) map.removeControl(slider);
                
                
                //------------------------------------------------------------------------------
                // adding "Selected point" marker
                //------------------------------------------------------------------------------
                
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
                
                map.layerManager.addLayer(

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
                            
                            {offset: [0, 0], sticky: false, permanent: true, opacity: 0.9}
                            
                        ),
                            
                    'marker', 100, 'selected_point');
                
                
                // creating a function that will filter brightness values
                
                function dark_points (grid_coords) {
                    
                    return grid_coords.alt >= (selected_brightness + 1) && grid_coords.alt <= (selected_brightness + 1.75);
                    
                    // in R, i used dplyr::between() here
                }
                
                // applying the filtering function to the data
                
                var grid_coords_filtered = grid_coords.filter(dark_points);
                
                
                //------------------------------------------------------------------------------
                // distance calculations
                //------------------------------------------------------------------------------
                
                // creating variables for computed distances
                
                var results = [];
                var distance;
                
                // looping through all filtered points to get the distance values (`push` appends an array)
                
                for (var j = 0; j < grid_coords_filtered.length; j++) {
                    
                    distance = grid_coords_filtered[j].distanceTo(e.latlng);
                    
                    results.push({"point": j, "grid_point": grid_coords_filtered[j], "distance": distance});
                    
                }
                
                // sorting the results, so I can pull out the top [x] values
                
                results.sort(function(a, b) { return a.distance - b.distance });
                
                // pulling out the top [x] values
                
                
                //------------------------------------------------------------------------------
                // adding slider to control # of points returned
                //------------------------------------------------------------------------------
                
                // all operations that add markers and compute distances need to be inside this 
                //  slider control function
                
                slider = L.control.slider(function(value) {
                    
                    var dark_point = results.slice(0, value);
                    
                    // if there is no darker point than the one clicked, don't do anything
                    
                    if (typeof dark_point !== "undefined") {
                        
                        //------------------------------------------------------------------------------
                        // Sending dark point info to console 
                        //------------------------------------------------------------------------------
                        
                        //console.log(
                        //    {
                        //        "Click point:": {
                        //            "lat": [e.latlng.lat], 
                        //            "lng": [e.latlng.lng],
                        //            "mag": [selected_brightness]
                        //        },
                        //        "Dark point:": {
                        //            "lat": [dark_point.grid_point.lat], 
                        //            "lng": [dark_point.grid_point.lng], 
                        //            "mag": [dark_point.grid_point.alt]
                        //        }
                        //    }
                        //);
                        
                        //------------------------------------------------------------------------------
                        // adding "dark points" markers
                        //------------------------------------------------------------------------------
                        
                        // formatting icon for dark point marker(s)
                        
                        var dark_point_icon = 
                            L.ExtraMarkers.icon({
                                icon: "glyphicon-star",
                                iconColor: "#34FEF1",
                                prefix: "glyphicon",
                                markerColor: "#595959",
                                shape: "penta",
                                svg: true
                        });
                        
                        // clearning existing markers and lines
                        
                        if (map.layerManager.getLayerGroup('dark_points')) map.layerManager.clearGroup('dark_points');
                        if (map.layerManager.getLayerGroup('dark_lines')) map.layerManager.clearGroup('dark_lines');
                        
                        
                        for (var k = 0; k < dark_point.length; k++) {
                            
                            // adding a marker at the darkest point(s)
                            
                            map.layerManager.addLayer(
                                
                                L.marker(
                                    [dark_point[k].grid_point.lat, dark_point[k].grid_point.lng], 
                                    {"icon": dark_point_icon})
                                    .bindTooltip(
                                        
                                        "<span style='font-family:sans-serif;font-size:130%;font-weight:bold'>" + 
                                        "mag: " + dark_point[k].grid_point.alt.toFixed(2) + 
                                        "</span>" + 
                                        "<br>" +
                                        
                                        "<span style='font-family:monospace;font-size:115%;font-weight:bold'>" + 
                                        (dark_point[k].distance/1000).toFixed(1) + " km" + 
                                        "</span>" +
                                        "<br>" +
                                        
                                        "<span style='font-family:monospace;font-size:115%;'>" + 
                                        dark_point[k].grid_point.lat.toFixed(2) + ", " + 
                                        dark_point[k].grid_point.lng.toFixed(2) + 
                                        "</span>", 
                                        
                                        {offset: [0, 0], sticky: false, permanent: true, opacity: 0.8}
                                        
                                    ),
                            
                                'marker', k, 'dark_points');
                            
                            
                            // adding polyline(s) between click point and dark point(s)
                            
                            map.layerManager.addLayer(
                                
                                L.polyline(
                                    [
                                        e.latlng, 
                                        [dark_point[k].grid_point.lat, dark_point[k].grid_point.lng]
                                    ], 
                                    {"color": "black", "weight": 3, "opacity": 0.85}),
                                
                                'polyline', k, 'dark_lines');
                        
                        }
                        
                        // opening all tooltips
                        
                        var selected_point_group =  map.layerManager.getLayerGroup('selected_point');
                        var dark_points_group =  map.layerManager.getLayerGroup('dark_points');
                        var dark_lines_group =  map.layerManager.getLayerGroup('dark_lines');
                        
                        selected_point_group.eachLayer(layer => layer.openTooltip());
                        dark_points_group.eachLayer(layer => layer.openTooltip());
                        dark_lines_group.eachLayer(layer => layer.openTooltip());
                        
                }
            
                }, {
            	max: 10,
            	value: 1,
            	step:1,
            	size: '250px',
            	orientation: 'horizontal',
            	id: 'point_count_slider',
            	logo: '#',
            	collapsed: true,
            	syncSlider: true,
            	title: 'Number of dark points shown',
            	increment: true
                
            }).addTo(map);
        

        //---------------------------------------------------------------------------//
        // on first click, set view to encompass all points
        //---------------------------------------------------------------------------//
        
        var selected_point_group = map.layerManager.getLayerGroup('selected_point');
        var dark_points_group = map.layerManager.getLayerGroup('dark_points');
        
        map.fitBounds(
            [
                map.layerManager.getLayerGroup('dark_points').getBounds(),
                map.layerManager.getLayerGroup('selected_point').getBounds()
            ], 
            {"padding": [25, 25], "duration": 0.5, "zoomSnap": 0.5}
        );
        
        });
     

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
                        if (map.layerManager.getLayerGroup('dark_lines')) {
                            map.layerManager.clearGroup('dark_lines');
                            
                        }
                        if (slider) map.removeControl(slider);
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
                    var dark_lines_group = map.layerManager.getLayerGroup('dark_lines');
                    
                    // close open tooltips if the layers exist
                    
                    if (selected_point_group) selected_point_group.eachLayer(layer => layer.closeTooltip());
                    if (dark_points_group) dark_points_group.eachLayer(layer => layer.closeTooltip());
                    if (dark_lines_group) dark_lines_group.eachLayer(layer => layer.closeTooltip());
                    
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
                    var dark_lines_group = map.layerManager.getLayerGroup('dark_lines');
                    
                    // open closed tooltips if the layers exist
                    
                    if (selected_point_group) selected_point_group.eachLayer(layer => layer.openTooltip());
                    if (dark_points_group) dark_points_group.eachLayer(layer => layer.openTooltip());
                    if (dark_lines_group) dark_lines_group.eachLayer(layer => layer.openTooltip());
                    
                    control.state("tooltips-on");
                }
            }]
        }).addTo(map);

    });

});

# Light Pollution Heat Map for the Northeast US

## Overview

This map shows the brightness<sup id="note1">[1](#footnote1)</sup> of the night sky from Maryland to Maine, constructed using [Leaflet](https://leafletjs.com/), mostly via the [`{leaflet}`](https://rstudio.github.io/leaflet/) package in R and its extension packages. Click anywhere on the map, and you'll get (by default) the closest single point that is at least 1 [Exposure Value (EV)](https://en.wikipedia.org/wiki/Exposure_value#EV_as_a_measure_of_luminance_and_illuminance) darker than the clicked point.<sup id="note2">[2](#footnote2)</sup> You can use the "dark point properties" control to change: the number of dark points, their EV difference from the clicked point, and their maximum distance away.

My inspiration was the awesome [lightpollutionmap.info](https://www.lightpollutionmap.info/#zoom=5.34&lat=5329996&lon=-8358608&layers=B0FFFFFTFFFFFFFFF),<sup id="note3">[3](#footnote3)</sup> my deep dislike of rainbow color palettes, and my desire to take some good star photos in the Catskills. Data were downloaded from [*Supplement to: The New World Atlas of Artificial Night Sky Brightness*](http://doi.org/10.5880/GFZ.1.4.2016.001).<sup id="note4">[4](#footnote4)</sup>

**The map is available at: https://cgettings.github.io/Light-Pollution-Map/**

## Screenshot

[![Screenshot of map](map_screenshot.png)](map_screenshot.png)

## Code

[R](/code/Light_Pollution_Map.R)<br>
[JavaScript](/code/closest_dark_place.js)<br>

### Data processing

The sky brightness data comes from a whole-world geotiff file of simulated zenith radiance data, given in `mcd/m^2`. I read the file into R as a `RasterLayer` using `raster::raster()`, which avoids loading the whole 2.8 GB file into memory. I then crop it using a bounding box that contains the states I'm mapping, and then convert the cropped raster into a [`stars` object](https://r-spatial.github.io/stars/), which loads it into memory. This allows me to use `{sf}` methods to further crop the raster using state boundary data from the [`{tigris}` package](https://github.com/walkerke/tigris). Finally, I convert the `stars` object into a `tbl`, convert luminance (`mcd/m^2`) to magnitude (`mag/arcsec^2`),<sup id="note5">[5](#footnote5)</sup> and then turn the tibble back into a `stars` object for mapping.

### Mapping

#### R

I create the map using `{leaflet}` and `addProviderTiles()`, with a custom tile layer drawn from the "USA_Topo_Maps" esri tile layer hosted on [ArcGIS online](https://services.arcgisonline.com/ArcGIS/rest/services/USA_Topo_Maps/MapServer/). I then add the `stars` raster to the map using `leafem::addGeoRaster()`, specifying colors using the `viridisLite::inferno()` palette, with breaks [computed](/code/Light_Pollution_Map.R#L320) so that qualitatively different colors roughly map onto the breaks between [Crumey's sky quality bands](https://academic.oup.com/mnras/article/442/3/2600/1052389#18902351): respectively, *Pristine vs. Black* (purple), *Black vs. Grey* (maroon), *Grey vs. Bright* (orange), and *Bright vs. White* (yellow). 

I add the brightness mousover display using `leafem::addImageQuery()`, the OSM search using `leaflet.extras::addSearchOSM()`, and the map view reset botton by [modifying](/code/functions/addResetMapButtonPosition.R) `leaflet.extras::addResetMapButton()` to simply add a `position` argument to the `easyButton()` call. Finally, I add map dependencies using the [`registerPlugin`](http://rstudio.github.io/leaflet/extending.html) and `leaflet.extras::addAwesomeMarkersDependencies()` functions, and then pass my custom JavaScript and a `tbl` of raw raster data to `htmlwidgets::onRender()`.

#### JavaScript

This [custom JavaScript](/code/closest_dark_place.js) uses the raster data I passed to `htmlwidgets::onRender()`, along with the already-rendered map layer, to find the dark points.

First, the script converts the raw raster data to `LatLng` points, with the magnitude value saved as the `alt[itude]` property. It then re-reads the raster layer data from the `DOM` using `fetch`, then uses the `georaster` package (already loaded thanks to `leafem::addGeoRaster()`) to parse the data.<sup id="note6">[6](#footnote6)</sup> The script then uses the [`geoblaze` package](https://github.com/GeoTIFF/geoblaze) to extract the magnitude value from where the raster was clicked.

Using that value, the script by default finds all points in the raw raster data that are between 1 and 2<sup id="note7">[7](#footnote7)</sup> EVs darker than the clicked point. 

Using the custom control, the user can change this value, and even find points that are brighter (i.e., negative values). The control's values are read from the DOM on the "click" event, or on the "update" event, which is fired by clicking on the control's "update" button.

The script then uses Leaflet's built-in `distanceTo` function to compute the distance between the clicked point and the filtered dark points, and finally selects the closest single point (the default), or as many as the user specifies, potentially within a specified maximum distance.

These points are then displayed on the map, with tooltips giving their brightness, distance, and coordinates; the unformatted values are also sent to the console (accessible via "Developer tools" in a web browser) as `LatLng` objects.

---

**TODO:** Add options to:

* ~Show more than 1 dark point~
* ~Show darkest point(s) within a specified radius of clicked point~
* ~Change magnitude difference between clicked point and dark points~
* Find dark points where specified celestial objects are visible<sup id="note8">[8](#footnote8)</sup>
* ~Add explanation re: heat map color gradient~
* Add more/better search functionality.

---

<a name="footnote1">1.</a> Sky brightness values are in `mag/arcsec^2`. Explanation [here](https://en.wikipedia.org/wiki/Surface_brightness). [↩](#note1)<br>
<a name="footnote2">2.</a> In practical terms, this means that you could e.g. find locations where a 2-second camera exposure had the same background sky brightness as a 1-second exposure at your original location. [↩](#note2)<br>
<a name="footnote3">3.</a> Shout out to [Dan Jentzen](https://www.brighterboston.org/staff) for introducing me to this website. [↩](#note3)<br>
<a name="footnote4">4.</a> Falchi, Fabio; Cinzano, Pierantonio; Duriscoe, Dan; Kyba, Christopher C. M.; Elvidge, Christopher D.; Baugh, Kimberly; Portnov, Boris; Rybnikova, Nataliya A.; Furgoni, Riccardo (2016): Supplement to: The New World Atlas of Artificial Night Sky Brightness. V. 1.1. GFZ Data Services. http://doi.org/10.5880/GFZ.1.4.2016.001 <br>
Falchi F, Cinzano P, Duriscoe D, Kyba CC, Elvidge CD, Baugh K, Portnov BA, Rybnikova NA, Furgoni R. The new world atlas of artificial night sky brightness. Science Advances. 2016 Jun 1;2(6). http://dx.doi.org/10.1126/sciadv.1600377[↩](#note4) <br>
<a name="footnote5">5.</a> Because these luminance values represent only *artificial* brightness, I add `0.171168465` to each value before converting it, copying the procedure of lightpollutionmap.info. This ensures that a luminance of 0 produces a magnitude of 22.0, which is the darkest value on common light pollution scales (labeled ["Excellent"](https://en.wikipedia.org/wiki/Bortle_scale) or ["Pristine"](https://academic.oup.com/mnras/article/442/3/2600/1052389#18902351)) [↩](#note5)<br>
<a name="footnote6">6.</a> This is necessary because the raster data object created by `leafem::addGeoRaster()` only exists within the scope of the function call that adds the georaster layer. [↩](#note6)<br>
<a name="footnote7">7.</a> Technically, it's "EV diff value + 1 EV". This is a mostly arbitrary cutoff that reduces processing demands. Note that if a user is searching for *brighter* points, this range will include points 1-2 EVs brighter, because the script accounts for the sign of the EV control. [↩](#note7)<br>
<a name="footnote8">8.</a> More information available [here](https://en.wikipedia.org/wiki/Naked_eye#In_astronomy). [↩](#note8)<br>

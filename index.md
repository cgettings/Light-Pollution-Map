---
pagetitle: Light Pollution Map
---

<!-- I'm specifying these basic HTML properties here in the markdown doc. This will force the map to render as full screen with no borders. I'm letting RStudio's conversion to HTML take care of the actual rendering. Magic! -->  
  
<meta name="viewport" content="width=device-width, initial-scale=1.0">
  
<head>
    <style>
        body {
            margin: 0px;
            border: 0px;
            padding: 0px;
        }
        #map {
            height: 100%;
            width: 100%;
            position: fixed;
            top: 0;
            left: 0;
        }
    </style>
</head>

<iframe id="map" src="plots/light_pollution_heatmap_georaster.html" style="border:none; background:none"> </iframe>

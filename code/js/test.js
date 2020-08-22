
var update = function(value){
    return value;
};

var className = 'leaflet-control-slider';
this._container = L.DomUtil.create('div', className + ' ' +className + '-' + this.options.orientation);
this._sliderLink = L.DomUtil.create('a', className + '-toggle', this._container);

this._sliderContainer = L.DomUtil.create('div', 'leaflet-slider-container', this._container);
this.slider = L.DomUtil.create('input', 'leaflet-slider', this._sliderContainer);

var _updateValue = function () {
    
    this.update(this.slider.value);
};


L.DomEvent.on(
    this.slider, 
    "change", 
    function (e) {
        this._updateValue();
    }, 
    this
);


L.DomEvent.disableClickPropagation(this._container);

if (this.options.collapsed) {
    if (!L.Browser.android) {
        L.DomEvent
            .on(this._container, 'mouseenter', this._expand, this)
            .on(this._container, 'mouseleave', this._collapse, this);
    }

    if (L.Browser.touch) {
        L.DomEvent
            .on(this._sliderLink, 'click', L.DomEvent.stop)
            .on(this._sliderLink, 'click', this._expand, this);
    } else {
        L.DomEvent.on(this._sliderLink, 'focus', this._expand, this);
    }
} else {
    this._expand();
}


this.slider.setAttribute("title", this.options.title);
this.slider.setAttribute("id", this.options.id);
this.slider.setAttribute("type", "range");
this.slider.setAttribute("min", this.options.min);
this.slider.setAttribute("max", this.options.max);
this.slider.setAttribute("step", this.options.step);
this.slider.setAttribute("value", this.options.value);


    map.on(
        'click',
        function(e) {
            map.layerManager.addLayer(
                L.marker(e.latlng).addTo(map),
            'marker', 100, 'selected_point');
        }
    );


this._sliderValue = L.DomUtil.create('p', className+'-value', this._container);
this._sliderValue.innerHTML = this.options.getValue(this.options.value);








const num_points = document.getElementById('num_points');

num_points.addEventListener('input', (event) => {
    
    const num_points_value = document.getElementById('num_points_value');
    
    num_points_value.textContent = `${event.target.value}`;
    
});





selectElement.addEventListener('change', (event) => {
    
  const result = document.querySelector('.result');
  
  result.textContent = `You like ${event.target.value}`;
});







const num_points = document.getElementById('num_points');

num_points.addEventListener('input', (event) => {
    
    const num_points_value = document.getElementById('num_points_value');
    
    num_points_value.textContent = `${event.target.value}`;
    
});

function updateValue(e) {
  num_points_value.textContent = e.target.value;
}




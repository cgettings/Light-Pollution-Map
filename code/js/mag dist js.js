

var className = 'leaflet-control-input';
this._container = L.DomUtil.create('div', className);
this._sliderLink = L.DomUtil.create('a', className + '-toggle', this._container);

this._sliderContainer = L.DomUtil.create('div', 'leaflet-slider-container', this._container);
this.slider = L.DomUtil.create('input', 'leaflet-slider', this._sliderContainer);

this.slider.setAttribute("title", this.options.title);

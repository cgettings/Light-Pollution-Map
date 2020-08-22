
// this._container = overall '<div>' element
// this._container : class = 'leaflet-control-slider'

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

_expand = function () {
    L.DomUtil.addClass(this._container, 'leaflet-control-slider-expanded');
};

_collapse = function () {
    L.DomUtil.removeClass(this._container, 'leaflet-control-slider-expanded');
};

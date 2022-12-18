
var LayerManager = /*#__PURE__*/function () {
  function LayerManager(map) {
    _classCallCheck(this, LayerManager);

    this._map = map; // BEGIN layer indices
    // {<groupname>: {<stamp>: layer}}

    this._byGroup = {}; // {<categoryName>: {<stamp>: layer}}

    this._byCategory = {}; // {<categoryName_layerId>: layer}

    this._byLayerId = {}; // {<stamp>: {
    //             "group": <groupname>,
    //             "layerId": <layerId>,
    //             "category": <category>,
    //             "container": <container>
    //           }
    // }

    this._byStamp = {}; // {<crosstalkGroupName>: {<key>: [<stamp>, <stamp>, ...], ...}}

    this._byCrosstalkGroup = {}; // END layer indices
    // {<categoryName>: L.layerGroup}

    this._categoryContainers = {}; // {<groupName>: L.layerGroup}

    this._groupContainers = {};
  }

  _createClass(LayerManager, [{
    key: "addLayer",
    value: function addLayer(layer, category, layerId, group, ctGroup, ctKey) {
      var _this = this;

      // Was a group provided?
      var hasId = typeof layerId === "string";
      var grouped = typeof group === "string";
      var stamp = _leaflet2["default"].Util.stamp(layer) + ""; // This will be the default layer group to add the layer to.
      // We may overwrite this let before using it (i.e. if a group is assigned).
      // This one liner creates the _categoryContainers[category] entry if it
      // doesn't already exist.

      var container = this._categoryContainers[category] = this._categoryContainers[category] || _leaflet2["default"].layerGroup().addTo(this._map);

      var oldLayer = null;

      if (hasId) {
        // First, remove any layer with the same category and layerId
        var prefixedLayerId = this._layerIdKey(category, layerId);

        oldLayer = this._byLayerId[prefixedLayerId];

        if (oldLayer) {
          this._removeLayer(oldLayer);
        } // Update layerId index


        this._byLayerId[prefixedLayerId] = layer;
      } // Update group index


      if (grouped) {
        this._byGroup[group] = this._byGroup[group] || {};
        this._byGroup[group][stamp] = layer; // Since a group is assigned, don't add the layer to the category's layer
        // group; instead, use the group's layer group.
        // This one liner creates the _groupContainers[group] entry if it doesn't
        // already exist.

        container = this.getLayerGroup(group, true);
      } // Update category index


      this._byCategory[category] = this._byCategory[category] || {};
      this._byCategory[category][stamp] = layer; // Update stamp index

      var layerInfo = this._byStamp[stamp] = {
        layer: layer,
        group: group,
        ctGroup: ctGroup,
        ctKey: ctKey,
        layerId: layerId,
        category: category,
        container: container,
        hidden: false
      }; // Update crosstalk group index

      if (ctGroup) {
        if (layer.setStyle) {
          // Need to save this info so we know what to set opacity to later
          layer.options.origOpacity = typeof layer.options.opacity !== "undefined" ? layer.options.opacity : 0.5;
          layer.options.origFillOpacity = typeof layer.options.fillOpacity !== "undefined" ? layer.options.fillOpacity : 0.2;
        }

        var ctg = this._byCrosstalkGroup[ctGroup];

        if (!ctg) {
          ctg = this._byCrosstalkGroup[ctGroup] = {};
          var crosstalk = global.crosstalk;

          var handleFilter = function handleFilter(e) {
            if (!e.value) {
              var groupKeys = Object.keys(ctg);

              for (var i = 0; i < groupKeys.length; i++) {
                var key = groupKeys[i];
                var _layerInfo = _this._byStamp[ctg[key]];

                _this._setVisibility(_layerInfo, true);
              }
            } else {
              var selectedKeys = {};

              for (var _i = 0; _i < e.value.length; _i++) {
                selectedKeys[e.value[_i]] = true;
              }

              var _groupKeys = Object.keys(ctg);

              for (var _i2 = 0; _i2 < _groupKeys.length; _i2++) {
                var _key = _groupKeys[_i2];
                var _layerInfo2 = _this._byStamp[ctg[_key]];

                _this._setVisibility(_layerInfo2, selectedKeys[_groupKeys[_i2]]);
              }
            }
          };

          var filterHandle = new crosstalk.FilterHandle(ctGroup);
          filterHandle.on("change", handleFilter);

          var handleSelection = function handleSelection(e) {
            if (!e.value || !e.value.length) {
              var groupKeys = Object.keys(ctg);

              for (var i = 0; i < groupKeys.length; i++) {
                var key = groupKeys[i];
                var _layerInfo3 = _this._byStamp[ctg[key]];

                _this._setOpacity(_layerInfo3, 1.0);
              }
            } else {
              var selectedKeys = {};

              for (var _i3 = 0; _i3 < e.value.length; _i3++) {
                selectedKeys[e.value[_i3]] = true;
              }

              var _groupKeys2 = Object.keys(ctg);

              for (var _i4 = 0; _i4 < _groupKeys2.length; _i4++) {
                var _key2 = _groupKeys2[_i4];
                var _layerInfo4 = _this._byStamp[ctg[_key2]];

                _this._setOpacity(_layerInfo4, selectedKeys[_groupKeys2[_i4]] ? 1.0 : 0.2);
              }
            }
          };

          var selHandle = new crosstalk.SelectionHandle(ctGroup);
          selHandle.on("change", handleSelection);
          setTimeout(function () {
            handleFilter({
              value: filterHandle.filteredKeys
            });
            handleSelection({
              value: selHandle.value
            });
          }, 100);
        }

        if (!ctg[ctKey]) ctg[ctKey] = [];
        ctg[ctKey].push(stamp);
      } // Add to container


      if (!layerInfo.hidden) container.addLayer(layer);
      return oldLayer;
    }
  }, {
    key: "brush",
    value: function brush(bounds, extraInfo) {
      var _this2 = this;

      /* eslint-disable no-console */
      // For each Crosstalk group...
      Object.keys(this._byCrosstalkGroup).forEach(function (ctGroupName) {
        var ctg = _this2._byCrosstalkGroup[ctGroupName];
        var selection = []; // ...iterate over each Crosstalk key (each of which may have multiple
        // layers)...

        Object.keys(ctg).forEach(function (ctKey) {
          // ...and for each layer...
          ctg[ctKey].forEach(function (stamp) {
            var layerInfo = _this2._byStamp[stamp]; // ...if it's something with a point...

            if (layerInfo.layer.getLatLng) {
              // ... and it's inside the selection bounds...
              // TODO: Use pixel containment, not lat/lng containment
              if (bounds.contains(layerInfo.layer.getLatLng())) {
                // ...add the key to the selection.
                selection.push(ctKey);
              }
            }
          });
        });
        new global.crosstalk.SelectionHandle(ctGroupName).set(selection, extraInfo);
      });
    }
  }, {
    key: "unbrush",
    value: function unbrush(extraInfo) {
      Object.keys(this._byCrosstalkGroup).forEach(function (ctGroupName) {
        new global.crosstalk.SelectionHandle(ctGroupName).clear(extraInfo);
      });
    }
  }, {
    key: "_setVisibility",
    value: function _setVisibility(layerInfo, visible) {
      if (layerInfo.hidden ^ visible) {
        return;
      } else if (visible) {
        layerInfo.container.addLayer(layerInfo.layer);
        layerInfo.hidden = false;
      } else {
        layerInfo.container.removeLayer(layerInfo.layer);
        layerInfo.hidden = true;
      }
    }
  }, {
    key: "_setOpacity",
    value: function _setOpacity(layerInfo, opacity) {
      if (layerInfo.layer.setOpacity) {
        layerInfo.layer.setOpacity(opacity);
      } else if (layerInfo.layer.setStyle) {
        layerInfo.layer.setStyle({
          opacity: opacity * layerInfo.layer.options.origOpacity,
          fillOpacity: opacity * layerInfo.layer.options.origFillOpacity
        });
      }
    }
  }, {
    key: "getLayer",
    value: function getLayer(category, layerId) {
      return this._byLayerId[this._layerIdKey(category, layerId)];
    }
  }, {
    key: "removeLayer",
    value: function removeLayer(category, layerIds) {
      var _this3 = this;

      // Find layer info
      _jquery2["default"].each((0, _util.asArray)(layerIds), function (i, layerId) {
        var layer = _this3._byLayerId[_this3._layerIdKey(category, layerId)];

        if (layer) {
          _this3._removeLayer(layer);
        }
      });
    }
  }, {
    key: "clearLayers",
    value: function clearLayers(category) {
      var _this4 = this;

      // Find all layers in _byCategory[category]
      var catTable = this._byCategory[category];

      if (!catTable) {
        return false;
      } // Remove all layers. Make copy of keys to avoid mutating the collection
      // behind the iterator you're accessing.


      var stamps = [];

      _jquery2["default"].each(catTable, function (k, v) {
        stamps.push(k);
      });

      _jquery2["default"].each(stamps, function (i, stamp) {
        _this4._removeLayer(stamp);
      });
    }
  }, {
    key: "getLayerGroup",
    value: function getLayerGroup(group, ensureExists) {
      var g = this._groupContainers[group];

      if (ensureExists && !g) {
        this._byGroup[group] = this._byGroup[group] || {};
        g = this._groupContainers[group] = _leaflet2["default"].featureGroup();
        g.groupname = group;
        g.addTo(this._map);
      }

      return g;
    }
  }, {
    key: "getGroupNameFromLayerGroup",
    value: function getGroupNameFromLayerGroup(layerGroup) {
      return layerGroup.groupname;
    }
  }, {
    key: "getVisibleGroups",
    value: function getVisibleGroups() {
      var _this5 = this;

      var result = [];

      _jquery2["default"].each(this._groupContainers, function (k, v) {
        if (_this5._map.hasLayer(v)) {
          result.push(k);
        }
      });

      return result;
    }
  }, {
    key: "getAllGroupNames",
    value: function getAllGroupNames() {
      var result = [];

      _jquery2["default"].each(this._groupContainers, function (k, v) {
        result.push(k);
      });

      return result;
    }
  }, {
    key: "clearGroup",
    value: function clearGroup(group) {
      var _this6 = this;

      // Find all layers in _byGroup[group]
      var groupTable = this._byGroup[group];

      if (!groupTable) {
        return false;
      } // Remove all layers. Make copy of keys to avoid mutating the collection
      // behind the iterator you're accessing.


      var stamps = [];

      _jquery2["default"].each(groupTable, function (k, v) {
        stamps.push(k);
      });

      _jquery2["default"].each(stamps, function (i, stamp) {
        _this6._removeLayer(stamp);
      });
    }
  }, {
    key: "clear",
    value: function clear() {
      function clearLayerGroup(key, layerGroup) {
        layerGroup.clearLayers();
      } // Clear all indices and layerGroups


      this._byGroup = {};
      this._byCategory = {};
      this._byLayerId = {};
      this._byStamp = {};
      this._byCrosstalkGroup = {};

      _jquery2["default"].each(this._categoryContainers, clearLayerGroup);

      this._categoryContainers = {};

      _jquery2["default"].each(this._groupContainers, clearLayerGroup);

      this._groupContainers = {};
    }
  }, {
    key: "_removeLayer",
    value: function _removeLayer(layer) {
      var stamp;

      if (typeof layer === "string") {
        stamp = layer;
      } else {
        stamp = _leaflet2["default"].Util.stamp(layer);
      }

      var layerInfo = this._byStamp[stamp];

      if (!layerInfo) {
        return false;
      }

      layerInfo.container.removeLayer(stamp);

      if (typeof layerInfo.group === "string") {
        delete this._byGroup[layerInfo.group][stamp];
      }

      if (typeof layerInfo.layerId === "string") {
        delete this._byLayerId[this._layerIdKey(layerInfo.category, layerInfo.layerId)];
      }

      delete this._byCategory[layerInfo.category][stamp];
      delete this._byStamp[stamp];

      if (layerInfo.ctGroup) {
        var ctGroup = this._byCrosstalkGroup[layerInfo.ctGroup];
        var layersForKey = ctGroup[layerInfo.ctKey];
        var idx = layersForKey ? layersForKey.indexOf(stamp) : -1;

        if (idx >= 0) {
          if (layersForKey.length === 1) {
            delete ctGroup[layerInfo.ctKey];
          } else {
            layersForKey.splice(idx, 1);
          }
        }
      }
    }
  }, {
    key: "_layerIdKey",
    value: function _layerIdKey(category, layerId) {
      return category + "\n" + layerId;
    }
  }]);

  return LayerManager;
}();

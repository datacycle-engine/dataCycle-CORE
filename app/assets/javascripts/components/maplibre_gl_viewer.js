import pick from 'lodash/pick';
import isEmpty from 'lodash/isEmpty';

import maplibregl from 'maplibre-gl/dist/maplibre-gl';

const iconPaths = {
  start:
    'data:image/svg+xml;utf8,<svg width="21.091" height="33.117" version="1.1" viewBox="0 0 21.091 33.117" xmlns="http://www.w3.org/2000/svg"><path d="m10.545 1c-5.2719 0-9.5453 4.2748-9.5453 9.5484 0 9.5484 9.5453 21.006 9.5453 21.006s9.5453-11.458 9.5453-21.006c0-5.2736-4.2734-9.5484-9.5453-9.5484z" fill="${color}" stroke="${strokeColor}" stroke-width="2" style="paint-order:normal"/><path d="m15.944 11.969-8.9451 5.0275 0.11862-10.26z" fill="%23fff" fill-opacity="1"/></svg>'
};

class MapLibreGlViewer {
  constructor(container) {
    this.$container = $(container);
    this.$parentContainer = this.$container.parent('.geographic');
    this.containerId = this.$container.attr('id');
    this.map;
    this.value = this.$container.data('value');
    this.beforeValue = this.$container.data('before-position');
    this.afterValue = this.$container.data('after-position');
    this.type = this.$container.data('type');
    this.additionalValues = this.$container.data('additionalValues') || {};
    this.additionalValuesOverlay = this.$container.data('additionalValuesOverlay');
    this.feature;
    this.additionalFeatures = {};
    this.icons = iconPaths;
    this.colorsHandler = {
      get: function (target, name) {
        if (target.hasOwnProperty(name)) return target[name];
        else if (name) return name;
        else target['default'];
      }
    };
    this.definedColors = {
      default: '#1779ba',
      lightBlue: '#1dbde5',
      red: '#cc4b37',
      green: '#90c062',
      white: '#ffffff',
      yellow: '#ffae00',
      gray: '#767676'
    };
    this.colors = new Proxy(this.definedColors, this.colorsHandler);
    this.zoomMethod = 'ctrlKey';
    this.mouseZoomTimeout;
    this.mapOptions = this.$container.data('map-options');
    this.mapStyles = this.mapOptions.styles;
    this.mapBackend = this.mapOptions.viewer || this.mapOptions.editor;
    this.defaultPosition = pick(this.mapOptions, ['latitude', 'longitude', 'zoom']);
    this.highDpi = window.devicePixelRatio > 1;

    this.credentials = this.mapOptions.credentials;
    this.selectedAdditionalSources = {};
    this.selectedAdditionalLayers = {};
    this.sources = {};
    this.layers = {};
    this.allRenderedLayers = [];
    this.hoveredStateId = {};
  }
  setup() {
    try {
      this.initMap();
      this.map.on('load', this.configureMap.bind(this));
    } catch (error) {
      console.error(error);
    }
  }
  initMap() {
    this.map = new maplibregl.Map({
      container: this.containerId,
      style: this.mapBaseLayer(),
      center: this.defaultCenter(),
      zoom: this.defaultZoom(),
      transformRequest: (url, resourceType) => {
        if (url.includes('tiles.pixelmap.at/')) {
          return {
            headers: {
              Authorization: `Bearer ${this.credentials.api_key}`
            },
            url: url
          };
        }
        return;
      }
    });
  }
  configureMap() {
    this.initControls();
    this.setZoomMethod();
    this.setIcons();

    this.initFeatures();
    this._disableScrollingOnMapOverlays();
    this.initMouseWheelZoom();
    this.updateMapPosition();
  }
  initFeatures() {
    this.drawFeatures();
    this.drawAdditionalFeatures();
  }
  mapBaseLayer() {
    let baseStyle = this.mapStyles[0].value;

    if (typeof this['baseLayer' + baseStyle] == 'function') return this['baseLayer' + baseStyle]();
    else if (baseStyle) return baseStyle;

    throw 'No Map-Style defined!';
  }
  baseLayerOSM() {
    return {
      version: 8,
      sources: {
        'osm-tiles': {
          type: 'raster',
          tiles: [
            'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
            'https://b.tile.openstreetmap.org/{z}/{x}/{y}.png',
            'https://c.tile.openstreetmap.org/{z}/{x}/{y}.png'
          ],
          tileSize: 256,
          attribution:
            '&#169; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors.'
        }
      },
      layers: [
        {
          id: 'osm-tiles',
          type: 'raster',
          source: 'osm-tiles',
          minzoom: 0,
          maxzoom: 19
        }
      ]
    };
  }
  baseLayerBaseMapAt() {
    const layer = this.highDpi ? 'bmaphidpi' : 'geolandbasemap';
    const matrixSet = 'google3857';
    const style = 'normal';
    const fileType = this.highDpi ? 'jpeg' : 'png';
    return {
      version: 8,
      sources: {
        'basemap-at-tiles': {
          type: 'raster',
          tiles: [
            `https://maps.wien.gv.at/basemap/${layer}/${style}/${matrixSet}/{z}/{y}/{x}.${fileType}`,
            `https://maps1.wien.gv.at/basemap/${layer}/${style}/${matrixSet}/{z}/{y}/{x}.${fileType}`,
            `https://maps2.wien.gv.at/basemap/${layer}/${style}/${matrixSet}/{z}/{y}/{x}.${fileType}`,
            `https://maps3.wien.gv.at/basemap/${layer}/${style}/${matrixSet}/{z}/{y}/{x}.${fileType}`,
            `https://maps4.wien.gv.at/basemap/${layer}/${style}/${matrixSet}/{z}/{y}/{x}.${fileType}`
          ],
          tileSize: 256,
          attribution: '© <a href="https://www.basemap.at" target="_blank">basemap.at</a>'
        }
      },
      layers: [
        {
          id: 'basemap-at-tiles',
          type: 'raster',
          source: 'basemap-at-tiles',
          minzoom: 0,
          maxzoom: 18
        }
      ]
    };
  }
  baseLayerTourSprung() {
    return {
      version: 8,
      sources: {
        'toursprung-tiles': {
          type: 'raster',
          tiles: [
            `https://rtc-cdn.maptoolkit.net/rtc/toursprung-terrain/{z}/{x}/{y}${
              this.highDpi ? '@2x' : ''
            }.png?api_key=${this.credentials.api_key}`
          ],
          tileSize: 256,
          attribution:
            '© <a href="http://www.toursprung.com" target="_blank">Toursprung</a> © <a href="https://www.openstreetmap.org/copyright" target="_blank">OSM Contributors</a>'
        }
      },
      layers: [
        {
          id: 'toursprung-tiles',
          type: 'raster',
          source: 'toursprung-tiles',
          minzoom: 0,
          maxzoom: 22
        }
      ]
    };
  }
  defaultCenter() {
    if (this.defaultPosition && this.defaultPosition.longitude && this.defaultPosition.latitude)
      return [this.defaultPosition.longitude, this.defaultPosition.latitude];
    else return [13.34576, 47.69642];
  }
  defaultZoom() {
    if (this.defaultPosition && this.defaultPosition.zoom) return this.defaultPosition.zoom;
    else return 7;
  }
  setZoomMethod() {
    const platform = window.navigator.platform;

    if (/Mac/.test(platform)) {
      this.zoomMethod = 'metaKey';
    } else {
      this.zoomMethod = 'ctrlKey';
    }
  }
  setIcons() {
    for (const [iconKey, iconValue] of Object.entries(this.icons)) {
      for (const [colorKey, colorValue] of Object.entries(this.definedColors)) {
        let icon = new Image(21, 33);
        icon.onload = () => this.map.addImage(`${iconKey}_${colorKey}`, icon);
        icon.src = iconValue.interpolate({
          color: escape(colorValue),
          strokeColor: escape(this.colors['white'])
        });
      }
    }
  }
  drawFeatures() {
    if (!this.feature && this.value) this.feature = this.value;
    if (!this.afterValue && this.feature) this._addSourceAndLayer('primary', this.feature);
  }
  drawAdditionalFeatures() {
    const beforeFeature = this.beforeValue ? { beforeValue: this.beforeValue } : {};
    const afterFeature = this.afterValue ? { afterValue: this.afterValue } : {};

    this.additionalFeatures = { ...beforeFeature, ...afterFeature, ...this.additionalValues };

    for (const [key, value] of Object.entries(this.additionalFeatures)) {
      this._addSelectedSourceAndLayers(key, value);
    }

    this._addPopup();
  }
  _getLastLineLayerId() {
    return this.map
      .getStyle()
      .layers.find(l => l.type === 'background' || (l.type === 'line' && l.id.includes('feature'))).id;
  }
  _getLastPointLayerId() {
    return this.map
      .getStyle()
      .layers.find(
        l => l.type === 'background' || l.type === 'symbol' || (l.type === 'circle' && l.id.includes('feature'))
      ).id;
  }
  _lineLayer(layerId, source) {
    let lineColor = this.definedColors.gray;
    let iconColor = 'gray';

    if (layerId.includes('feature')) {
      lineColor = this.definedColors.default;
      iconColor = 'default';
    } else if (layerId.includes('selected')) {
      lineColor = this.definedColors.lightBlue;
      iconColor = 'lightBlue';
    }

    this.map.addLayer(
      {
        id: `${layerId}_hover`,
        type: 'line',
        source: source,
        filter: ['==', ['geometry-type'], 'LineString'],
        layout: {
          'line-cap': 'round',
          'line-join': 'round'
        },
        paint: {
          'line-color': this.definedColors.white,
          'line-opacity': ['case', ['boolean', ['feature-state', 'hover'], false], 1, 0],
          'line-width': this.getStyleCaseExpression('width', ['+', ['get', 'width'], 4], 9)
        }
      }
      // this._getLastLineLayerId() // TODO:
    );

    this.map.addLayer(
      {
        id: layerId,
        type: 'line',
        source: source,
        filter: ['==', '$type', 'LineString'],
        layout: {
          'line-cap': 'round',
          'line-join': 'round'
        },
        paint: {
          'line-color': this.getStyleCaseExpression('color', this.getColorMatchHexExpression(), lineColor),
          'line-opacity': iconColor === 'gray' ? 0.75 : 1,
          'line-width': this.getStyleCaseExpression('width', ['get', 'width'], 5)
        }
      }
      // this._getLastLineLayerId() // TODO:
    );
    // we are adding only start point, because then we can use symbol-placement point
    this.map.addLayer(
      {
        id: `${layerId}_hover_start`,
        type: 'symbol',
        source: source,
        filter: ['==', ['geometry-type'], 'LineString'],
        layout: {
          'icon-image': this.getStyleCaseExpression(
            'color',
            ['concat', 'start_', ['get', 'color']],
            `start_${iconColor}`
          ),
          'icon-offset': [0, -15],
          'symbol-placement': 'point'
        },
        paint: {
          'icon-opacity': ['case', ['boolean', ['feature-state', 'hover'], false], 1, 0]
        }
      }
      // this._getLastPointLayerId() // TODO:
    );

    this.initMapHoverActions(`${layerId}_hover`, source);

    if (layerId.includes('selected'))
      this.allRenderedLayers.push(`${layerId}_hover`, layerId, `${layerId}_hover_start`);

    return layerId;
  }
  _pointLayer(layerId, source) {
    let pointColor = this.definedColors.gray;
    let circleRadius = 5;

    if (layerId.includes('feature')) {
      pointColor = this.definedColors.default;
      circleRadius = 7;
    } else if (layerId.includes('selected')) {
      pointColor = this.definedColors.lightBlue;
      circleRadius = 7;
    }

    this.map.addLayer(
      {
        id: layerId,
        type: 'circle',
        source: source,
        filter: ['==', '$type', 'Point'],
        paint: {
          'circle-radius': circleRadius,
          'circle-stroke-width': 4,
          'circle-color': this.getStyleCaseExpression('color', this.getColorMatchHexExpression(), pointColor),
          'circle-stroke-color': this.definedColors.white
        }
      }
      // this._getLastPointLayerId() // TODO:
    );

    this.map.addLayer(
      {
        id: `${layerId}_hover`,
        type: 'circle',
        source: source,
        filter: ['==', '$type', 'Point'],
        paint: {
          'circle-radius': circleRadius + 2,
          'circle-stroke-width': 4,
          'circle-color': this.getStyleCaseExpression('color', this.getColorMatchHexExpression(), pointColor),
          'circle-stroke-color': this.definedColors.white,
          'circle-opacity': ['case', ['boolean', ['feature-state', 'hover'], false], 1, 0],
          'circle-stroke-opacity': ['case', ['boolean', ['feature-state', 'hover'], false], 1, 0]
        }
      }
      // this._getLastPointLayerId() // TODO:
    );
    this.initMapHoverActions(`${layerId}_hover`, source);

    if (layerId.includes('selected')) this.allRenderedLayers.push(`${layerId}_hover`, layerId);

    return layerId;
  }
  _addPopup() {
    const popup = new maplibregl.Popup({
      closeButton: false,
      closeOnClick: false,
      className: 'additional-feature-popup'
    });

    this.map.on('mousemove', e => {
      const feature = this.map.queryRenderedFeatures(e.point, { layers: this.allRenderedLayers })[0];

      if (feature) {
        popup
          .setLngLat(feature.geometry.type !== 'Point' ? e.lngLat : feature.geometry.coordinates)
          .setHTML(feature.properties.name)
          .addTo(this.map);

        this._highlightLinked(feature);
      } else {
        popup.remove();
      }
    });
  }
  _highlightLinked(feature) {
    if (!feature.properties.thingPath) return;

    let listElement = $('li[data-id*="' + feature.properties.thingPath.split('/').pop() + '"]');

    listElement.addClass('highlight');

    setTimeout(() => {
      listElement.removeClass('highlight');
    }, 1000);
  }
  _addSourceAndLayer(key, data) {
    this.sources[key] = `feature_source_${key}`;

    this.map.addSource(this.sources[key], {
      type: 'geojson',
      data: data,
      promoteId: 'id'
    });

    this.layers[key] = {
      point: this._pointLayer(`feature_point_${key}`, this.sources[key]),
      line: this._lineLayer(`feature_line_${key}`, this.sources[key])
    };
  }
  _addSelectedSourceAndLayers(key, data) {
    this.selectedAdditionalSources[key] = `additional_values_source_selected_${key}`;

    this.map.addSource(this.selectedAdditionalSources[key], {
      type: 'geojson',
      data: data,
      promoteId: 'id'
    });

    this.selectedAdditionalLayers[key] = {
      point: this._pointLayer(`additional_values_point_selected_${key}`, this.selectedAdditionalSources[key]),
      line: this._lineLayer(`additional_values_line_selected_${key}`, this.selectedAdditionalSources[key])
    };
  }
  _disableScrollingOnMapOverlays() {
    this.$parentContainer.siblings('.map-info').on('wheel', event => {
      if (event.originalEvent[this.zoomMethod]) event.preventDefault();
    });

    this.$container.on('wheel', '*', event => {
      if (event.originalEvent[this.zoomMethod]) event.preventDefault();
    });
  }
  initControls() {
    this.map.addControl(new maplibregl.NavigationControl(), 'top-left');
    this.map.addControl(new maplibregl.FullscreenControl(), 'top-right');
  }
  initMouseWheelZoom() {
    this.map.scrollZoom.disable();

    this.map.on('wheel', event => {
      if (!event.originalEvent[this.zoomMethod] && document.fullscreenElement != this.$container.get(0)) {
        if (this.map.scrollZoom._enabled) this.map.scrollZoom.disable();

        if (!this.$container.find('.scroll-overlay').length) {
          const $element = $(
            '<div class="scroll-overlay" style="display: none;"><div class="scroll-overlay-text"></div></div>'
          );

          this.$container.append($element);
          $element.fadeIn(100);

          I18n.translate(`frontend.map.scroll_notice.${this.zoomMethod}`).then(text => {
            $($element).find('.scroll-overlay-text').text(text);
          });
        } else {
          this.$container.find('.scroll-overlay').fadeIn(100);
        }

        window.clearTimeout(this.mouseZoomTimeout);
        this.mouseZoomTimeout = window.setTimeout(() => {
          this.$container.find('.scroll-overlay').fadeOut(100);
        }, 1000);
      } else {
        event.originalEvent.preventDefault();

        if (!this.map.scrollZoom._enabled) this.map.scrollZoom.enable();

        this.$container.find('.scroll-overlay').fadeOut(100);
      }
    });
  }
  initMapHoverActions(layerId, source) {
    this.map.on('mousemove', layerId, e => {
      if (e.features.length > 0) {
        if (this.hoveredStateId[layerId]) {
          this.map.setFeatureState({ source: source, id: this.hoveredStateId[layerId] }, { hover: false });
        }
        this.hoveredStateId[layerId] = e.features[0].id;
        this.map.setFeatureState({ source: source, id: this.hoveredStateId[layerId] }, { hover: true });
      }
    });
    this.map.on('mouseleave', layerId, () => {
      if (this.hoveredStateId[layerId] != null) {
        this.map.setFeatureState({ source: source, id: this.hoveredStateId[layerId] }, { hover: false });
      }
      this.hoveredStateId[layerId] = null;
    });
  }
  updateMapPosition() {
    let bounds = new maplibregl.LngLatBounds();

    if (this.feature) bounds.extend(this.getBoundsForGeojson(this.feature));

    for (const geoJson of Object.values(this.additionalFeatures)) {
      bounds.extend(this.getBoundsForGeojson(geoJson));
    }
    // TODO: how do AdditionalValues fit here?

    if (isEmpty(bounds)) return;

    this.map.fitBounds(bounds, {
      padding: 50,
      maxZoom: 15
    });
  }
  getBoundsForGeojson(geoJson) {
    const bounds = new maplibregl.LngLatBounds();

    if (geoJson.hasOwnProperty('features')) {
      for (const feature of geoJson.features) {
        if (!feature || !feature.geometry) continue;

        this.addBoundsForFeature(bounds, feature);
      }
    } else {
      return this.addBoundsForFeature(bounds, geoJson);
    }
    return bounds;
  }
  addBoundsForFeature(bounds, feature) {
    if (feature.geometry.type === 'Point') bounds.extend(feature.geometry.coordinates);
    else if (feature.geometry.type === 'MultiLineString') {
      for (const lineStrings of feature.geometry.coordinates) {
        for (const coords of lineStrings) bounds.extend([coords[0], coords[1]]);
      }
    }
    return bounds;
  }
  getStyleCaseExpression(property, output, fallback) {
    return ['case', ['boolean', ['to-boolean', ['get', property]]], output, fallback];
  }
  getColorMatchHexExpression() {
    let matchEx = ['match', ['get', 'color']];

    for (const [name, value] of Object.entries(this.definedColors)) {
      matchEx.push(name, value);
    }

    matchEx.push(this.definedColors.default);

    return matchEx;
  }
  isPoint() {
    return this.type.includes('Point');
  }
  isLineString() {
    return this.type.includes('LineString');
  }
}

export default MapLibreGlViewer;

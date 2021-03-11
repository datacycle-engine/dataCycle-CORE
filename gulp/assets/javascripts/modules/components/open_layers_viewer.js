var ObjectHelpers = require('../helpers/object_helpers');

var ol = {
  Map: require('ol/map').default,
  layer: {
    Tile: require('ol/layer/tile').default,
    Vector: require('ol/layer/vector').default
  },
  Feature: require('ol/feature').default,
  format: {
    WKT: require('ol/format/wkt').default
  },
  geom: {
    Point: require('ol/geom/point').default,
    LineString: require('ol/geom/linestring').default,
    MultiLineString: require('ol/geom/multilinestring').default
  },
  source: {
    OSM: require('ol/source/osm').default,
    Vector: require('ol/source/vector').default,
    WMTS: require('ol/source/wmts').default,
    XYZ: require('ol/source/xyz').default
  },
  style: {
    Style: require('ol/style/style').default,
    Stroke: require('ol/style/stroke').default,
    Circle: require('ol/style/circle').default,
    Fill: require('ol/style/fill').default,
    Text: require('ol/style/text').default,
    Icon: require('ol/style/icon').default
  },
  View: require('ol/view').default,
  extent: require('ol/extent').default,
  interaction: {
    Draw: require('ol/interaction/draw').default,
    Modify: require('ol/interaction/modify').default,
    Snap: require('ol/interaction/snap').default,
    MouseWheelZoom: require('ol/interaction/mousewheelzoom').default
  },
  interactions: require('ol/interaction').default,
  proj: require('ol/proj').default,
  WMTSCapabilities: require('ol/format/wmtscapabilities').default
};

var { optionsFromCapabilities } = require('ol/source/wmts').default;

class OpenLayersViewer {
  constructor(container) {
    this.$container = $(container);
    this.containerId = this.$container.attr('id');
    this.ol = ol;
    this.value = this.$container.data('value');
    this.beforeValue = this.$container.data('before-position');
    this.afterValue = this.$container.data('after-position');
    this.type = this.$container.data('type');
    this.additionalValues = this.$container.data('additionalValues');
    this.feature;
    this.featureBefore;
    this.icons = {
      default:
        'data:image/svg+xml;utf8,<svg width="20.889" height="32.571" version="1.1" viewBox="0 0 20.889 32.571" xmlns="http://www.w3.org/2000/svg"><path d="m10.889 0c-5.523 0-10 4.477-10 10 0 10 10 22 10 22s10-12 10-22c0-5.523-4.477-10-10-10zm0 16c-3.314 0-6-2.686-6-6s2.686-6 6-6 6 2.686 6 6-2.686 6-6 6z" fill-opacity=".5"/><path d="m10 0.57142c-5.523 0-10 4.477-10 10 0 10 10 22 10 22s10-12 10-22c0-5.523-4.477-10-10-10zm0 16c-3.314 0-6-2.686-6-6 0-3.314 2.686-6 6-6s6 2.686 6 6c0 3.314-2.686 6-6 6z" fill="${markerColor}"/></svg>',
      start:
        'data:image/svg+xml;utf8,<svg width="20.875" height="32.42" version="1.1" viewBox="0 0 20.875 32.42" xmlns="http://www.w3.org/2000/svg"><path d="m10.875 0c-5.523 0-10 4.477-10 10 0 10 10 22 10 22s10-12 10-22c0-5.523-4.477-10-10-10zm-3.9593 11.721c0.14697-8.0447 2.867-5.8185 9.2881-0.47458-6.2 5.5496-9.1109 8.1994-9.2881 0.47458z" opacity=".5"/><path d="m10 0.41968c-5.523 0-10 4.477-10 10 0 10 10 22 10 22s10-12 10-22c0-5.523-4.477-10-10-10zm-3.9593 11.721c0.14697-8.0447 2.867-5.8185 9.2881-0.47458-6.2 5.5496-9.1109 8.1994-9.2881 0.47458z" fill="${markerColor}"/></svg>',
      end:
        'data:image/svg+xml;utf8,<svg width="20.963" height="32.525" version="1.1" viewBox="0 0 20.963 32.525" xmlns="http://www.w3.org/2000/svg"><path d="m10.963 0c-5.523 0-10 4.477-10 10 0 10 10 22 10 22s10-12 10-22c0-5.523-4.477-10-10-10zm0 14.036c-4.4239 0.04459-3.9455 0.32896-3.8531-4.0358 9.9e-4 -4.8216-0.62981-4.1587 3.8531-4.2185 4.5744-0.01416 4.0456-0.67578 4.0815 4.3099 0.12766 4.5017 0.45258 3.9004-4.0815 3.9445z" fill="${markerColor}" opacity=".5"/><path d="m10 0.52489c-5.523 0-10 4.477-10 10 0 10 10 22 10 22s10-12 10-22c0-5.523-4.477-10-10-10zm0 14.036c-4.4239 0.044587-3.9455 0.32896-3.8531-4.0358 9.905e-4 -4.8216-0.62981-4.1587 3.8531-4.2185 4.5744-0.01416 4.0456-0.67578 4.0815 4.3099 0.12766 4.5017 0.45258 3.9004-4.0815 3.9445z" fill="${markerColor}"/></svg>'
    };
    this.markerColors = {
      default: '#111111',
      red: '#cc4b37',
      green: '#90c062',
      defaultLine: '#1779ba'
    };
    this.styles = {
      icon: {},
      line: {}
    };
    this.scrollTexts = {
      ctrlKey: 'Strg+Scrollen zum Zoomen',
      metaKey: '⌘+Scrollen zum Zoomen',
      pinch: 'zwei Finger zum Zoomen/Scrollen'
    };
    this.zoomMethod = 'ctrlKey';
    this.options = {};
    this.features = [];
    this.layerLines;
    this.mouseWheelZoom = new this.ol.interaction.MouseWheelZoom();
    this.mouseZoomTimeout;
    this.mapOptions = this.$container.data('map-options');
    this.mapBackend = this.mapOptions.viewer || this.mapOptions.editor;
    this.defaultPosition = ObjectHelpers.select(this.mapOptions, ['latitude', 'longitude', 'zoom']);
    this.highDpi = window.devicePixelRatio > 1;
    this.wktFormat = new this.ol.format.WKT();
    this.source;
  }
  setup() {
    this.setZoomMethod();
    this.initIconStyles();
    this.initFeatures();
    this.configureFeatures();
    this.configureLayerLines();
    this.initMouseWheelZoom();
    this.initMap().then(() => {
      this.setDefaultPosition();
    });
  }
  isPoint() {
    return this.type.includes('Point');
  }
  isLineString() {
    return this.type.includes('LineString');
  }
  mapBaseLayer() {
    if (typeof this['baseLayer' + this.mapBackend] == 'function') return this['baseLayer' + this.mapBackend]();
    else return this.baseLayerBaseMap();
  }
  baseLayerBaseMap() {
    return fetch('https://maps.wien.gv.at/basemap/1.0.0/WMTSCapabilities.xml')
      .then(response => response.text())
      .then(text => {
        let result = new this.ol.WMTSCapabilities().read(text);
        let options = optionsFromCapabilities(result, {
          layer: this.highDpi ? 'bmaphidpi' : 'geolandbasemap',
          matrixSet: 'google3857',
          style: 'normal'
        });

        options.attributions = '© <a href="https://www.basemap.at" target="_blank">basemap.at</a>';
        options.tilePixelRatio = this.hiDPI ? 2 : 1;

        return new this.ol.layer.Tile({
          source: new this.ol.source.WMTS(options)
        });
      });
  }
  baseLayerOpenStreetMap() {
    return Promise.resolve(
      new this.ol.layer.Tile({
        source: new this.ol.source.OSM()
      })
    );
  }
  baseLayerTourSprung() {
    return Promise.resolve(
      new this.ol.layer.Tile({
        source: new this.ol.source.XYZ({
          attributions:
            '© <a href="http://www.toursprung.com" target="_blank">Toursprung</a> © <a href="https://www.openstreetmap.org/copyright" target="_blank">OSM Contributors</a>',
          url:
            'https://rtc-cdn.maptoolkit.net/rtc/toursprung-terrain/{z}/{x}/{y}' +
            (this.hiDPI ? '@2x' : '') +
            '.png?api_key=' +
            this.mapOptions.credentials.api_key,
          tilePixelRatio: this.hiDPI ? 2 : 1
        })
      })
    );
  }
  generateIconStyle(type, color, additionalParameters = {}) {
    return new this.ol.style.Style(
      Object.assign(
        {
          image: new this.ol.style.Icon({
            anchor: [0.5, 1],
            opacity: 0.8,
            scale: 1,
            src: this.icons[type].interpolate({ markerColor: escape(this.markerColors[color]) })
          })
        },
        additionalParameters
      )
    );
  }
  generateLineStyle(color, width = 5) {
    return new this.ol.style.Style({
      stroke: new this.ol.style.Stroke({ color: this.markerColors[color], width: width })
    });
  }
  initIconStyles() {
    this.styles.icon.default = this.generateIconStyle('default', 'default');
    this.styles.icon.red = this.generateIconStyle('default', 'red');
    this.styles.icon.green = this.generateIconStyle('default', 'green');
    this.styles.line.default = this.generateLineStyle('defaultLine');
    this.styles.line.red = this.generateLineStyle('red');
    this.styles.line.green = this.generateLineStyle('green');
  }
  initFeatures() {
    if (this.beforeValue && this.beforeValue.length) {
      this.featureBefore = this.createFeaturefromWkt(this.beforeValue);
      this.featureBefore.setStyle((feature, _) => this.styleFunction(feature, 'red', 'red', 7));
    }
    if (this.afterValue && this.afterValue.length) {
      this.feature = this.createFeaturefromWkt(this.afterValue);
      this.feature.setStyle((feature, _) => this.styleFunction(feature, 'green', 'green'));
    }
    if (!this.feature && this.value && this.value.length) {
      this.feature = this.createFeaturefromWkt(this.value);
      this.feature.setStyle((feature, _) => this.styleFunction(feature, 'defaultLine', 'default'));
    }
  }
  styleFunction(feature, lineColor, color, width = 5) {
    var geometry = feature.getGeometry();
    var styles = [this.generateLineStyle(lineColor, width)];

    if (geometry.constructor.name.includes('MultiLineString')) {
      geometry.getLineStrings().forEach(lineString => {
        styles.push(
          this.generateIconStyle('start', color, {
            geometry: new this.ol.geom.Point(lineString.getFirstCoordinate())
          })
        );
        styles.push(
          this.generateIconStyle('end', color, {
            geometry: new this.ol.geom.Point(lineString.getLastCoordinate())
          })
        );
      });
    } else if (geometry.constructor.name.includes('LineString')) {
      styles.push(
        this.generateIconStyle('start', color, {
          geometry: new this.ol.geom.Point(geometry.getFirstCoordinate())
        })
      );
      styles.push(
        this.generateIconStyle('end', color, {
          geometry: new this.ol.geom.Point(geometry.getLastCoordinate())
        })
      );
    } else {
      styles.push(
        this.generateIconStyle('default', color, {
          geometry: new this.ol.geom.Point(geometry.getFirstCoordinate())
        })
      );
    }

    return styles;
  }
  drawAdditionalFeatures() {
    this.additionalValues.forEach(additionalFeature => {
      let feature = this.createFeaturefromWkt(additionalFeature);
      feature.setStyle((feature, _) => this.styleFunction(feature, 'defaultLine', 'default'));
      this.features.push(feature);
    });
  }
  createFeaturefromWkt(wkt) {
    return this.wktFormat.readFeature(wkt, {
      dataProjection: 'EPSG:4326',
      featureProjection: 'EPSG:3857'
    });
  }
  configureFeatures() {
    if (this.feature) this.features.push(this.feature);
    if (this.featureBefore) this.features.push(this.featureBefore);
    if (this.additionalValues && this.additionalValues.length) this.drawAdditionalFeatures();

    if (this.features.length) {
      this.options = {
        features: this.features
      };
    }
  }
  configureLayerLines() {
    this.source = new this.ol.source.Vector(this.options);

    this.layerLines = new this.ol.layer.Vector({
      source: this.source,
      style: [
        new this.ol.style.Style({
          stroke: new this.ol.style.Stroke({
            color: '#c30000',
            width: 3
          }),
          image: new this.ol.style.Circle({
            radius: 3,
            fill: new this.ol.style.Fill({
              color: '#c30000'
            }),
            stroke: new this.ol.style.Stroke({
              color: '#c30000',
              width: 3
            })
          })
        })
      ]
    });
  }
  setZoomMethod() {
    const platform = window.navigator.platform;

    if (/Mac/.test(platform)) {
      this.zoomMethod = 'metaKey';
    } else {
      this.zoomMethod = 'ctrlKey';
    }
  }
  initMouseWheelZoom() {
    let oldFn = this.mouseWheelZoom.handleEvent;
    let self = this;

    this.mouseWheelZoom.handleEvent = function (e) {
      let type = e.type;
      if (type !== 'wheel') {
        return true;
      }

      if (!e.originalEvent[self.zoomMethod]) {
        if (!$(e.map.getTargetElement().firstElementChild).find('.scroll-overlay').length) {
          $(e.map.getTargetElement().firstElementChild)
            .find('canvas')
            .after(
              `<div class="scroll-overlay" style="display: none;"><div class="scroll-overlay-text">Verwende ${
                self.scrollTexts[self.zoomMethod]
              } der Karte</div></div>`
            );
        } else {
          $(e.map.getTargetElement().firstElementChild).find('.scroll-overlay').fadeIn(100);
        }

        window.clearTimeout(self.mouseZoomTimeout);
        self.mouseZoomTimeout = window.setTimeout(() => {
          $(e.map.getTargetElement().firstElementChild).find('.scroll-overlay').fadeOut(100);
        }, 1000);
        return true;
      } else {
        $(e.map.getTargetElement().firstElementChild).find('.scroll-overlay').fadeOut(100);
      }

      oldFn.call(this, e);
    };
  }
  initMap() {
    return this.mapBaseLayer().then(baseLayer => {
      this.map = new this.ol.Map({
        interactions: this.ol.interactions
          .defaults({
            mouseWheelZoom: false
          })
          .extend([this.mouseWheelZoom]),
        target: this.containerId,
        layers: [baseLayer, this.layerLines],
        view: new this.ol.View({
          center: [0, 0],
          zoom: 10
        })
      });
    });
  }
  setConfiguredDefaultPosition() {
    if (this.defaultPosition && this.defaultPosition.longitude && this.defaultPosition.latitude) {
      let newCoords = new this.ol.geom.Point([this.defaultPosition.longitude, this.defaultPosition.latitude]).transform(
        'EPSG:4326',
        'EPSG:3857'
      );
      this.map.getView().setCenter(newCoords.getCoordinates());
    }
    if (this.defaultPosition && this.defaultPosition.zoom) this.map.getView().setZoom(this.defaultPosition.zoom);
  }
  setDefaultPosition() {
    if (!this.feature && !this.featureBefore) {
      this.setConfiguredDefaultPosition();
      return;
    }

    let extent = new this.ol.extent.createEmpty();
    if (this.feature) extent = new this.ol.extent.extend(extent, this.feature.getGeometry().getExtent());
    if (this.featureBefore) extent = new this.ol.extent.extend(extent, this.featureBefore.getGeometry().getExtent());

    this.map.getView().fit(extent, { padding: [50, 50, 50, 50], maxZoom: 15 });
  }
}

module.exports = OpenLayersViewer;

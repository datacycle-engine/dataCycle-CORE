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
  WMTSCapabilities: require('ol/format/wmtscapabilities').default,
  deviceCapabilities: require('ol/has').default
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
        'data:image/svg+xml;utf8,<svg width="21" height="33" version="1.1" viewBox="0 0 21 33" xmlns="http://www.w3.org/2000/svg"><path d="m10.5 0.5c-5.523 0-10 4.477-10 10 0 10 10 22 10 22s10-12 10-22c0-5.523-4.477-10-10-10z" fill="${markerColor}" stroke="%23fff" stroke-linejoin="round" stroke-opacity=".8" style="paint-order:stroke markers fill"/><circle cx="10.574" cy="10.771" r="4.4524" fill-opacity=".8" fill="%23111"/></svg>',
      start:
        'data:image/svg+xml;utf8,<svg width="21" height="33" version="1.1" viewBox="0 0 21 33" xmlns="http://www.w3.org/2000/svg"><path d="m10.5 0.5c-5.523 0-10 4.477-10 10 0 10 10 22 10 22s10-12 10-22c0-5.523-4.477-10-10-10z" fill="${markerColor}" stroke="%23fff" stroke-linejoin="round" stroke-opacity=".8" style="paint-order:stroke markers fill"/><path d="m16.253 11.621-8.9451 5.0275 0.11862-10.26z" fill="%23111" fill-opacity=".8"/></svg>',
      end:
        'data:image/svg+xml;utf8,<svg width="21" height="33" version="1.1" viewBox="0 0 21 33" xmlns="http://www.w3.org/2000/svg"><path d="m10.5 0.5c-5.523 0-10 4.477-10 10 0 10 10 22 10 22s10-12 10-22c0-5.523-4.477-10-10-10z" fill="${markerColor}" stroke="%23fff" stroke-linejoin="round" stroke-opacity=".8" style="paint-order:stroke markers fill"/><rect x="6.042" y="7.3383" width="9.1903" height="8.3106" ry="0" fill="%23111" fill-opacity=".8"/></svg>'
    };
    this.markerColors = {
      default: '#1779ba',
      red: '#cc4b37',
      green: '#90c062'
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
    this.highDpi = this.ol.deviceCapabilities.DEVICE_PIXEL_RATIO > 1;
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
        options.tilePixelRatio = this.highDpi ? 2 : 1;

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
  generateIconStyle(type, color, additionalParameters = {}, additionalImageParameters = {}) {
    return new this.ol.style.Style(
      Object.assign(
        {
          image: new this.ol.style.Icon(
            Object.assign(
              {
                anchor: [0.5, 1],
                opacity: 0.9,
                scale: 1,
                src: this.icons[type].interpolate({ markerColor: escape(this.markerColors[color]) })
              },
              additionalImageParameters
            )
          )
        },
        additionalParameters
      )
    );
  }
  generateLineStyle(color, width = 5) {
    return [
      new this.ol.style.Style({
        stroke: new this.ol.style.Stroke({ color: '#ffffff', width: width + 2 })
      }),
      new this.ol.style.Style({
        stroke: new this.ol.style.Stroke({ color: this.markerColors[color], width: width })
      })
    ];
  }
  initIconStyles() {
    this.styles.icon.default = this.generateIconStyle('default', 'default');
    this.styles.icon.red = this.generateIconStyle('default', 'red');
    this.styles.icon.green = this.generateIconStyle('default', 'green');
    this.styles.line.default = this.generateLineStyle('default');
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
      this.feature.setStyle((feature, _) => this.styleFunction(feature, 'default', 'default'));
    }
  }
  styleFunction(feature, lineColor, color, width = 5) {
    var geometry = feature.getGeometry();
    var styles = this.generateLineStyle(lineColor, width);

    if (geometry.constructor.name.includes('MultiLineString')) {
      geometry.getLineStrings().forEach(lineString => {
        styles.push(
          this.generateIconStyle(
            'end',
            'red',
            {
              geometry: new this.ol.geom.Point(lineString.getLastCoordinate())
            },
            { scale: 0.6 }
          )
        );
        styles.push(
          this.generateIconStyle(
            'start',
            'green',
            {
              geometry: new this.ol.geom.Point(lineString.getFirstCoordinate())
            },
            { scale: 0.7 }
          )
        );
      });
    } else if (geometry.constructor.name.includes('LineString')) {
      styles.push(
        this.generateIconStyle(
          'end',
          'red',
          {
            geometry: new this.ol.geom.Point(geometry.getLastCoordinate())
          },
          { scale: 0.6 }
        )
      );
      styles.push(
        this.generateIconStyle(
          'start',
          'green',
          {
            geometry: new this.ol.geom.Point(geometry.getFirstCoordinate())
          },
          { scale: 0.7 }
        )
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
      feature.setStyle((feature, _) => this.styleFunction(feature, 'default', 'default'));
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

    this.map.getView().fit(this.source.getExtent(), { padding: [50, 50, 50, 50], maxZoom: 15 });
  }
}

module.exports = OpenLayersViewer;

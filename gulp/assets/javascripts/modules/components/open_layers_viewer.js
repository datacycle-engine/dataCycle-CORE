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
    this.container = $(container);
    this.containerId = this.container.attr('id');
    this.value = this.container.data('value');
    this.beforeValue = this.container.data('before-position');
    this.afterValue = this.container.data('after-position');
    this.type = this.container.data('type');
    this.iconPaths = this.container.data('icon-paths');
    this.feature;
    this.featureBefore;
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
    this.mouseWheelZoom = new ol.interaction.MouseWheelZoom();
    this.mouseZoomTimeout;
    this.mapOptions = this.container.data('map-options');
    this.mapBackend = this.mapOptions.viewer || this.mapOptions.editor;
    this.defaultPosition = ObjectHelpers.select(this.mapOptions, ['latitude', 'longitude', 'zoom']);
    this.highDpi = window.devicePixelRatio > 1;
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
  mapBaseLayer() {
    if (typeof this['baseLayer' + this.mapBackend] == 'function') return this['baseLayer' + this.mapBackend]();
    else return this.baseLayerBaseMap();
  }
  baseLayerBaseMap() {
    return fetch('https://maps.wien.gv.at/basemap/1.0.0/WMTSCapabilities.xml')
      .then(response => response.text())
      .then(text => {
        let result = new ol.WMTSCapabilities().read(text);
        let options = optionsFromCapabilities(result, {
          layer: this.highDpi ? 'bmaphidpi' : 'geolandbasemap',
          matrixSet: 'google3857',
          style: 'normal'
        });

        options.attributions = '© <a href="https://www.basemap.at" target="_blank">basemap.at</a>';
        options.tilePixelRatio = this.hiDPI ? 2 : 1;

        return new ol.layer.Tile({
          source: new ol.source.WMTS(options)
        });
      });
  }
  baseLayerOpenStreetMap() {
    return Promise.resolve(
      new ol.layer.Tile({
        source: new ol.source.OSM()
      })
    );
  }
  baseLayerTourSprung() {
    return Promise.resolve(
      new ol.layer.Tile({
        source: new ol.source.XYZ({
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
  generateIconStyle(color) {
    return new ol.style.Style({
      image: new ol.style.Circle({
        radius: 7,
        fill: new ol.style.Fill({
          color: color
        }),
        stroke: new ol.style.Stroke({
          color: [0, 0, 0, 0.75],
          width: 1.5
        })
      }),
      zIndex: 100000
    });
  }
  generateLineStyle(color) {
    return new ol.style.Style({
      stroke: new ol.style.Stroke({ color: color, width: 5 })
    });
  }
  initIconStyles() {
    if (this.iconPaths !== undefined) {
      this.styles.icon.default = new ol.style.Style({
        image: new ol.style.Icon({
          anchor: [16, 32],
          anchorXUnits: 'pixels',
          anchorYUnits: 'pixels',
          src: this.iconPaths.default
        })
      });
    } else {
      this.styles.icon.default = this.generateIconStyle('#1779ba');
    }

    this.styles.icon.red = this.generateIconStyle('#cc4b37');
    this.styles.icon.green = this.generateIconStyle('#90c062');

    this.styles.line.default = this.generateLineStyle('#1779ba');
    this.styles.line.red = this.generateLineStyle('#cc4b37');
    this.styles.line.green = this.generateLineStyle('#90c062');
  }
  setFeatures(featureType) {
    if (this.afterValue && this.afterValue.length) {
      this.feature = this.createFeaturefromWkt(this.afterValue);
      this.feature.setStyle(this.styles[featureType].green);
    }
    if (this.beforeValue && this.beforeValue.length) {
      this.featureBefore = this.createFeaturefromWkt(this.beforeValue);
      this.featureBefore.setStyle(this.styles[featureType].red);
    }
    if (!this.afterValue || !this.afterValue.length) {
      this.feature = this.createFeaturefromWkt(this.value);
      this.feature.setStyle(this.styles[featureType].default);
    }
  }
  initFeatures() {
    switch (this.type) {
      case 'Point':
        this.setFeatures('icon');
        break;
      case 'LineString':
      case 'MultiLineString':
        this.setFeatures('line');
        break;
    }
  }
  createFeaturefromWkt(wkt) {
    let format = new ol.format.WKT();

    return format.readFeature(wkt, {
      dataProjection: 'EPSG:4326',
      featureProjection: 'EPSG:3857'
    });
  }
  configureFeatures() {
    if (this.feature !== undefined) this.features.push(this.feature);
    if (this.featureBefore !== undefined) this.features.push(this.featureBefore);

    if (this.features.length) {
      this.options = {
        features: this.features
      };
    }
  }
  configureLayerLines() {
    this.layerLines = new ol.layer.Vector({
      source: new ol.source.Vector(this.options),
      style: [
        new ol.style.Style({
          stroke: new ol.style.Stroke({
            color: '#c30000',
            width: 3
          }),
          image: new ol.style.Circle({
            radius: 3,
            fill: new ol.style.Fill({
              color: '#c30000'
            }),
            stroke: new ol.style.Stroke({
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
      this.map = new ol.Map({
        interactions: ol.interactions
          .defaults({
            mouseWheelZoom: false
          })
          .extend([this.mouseWheelZoom]),
        target: this.containerId,
        layers: [baseLayer, this.layerLines],
        view: new ol.View({
          center: [0, 0],
          zoom: 10
        })
      });
    });
  }
  setConfiguredDefaultPosition() {
    if (this.defaultPosition && this.defaultPosition.longitude && this.defaultPosition.latitude) {
      let newCoords = new ol.geom.Point([this.defaultPosition.longitude, this.defaultPosition.latitude]).transform(
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

    let extent = new ol.extent.createEmpty();
    if (this.feature) extent = new ol.extent.extend(extent, this.feature.getGeometry().getExtent());
    if (this.featureBefore) extent = new ol.extent.extend(extent, this.featureBefore.getGeometry().getExtent());

    this.map.getView().fit(extent, { padding: [50, 50, 50, 50], maxZoom: 15 });
  }
}

module.exports = OpenLayersViewer;

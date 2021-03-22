const ObjectHelpers = require('../helpers/object_helpers');

const ol = {
  Map: require('ol/map').default,
  layer: {
    Tile: require('ol/layer/tile').default,
    Vector: require('ol/layer/vector').default
  },
  Feature: require('ol/feature').default,
  format: {
    GeoJSON: require('ol/format/geojson').default
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
    MouseWheelZoom: require('ol/interaction/mousewheelzoom').default,
    Select: require('ol/interaction/select').default
  },
  events: {
    condition: require('ol/events/condition').default
  },
  interactions: require('ol/interaction').default,
  proj: require('ol/proj').default,
  WMTSCapabilities: require('ol/format/wmtscapabilities').default,
  deviceCapabilities: require('ol/has').default,
  overlay: require('ol/overlay').default,
  collection: require('ol/collection').default
};

const { optionsFromCapabilities } = require('ol/source/wmts').default;

const iconPaths = {
  default:
    'data:image/svg+xml;utf8,<svg width="21" height="33" version="1.1" viewBox="0 0 21 33" xmlns="http://www.w3.org/2000/svg"><path d="m10.5 0.5c-5.523 0-10 4.477-10 10 0 10 10 22 10 22s10-12 10-22c0-5.523-4.477-10-10-10z" fill="${color}" stroke="%23fff" stroke-linejoin="round" stroke-opacity=".8" style="paint-order:stroke markers fill"/><circle cx="10.574" cy="10.771" r="4.4524" fill-opacity=".8" fill="%23111"/></svg>',
  start:
    'data:image/svg+xml;utf8,<svg width="21" height="33" version="1.1" viewBox="0 0 21 33" xmlns="http://www.w3.org/2000/svg"><path d="m10.5 0.5c-5.523 0-10 4.477-10 10 0 10 10 22 10 22s10-12 10-22c0-5.523-4.477-10-10-10z" fill="${color}" stroke="%23fff" stroke-linejoin="round" stroke-opacity=".8" style="paint-order:stroke markers fill"/><path d="m16.253 11.621-8.9451 5.0275 0.11862-10.26z" fill="%23111" fill-opacity=".8"/></svg>',
  end:
    'data:image/svg+xml;utf8,<svg width="21" height="33" version="1.1" viewBox="0 0 21 33" xmlns="http://www.w3.org/2000/svg"><path d="m10.5 0.5c-5.523 0-10 4.477-10 10 0 10 10 22 10 22s10-12 10-22c0-5.523-4.477-10-10-10z" fill="${color}" stroke="%23fff" stroke-linejoin="round" stroke-opacity=".8" style="paint-order:stroke markers fill"/><rect x="6.042" y="7.3383" width="9.1903" height="8.3106" ry="0" fill="%23111" fill-opacity=".8"/></svg>'
};

class OpenLayersViewer {
  constructor(container) {
    this.$container = $(container);
    this.$parentContainer = this.$container.parent('.geographic');
    this.containerId = this.$container.attr('id');
    this.ol = ol;
    this.map;
    this.value = this.$container.data('value');
    this.beforeValue = this.$container.data('before-position');
    this.afterValue = this.$container.data('after-position');
    this.type = this.$container.data('type');
    this.additionalValues = this.$container.data('additionalValues');
    this.feature;
    this.additionalFeatures = [];
    this.infoOverlay;
    this.featureOverlay;
    this.featureOverlaySource;
    this.highlightedFeature;
    this.icons = iconPaths;
    this.colors = {
      default: '#1779ba',
      red: '#cc4b37',
      green: '#90c062'
    };
    this.scrollTexts = {
      ctrlKey: 'Strg+Scrollen zum Zoomen',
      metaKey: '⌘+Scrollen zum Zoomen',
      pinch: 'zwei Finger zum Zoomen/Scrollen'
    };
    this.zoomMethod = 'ctrlKey';
    this.featureLayer;
    this.mouseWheelZoom = new this.ol.interaction.MouseWheelZoom();
    this.mouseZoomTimeout;
    this.mapOptions = this.$container.data('map-options');
    this.mapBackend = this.mapOptions.viewer || this.mapOptions.editor;
    this.defaultPosition = ObjectHelpers.select(this.mapOptions, ['latitude', 'longitude', 'zoom']);
    this.highDpi = this.ol.deviceCapabilities.DEVICE_PIXEL_RATIO > 1;
    this.source;
    this.$popupContainer = this.$parentContainer.find('.ol-popup').first();
    this.$popupContent = this.$parentContainer.find('.ol-popup-content').first();
    this.$popupCloser = this.$parentContainer.find('.ol-popup-closer').first();
    this.featureProjection = {
      dataProjection: 'EPSG:4326',
      featureProjection: 'EPSG:3857'
    };
    this.geoJsonFormat = new this.ol.format.GeoJSON();
  }
  setup() {
    this.setZoomMethod();
    this.initFeatures();
    this.initMouseWheelZoom();

    this.initMap().then(() => {
      this.initMapHoverActions();
      this.updateMapPosition();
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
                src: this.icons[type].interpolate({ color: escape(this.colors[color]) })
              },
              additionalImageParameters
            )
          )
        },
        additionalParameters
      )
    );
  }
  generateLineStyle(props = {}) {
    props = Object.assign(
      {
        color: 'default',
        width: 5,
        background: false,
        backgroundColor: '#ffffff',
        backgroundWidth: (props.width || 5) + 2
      },
      props
    );

    let styles = [
      new this.ol.style.Style({
        stroke: new this.ol.style.Stroke({ color: this.colors[props.color], width: props.width })
      })
    ];

    if (props.background)
      styles.unshift(
        new this.ol.style.Style({
          stroke: new this.ol.style.Stroke({ color: props.backgroundColor, width: props.backgroundWidth })
        })
      );

    return styles;
  }
  initFeatures() {
    if (this.afterValue) this.feature = this.featureFromGeoJSON(this.afterValue);
    if (!this.feature && this.value) this.feature = this.featureFromGeoJSON(this.value);
    if (this.beforeValue) this.additionalFeatures = this.featuresFromGeoJSON(this.beforeValue);
    if (this.additionalValues && this.additionalValues.length)
      this.additionalFeatures.push(
        ...this.featuresFromGeoJSON({
          type: 'FeatureCollection',
          features: this.additionalValues
        })
      );

    if (this.$popupContainer.length) this.initInfoOverlay();
    this.initFeatureLayer();
  }
  initInfoOverlay() {
    this.infoOverlay = new this.ol.overlay({
      element: this.$popupContainer.get(0),
      autoPan: true
    });

    this.$popupCloser.on('click', event => {
      event.preventDefault();
      event.stopPropagation();

      this.infoOverlay.setPosition(undefined);
      this.$popupCloser.blur();
    });
  }
  initMapHoverActions() {
    this.featureOverlaySource = new this.ol.source.Vector();
    this.featureOverlay = new this.ol.layer.Vector({
      source: this.featureOverlaySource,
      map: this.map,
      style: this.highlightStyleFunction.bind(this)
    });

    this.map.on('pointermove', this.highlightFeature.bind(this));
    if (this.$popupContainer.length) this.map.on('singleclick', this.showInfoOverlay.bind(this));
  }
  showInfoOverlay(evt) {
    const pixel = this.map.getEventPixel(evt.originalEvent);
    let feature = this.map.getFeaturesAtPixel(pixel);
    feature = feature && feature[0];

    if (feature && feature.getProperties() && feature.getProperties().thingPath) {
      this.$popupContent.html(this.infoOverlayHtml(feature.getProperties()));
      this.infoOverlay.setPosition(evt.coordinate);
    } else if (this.infoOverlay.getPosition()) {
      this.infoOverlay.setPosition(undefined);
      this.$popupCloser.blur();
    }
  }
  infoOverlayHtml(featureProperties) {
    let html = '';

    if (featureProperties.thingPath && featureProperties.thingPath.length) {
      html += `<a href="${featureProperties.thingPath}" target="_blank" class="ol-popup-detail-link"><i class="fa fa-eye" aria-hidden="true"></i></a>`;
    }

    if (featureProperties.title && featureProperties.title.length) html += `<p>${featureProperties.title}</p>`;

    return html;
  }
  highlightFeature(evt) {
    if (evt.dragging) return;

    const pixel = this.map.getEventPixel(evt.originalEvent);
    let feature = this.map.getFeaturesAtPixel(pixel);
    feature = feature && feature.find(f => f.getGeometry().getType().includes('LineString'));

    if (feature !== this.highlightedFeature) {
      if (this.highlightedFeature) this.featureOverlaySource.removeFeature(this.highlightedFeature);
      if (feature) this.featureOverlaySource.addFeature(feature);

      this.highlightedFeature = feature;
    }
  }
  getFeatureStyle(feature) {
    let featureStyle = {
      color: 'default',
      width: 5,
      showStartEnd: false
    };
    const featureStyleProperties = feature.get('style');
    if (featureStyleProperties && featureStyleProperties.color) featureStyle.color = featureStyleProperties.color;
    if (featureStyleProperties && featureStyleProperties.width) featureStyle.width = featureStyleProperties.width;

    return featureStyle;
  }
  getStyles(feature, featureStyle) {
    const geometry = feature.getGeometry();
    let styles = [];

    if (featureStyle.showStartEnd && geometry.getType().includes('LineString')) {
      styles.push(
        this.generateIconStyle('end', featureStyle.color, {
          geometry: new this.ol.geom.Point(geometry.getLastCoordinate())
        })
      );
      styles.push(
        this.generateIconStyle('start', featureStyle.color, {
          geometry: new this.ol.geom.Point(geometry.getFirstCoordinate())
        })
      );
    } else if (geometry.getType() == 'Point') {
      styles.push(
        this.generateIconStyle('default', featureStyle.color, {
          geometry: new this.ol.geom.Point(geometry.getFirstCoordinate())
        })
      );
    }

    return styles;
  }
  highlightStyleFunction(feature) {
    const featureStyle = this.getFeatureStyle(feature);
    featureStyle.background = true;
    featureStyle.backgroundWidth = featureStyle.width + 4;
    featureStyle.showStartEnd = true;

    const styles = this.generateLineStyle(featureStyle);
    styles.push(...this.getStyles(feature, featureStyle));

    return styles;
  }
  styleFunction(feature) {
    const featureStyle = this.getFeatureStyle(feature);
    const styles = this.generateLineStyle(featureStyle);
    styles.push(...this.getStyles(feature, featureStyle));

    return styles;
  }
  featuresFromGeoJSON(geoJSON) {
    return this.geoJsonFormat.readFeatures(geoJSON, this.featureProjection);
  }
  featureFromGeoJSON(geoJSON) {
    return this.geoJsonFormat.readFeature(geoJSON, this.featureProjection);
  }
  initFeatureLayer() {
    let allFeatures = [];
    if (this.feature) allFeatures.push(this.feature);
    if (this.additionalFeatures && this.additionalFeatures.length) allFeatures.push(...this.additionalFeatures);

    this.source = new this.ol.source.Vector({
      features: allFeatures
    });

    this.featureLayer = new this.ol.layer.Vector({
      source: this.source,
      style: this.styleFunction.bind(this)
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
      const overlays = [];
      if (this.infoOverlay) overlays.push(this.infoOverlay);

      this.map = new this.ol.Map({
        interactions: this.ol.interactions
          .defaults({
            mouseWheelZoom: false
          })
          .extend([this.mouseWheelZoom]),
        target: this.containerId,
        overlays: overlays,
        layers: [baseLayer, this.featureLayer],
        view: this.defaultView()
      });
    });
  }
  defaultView() {
    const viewOptions = {
      zoom: 7,
      center: [1485643.2074492387, 6056497.724133261]
    };

    if (this.defaultPosition && this.defaultPosition.zoom) viewOptions.zoom = this.defaultPosition.zoom;
    if (this.defaultPosition && this.defaultPosition.longitude && this.defaultPosition.latitude) {
      let newCoords = new this.ol.geom.Point([this.defaultPosition.longitude, this.defaultPosition.latitude]).transform(
        'EPSG:4326',
        'EPSG:3857'
      );
      viewOptions.center = newCoords.getCoordinates();
    }

    return new this.ol.View(viewOptions);
  }
  updateMapPosition() {
    if (this.source.getFeatures().length)
      this.map.getView().fit(this.source.getExtent(), { padding: [50, 50, 50, 50], maxZoom: 15 });
  }
}

module.exports = OpenLayersViewer;

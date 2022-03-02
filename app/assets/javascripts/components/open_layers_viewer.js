import pick from 'lodash/pick';

import Map from 'ol/map';
import Feature from 'ol/feature';
import View from 'ol/view';
import extent from 'ol/extent';
import interactions from 'ol/interaction';
import controls from 'ol/control';
import proj from 'ol/proj';
import overlay from 'ol/overlay';
import collection from 'ol/collection';
import Tile from 'ol/layer/tile';
import VectorLayer from 'ol/layer/vector';
import GeoJSON from 'ol/format/geojson';
import WKT from 'ol/format/wkt';
import Point from 'ol/geom/point';
import LineString from 'ol/geom/linestring';
import MultiLineString from 'ol/geom/multilinestring';
import OSM from 'ol/source/osm';
import Vector from 'ol/source/vector';
import WMTS from 'ol/source/wmts';
import XYZ from 'ol/source/xyz';
import Style from 'ol/style/style';
import Stroke from 'ol/style/stroke';
import Circle from 'ol/style/circle';
import Fill from 'ol/style/fill';
import Text from 'ol/style/text';
import Icon from 'ol/style/icon';
import Draw from 'ol/interaction/draw';
import Translate from 'ol/interaction/translate';
import Snap from 'ol/interaction/snap';
import Modify from 'ol/interaction/modify';
import MouseWheelZoom from 'ol/interaction/mousewheelzoom';
import Select from 'ol/interaction/select';
import condition from 'ol/events/condition';
import FullScreen from 'ol/control/fullscreen';
import WMTSCapabilities from 'ol/format/wmtscapabilities';
import deviceCapabilities from 'ol/has';

const ol = {
  Map: Map,
  layer: {
    Tile,
    Vector: VectorLayer
  },
  Feature,
  format: {
    GeoJSON,
    WKT
  },
  geom: {
    Point,
    LineString,
    MultiLineString
  },
  source: {
    OSM,
    Vector,
    WMTS,
    XYZ
  },
  style: {
    Style,
    Stroke,
    Circle,
    Fill,
    Text,
    Icon
  },
  View,
  extent,
  interaction: {
    Draw,
    Translate,
    Snap,
    MouseWheelZoom,
    Select,
    Modify
  },
  events: {
    condition
  },
  control: {
    FullScreen
  },
  interactions,
  controls,
  proj,
  WMTSCapabilities,
  deviceCapabilities,
  overlay,
  collection
};

const iconPaths = {
  default:
    'data:image/svg+xml;utf8,<svg width="21.09" height="33.144" version="1.1" viewBox="0 0 21.09 33.144" xmlns="http://www.w3.org/2000/svg"><path d="m10.545 1c-5.2717 0-9.5449 4.2784-9.5449 9.5565 0 9.5565 9.5449 21.024 9.5449 21.024s9.5449-11.468 9.5449-21.024c0-5.2781-4.2733-9.5565-9.5449-9.5565z" fill="${color}" stroke="${strokeColor}" stroke-width="2" style="paint-order:normal"/><circle cx="10.545" cy="10.312" r="4.5249" fill="%23fff" fill-opacity="${opacity}"/></svg>',
  start:
    'data:image/svg+xml;utf8,<svg width="21.091" height="33.117" version="1.1" viewBox="0 0 21.091 33.117" xmlns="http://www.w3.org/2000/svg"><path d="m10.545 1c-5.2719 0-9.5453 4.2748-9.5453 9.5484 0 9.5484 9.5453 21.006 9.5453 21.006s9.5453-11.458 9.5453-21.006c0-5.2736-4.2734-9.5484-9.5453-9.5484z" fill="${color}" stroke="${strokeColor}" stroke-width="2" style="paint-order:normal"/><path d="m15.944 11.969-8.9451 5.0275 0.11862-10.26z" fill="%23fff" fill-opacity="${opacity}"/></svg>',
  end: 'data:image/svg+xml;utf8,<svg width="21.092" height="33.07" version="1.1" viewBox="0 0 21.092 33.07" xmlns="http://www.w3.org/2000/svg"><path d="m10.546 1c-5.2722 0-9.546 4.2685-9.546 9.5342 0 9.5342 9.546 20.975 9.546 20.975s9.546-11.441 9.546-20.975c0-5.2658-4.2737-9.5342-9.546-9.5342z" fill="${color}" stroke="${strokeColor}" stroke-width="2" style="paint-order:normal"/><rect x="5.9508" y="6.8043" width="9.1903" height="8.3106" ry="0" fill="%23fff" fill-opacity="${opacity}"/></svg>'
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
    this.additionalValues = this.$container.data('additionalValues') || {};
    this.additionalValuesOverlay = this.$container.data('additionalValuesOverlay');
    this.feature;
    this.additionalFeatures = [];
    this.infoOverlay;
    this.featureOverlay;
    this.featureOverlaySource;
    this.highlightedFeature;
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
      red: '#cc4b37',
      green: '#90c062',
      white: '#ffffff',
      gray: '#767676'
    };
    this.colors = new Proxy(this.definedColors, this.colorsHandler);
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
    this.defaultPosition = pick(this.mapOptions, ['latitude', 'longitude', 'zoom']);
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
    this.wktFormat = new this.ol.format.WKT();
    this.resizeObserver;
  }
  _createFeatureCollection(data = []) {
    return {
      type: 'FeatureCollection',
      features: data
    };
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
  async baseLayerBaseMap() {
    const response = await fetch('https://maps.wien.gv.at/basemap/1.0.0/WMTSCapabilities.xml');
    const text = await response.text();

    let result = new this.ol.WMTSCapabilities().read(text);
    let options = this.ol.source.WMTS.optionsFromCapabilities(result, {
      layer: this.highDpi ? 'bmaphidpi' : 'geolandbasemap',
      matrixSet: 'google3857',
      style: 'normal'
    });

    options.attributions = '© <a href="https://www.basemap.at" target="_blank">basemap.at</a>';
    options.tilePixelRatio = this.highDpi ? 2 : 1;

    return new this.ol.layer.Tile({
      source: new this.ol.source.WMTS(options)
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
  generateIconStyle(type, color, additionalParameters = {}, hover = false) {
    return new this.ol.style.Style(
      Object.assign(
        {
          image: new this.ol.style.Icon({
            anchor: [0.5, 1],
            opacity: 0.9,
            src: this.icons[type].interpolate({
              color: escape(this.colors[color]),
              strokeColor: escape(this.colors[hover ? 'white' : color]),
              opacity: hover ? 1 : 0.9
            })
          })
        },
        additionalParameters
      )
    );
  }
  generateLineStyle(props = {}) {
    props = Object.assign(
      {
        color: 'default',
        width: 4,
        background: false,
        backgroundColor: '#ffffff',
        backgroundWidth: (props.width || 4) + 2
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
    if (!this.feature && this.value) this.feature = this.featureFromGeoJSON(this.value);
    if (this.beforeValue) this.additionalFeatures = this.featuresFromGeoJSON(this.beforeValue);
    if (this.afterValue) this.feature = this.featureFromGeoJSON(this.afterValue);

    for (const geoJSON of Object.values(this.additionalValues)) {
      this.additionalFeatures.push(...this.featuresFromGeoJSON(geoJSON));
    }

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
    this.initResizeObserver();
    this.featureOverlaySource = new this.ol.source.Vector();
    this.featureOverlay = new this.ol.layer.Vector({
      source: this.featureOverlaySource,
      map: this.map,
      style: this.highlightStyleFunction.bind(this)
    });

    this.map.on('pointermove', this.highlightFeature.bind(this));
    if (this.$popupContainer.length) this.map.on('singleclick', this.showInfoOverlay.bind(this));
  }
  initResizeObserver() {
    this.resizeObserver = new ResizeObserver(_ => this.map.updateSize());
    this.resizeObserver.observe(document.body);
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

    if (featureProperties.name && featureProperties.name.length) html += `<p>${featureProperties.name}</p>`;

    return html;
  }
  cursor(feature) {
    if (this.drawing || (feature && feature.getProperties() && feature.getProperties().thingPath)) return 'pointer';

    return '';
  }
  highlightFeature(evt) {
    if (evt.dragging) return (this.map.getTargetElement().firstElementChild.style.cursor = 'grabbing');

    const feature = this.map.forEachFeatureAtPixel(evt.pixel, f => f);
    this.map.getTargetElement().firstElementChild.style.cursor = this.cursor(feature);

    if (feature !== this.highlightedFeature) {
      if (this.highlightedFeature) this.featureOverlaySource.removeFeature(this.highlightedFeature);
      if (feature) this.featureOverlaySource.addFeature(feature);

      this.highlightedFeature = feature;
    }
  }
  getFeatureStyle(feature) {
    let featureStyle = {
      color: 'default',
      width: 4,
      showStartEnd: false
    };

    Object.assign(featureStyle, feature.get('style') || {});

    return featureStyle;
  }
  getStyles(feature, featureStyle) {
    const geometry = feature.getGeometry();
    let styles = [];

    if (featureStyle.showStartEnd && geometry.getType().includes('LineString')) {
      styles.push(
        this.generateIconStyle(
          'end',
          featureStyle.color,
          {
            geometry: new this.ol.geom.Point(geometry.getLastCoordinate())
          },
          true
        )
      );
      styles.push(
        this.generateIconStyle(
          'start',
          featureStyle.color,
          {
            geometry: new this.ol.geom.Point(geometry.getFirstCoordinate())
          },
          true
        )
      );
    } else if (geometry.getType() == 'Point') {
      styles.push(
        this.generateIconStyle(
          'default',
          featureStyle.color,
          {
            geometry: new this.ol.geom.Point(geometry.getFirstCoordinate())
          },
          featureStyle.background
        )
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

    this.mouseWheelZoom.handleEvent = async function (e) {
      let type = e.type;
      if (type !== 'wheel') {
        return true;
      }

      if (!e.originalEvent[self.zoomMethod] && document.fullscreenElement != self.$container.get(0)) {
        if (!$(e.map.getTargetElement().firstElementChild).find('.scroll-overlay').length) {
          const $element = $(
            '<div class="scroll-overlay" style="display: none;"><div class="scroll-overlay-text"></div></div>'
          );

          $(e.map.getTargetElement().firstElementChild).find('canvas').after($element);

          I18n.translate(`frontend.map.scroll_notice.${self.zoomMethod}`).then(text => {
            $($element).find('.scroll-overlay-text').text(text);
          });
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
    const promise = this.mapBaseLayer();

    promise.then(baseLayer => {
      const overlays = [];
      if (this.infoOverlay) overlays.push(this.infoOverlay);

      this.map = new this.ol.Map({
        interactions: this.ol.interactions
          .defaults({
            mouseWheelZoom: false
          })
          .extend([this.mouseWheelZoom]),
        target: this.containerId,
        controls: this.ol.controls.defaults().extend([new this.ol.control.FullScreen()]),
        overlays: overlays,
        layers: [baseLayer, this.featureLayer],
        view: this.defaultView()
      });
    });

    return promise;
  }
  defaultView() {
    const viewOptions = {
      zoom: 7,
      center: [1485643.2074492387, 6056497.724133261]
    };

    if (this.defaultPosition && this.defaultPosition.zoom) viewOptions.zoom = this.defaultPosition.zoom;
    if (this.defaultPosition && this.defaultPosition.longitude && this.defaultPosition.latitude) {
      const newCoords = new this.ol.geom.Point([
        this.defaultPosition.longitude,
        this.defaultPosition.latitude
      ]).transform('EPSG:4326', 'EPSG:3857');
      viewOptions.center = newCoords.getCoordinates();
    }

    return new this.ol.View(viewOptions);
  }
  updateMapPosition() {
    if (this.source.getFeatures().length)
      this.map.getView().fit(this.source.getExtent(), { padding: [50, 50, 50, 50], maxZoom: 15 });
  }
}

export default OpenLayersViewer;

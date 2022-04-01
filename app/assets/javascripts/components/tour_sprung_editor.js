import OpenLayersEditor from './open_layers_editor';
import isEmpty from 'lodash/isEmpty';
import fetchInject from 'fetch-inject';
import AdditionalValuesFilterControl from './map_controls/mapbox_additional_values_filter_control';

const mtkLibrary = ['https://static.maptoolkit.net/mtk/v9.7.9/mtk.js'];
const defaultMtkScripts = [
  'https://static.maptoolkit.net/mtk/v9.7.9/mtk.css',
  'https://static.maptoolkit.net/api/v9.7.9/editor-gui.css',
  'https://static.maptoolkit.net/api/v9.7.9/editor-gui.js'
];
const mtkElevationProfile = [
  'https://static.maptoolkit.net/api/v9.7.9/elevationprofile.css',
  'https://static.maptoolkit.net/api/v9.7.9/elevationprofile.js'
];

class TourSprungEditor extends OpenLayersEditor {
  constructor(container) {
    super(container);

    this.credentials = this.mapOptions.credentials;
    this.routeMarkers = [];
    this.highlightedFeatures;
    this.map;
    this.editorGui;
    this.draggingMarker;
    this.selectedAdditionalSources = {};
    this.selectedAdditionalLayers = {};
    this.allRenderedLayers = [];
    this.showElevationProfile = this.$container.data('elevationProfile');
    this.elevationProfile;
    this.elevationProfilePromise;
    this.keyFiguresMapping = {
      length: 'distance',
      max_altitude: 'highest_point',
      min_altitude: 'lowest_point'
    };
  }
  static isAllowedType(type) {
    return type && type.includes('LineString');
  }
  setup() {
    this.setZoomMethod();

    this.loadExtenalScripts()
      .then(this.initMap.bind(this))
      .catch(e => {
        console.error('failed to load MapToolKit!', e);
      });
  }
  async loadExtenalScripts() {
    return await fetchInject(defaultMtkScripts, fetchInject(mtkLibrary));
  }
  _styleControlWithOptions() {
    const controlConfig = {};

    if (this.mapOptions.maptypes) controlConfig.maptypes = this.mapOptions.maptypes;
    if (this.mapOptions.maplayers)
      controlConfig.layers = this.mapOptions.maplayers.map(v => {
        v.value = new MTK.StyleLayer(v.value);
        return v;
      });

    return new MTK.StyleControl(controlConfig);
  }
  initMap() {
    MTK.init({ apiKey: this.credentials.api_key, language: document.documentElement.lang }).createMap(
      this.containerId,
      {
        map: {
          mapType: this.mapOptions.maptype || 'toursprung-terrain',
          location: this.defaultView(),
          controls: []
        }
      },
      this.configureMap.bind(this)
    );
    this.initEventHandlers();
  }
  initEventHandlers() {
    this.$container.on('dc:import:data', this.importData.bind(this)).addClass('dc-import-data');
    this.$container.on('dc:geoKeyFigure:compute', this._computeKeyFigure.bind(this));
  }
  _setElevationProfileFromFeature() {
    this.elevationProfilePromise = new Promise(async (resolve, _reject) => {
      if (!this.elevationProfile) await this._renderElevationProfile();

      this.elevationProfile.setPolyline(this.feature, {}, () => resolve());
    });
  }
  async _computeKeyFigure(event, data = {}) {
    event.preventDefault();

    if (!this.elevationProfile && !this.elevationProfilePromise) this._setElevationProfileFromFeature();

    await this.elevationProfilePromise;
    this.elevationProfilePromise = null;

    const keyFigures = this.elevationProfile.getData();
    const key = data.attributeKey;

    if (!key || !keyFigures) return;

    data.callback(Math.round(keyFigures[this.keyFiguresMapping[key] || key]));
  }
  configureMap(map) {
    this.map = map;

    if (this.mapOptions.i18n) MTK.i18n = Object.assign({}, this.mapOptions.i18n);

    this.configureEditor();

    if (this.value) this.drawInitialRoute();
    this.initMtkEvents();

    this.drawAdditionalFeatures();
    this.updateMapPosition();
  }
  _disableScrollingOnMapOverlays() {
    this.$parentContainer.siblings('.map-info').on('wheel', event => {
      if (event.originalEvent[this.zoomMethod]) event.preventDefault();
    });

    this.$container.on('wheel', event => {
      if (event.originalEvent[this.zoomMethod]) event.preventDefault();
    });
  }
  initMouseWheelZoom() {
    this.map.gl.scrollZoom.disable();

    this.map.gl.on('wheel', event => {
      if (!event.originalEvent[this.zoomMethod] && document.fullscreenElement != this.$container.get(0)) {
        if (this.map.gl.scrollZoom._enabled) this.map.gl.scrollZoom.disable();

        if (!this.$container.find('.scroll-overlay').length) {
          const $element = $(
            '<div class="scroll-overlay" style="display: none;"><div class="scroll-overlay-text"></div></div>'
          );

          this.$container.append($element);

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

        if (!this.map.gl.scrollZoom._enabled) this.map.gl.scrollZoom.enable();

        this.$container.find('.scroll-overlay').fadeOut(100);
      }
    });
  }
  initMtkEvents() {
    this._disableScrollingOnMapOverlays();
    this.initMouseWheelZoom();

    MTK.event.addListener(this.editorGui.editor, 'update', () => {
      this.feature = this.editorGui.editor.getPolyline();

      this.setHiddenFieldValue(this.getGeoJsonFromFeature());

      if (this.showElevationProfile || this.elevationProfile) this._setElevationProfileFromFeature();
    });

    this.map.on('maptypechanged', _event => {
      this.allRenderedLayers = [];
      this.drawAdditionalFeatures();
      this._changeMtkLineStyle();
    });
  }
  drawInitialRoute() {
    this.editorGui.editor.loadGeoJSON(this._createFeatureCollection([this.value]));

    this.feature = this.editorGui.editor.getPolyline();
  }
  iconOptions(type = 'default', hover = false, color = 'default') {
    const iconId = `marker-icon-${type}-${color}-${hover ? 'hovered' : 'not-hovered'}`;

    const imageUrl = this.icons[type].interpolate({
      color: escape(this.colors[color]),
      strokeColor: escape(this.colors[hover ? 'white' : color]),
      opacity: hover ? 1 : 0.9
    });

    if (this.map.gl.hasImage(iconId)) return iconId;

    let customIcon = new Image(21, 33);
    customIcon.onload = () => {
      if (this.map.gl.hasImage(iconId)) {
        customIcon = null;
        return;
      }

      this.map.gl.addImage(iconId, customIcon);
    };
    customIcon.src = imageUrl;

    return iconId;
  }
  lineStyle(options = {}) {
    return Object.assign(
      {
        color: this.colors.default,
        opacity: 1,
        width: 5
      },
      options
    );
  }
  _getLastLineLayerId() {
    return this.map.gl
      .getStyle()
      .layers.find(
        l =>
          (l.type === 'background' && l.id === 'mtk-raster-layers') || (l.type === 'line' && l.id.includes('selected'))
      ).id;
  }
  _getLastPointLayerId() {
    return this.map.gl
      .getStyle()
      .layers.find(
        l =>
          (l.type === 'background' && l.id === 'mtk-symbol-layers') ||
          (l.type === 'symbol' && l.source === 'mtk-editor-1') ||
          (l.type === 'circle' && l.id.includes('selected'))
      ).id;
  }
  _additionalLineLayer(key) {
    const layerId = `additional_values_line_${key}`;

    this.map.gl.addLayer(
      {
        id: layerId,
        type: 'line',
        source: `additional_values_${key}`,
        filter: ['==', '$type', 'LineString'],
        paint: {
          'line-color': key.includes('selected') ? this.definedColors.default : this.definedColors.gray,
          'line-opacity': key.includes('selected') ? 1 : 0.75,
          'line-width': 5
        }
      },
      this._getLastLineLayerId()
    );

    this.allRenderedLayers.push(layerId);

    return layerId;
  }
  _additionalPointLayer(key) {
    const layerId = `additional_values_point_${key}`;

    this.map.gl.addLayer(
      {
        id: layerId,
        type: 'circle',
        source: `additional_values_${key}`,
        filter: ['==', '$type', 'Point'],
        paint: {
          'circle-radius': key.includes('selected') ? 7 : 5,
          'circle-stroke-width': 2,
          'circle-color': key.includes('selected') ? this.definedColors.red : this.definedColors.default,
          'circle-stroke-color': this.definedColors.white
        }
      },
      this._getLastPointLayerId()
    );

    this.allRenderedLayers.push(layerId);

    return layerId;
  }
  _addPopup() {
    const popup = new mapboxgl.Popup({
      closeButton: false,
      closeOnClick: false,
      className: 'additional-feature-popup'
    });

    this.map.gl.on('mousemove', e => {
      const feature = this.map.gl.queryRenderedFeatures(e.point, { layers: this.allRenderedLayers })[0];

      if (feature) {
        this.map.gl.getCanvas().style.cursor = 'pointer';
        popup
          .setLngLat(feature.geometry.type !== 'Point' ? e.lngLat : feature.geometry.coordinates)
          .setHTML(feature.properties.name)
          .addTo(this.map.gl);
      } else {
        this.map.gl.getCanvas().style.cursor = '';
        popup.remove();
      }
    });
  }
  _addSelectedSourceAndLayers(key, data) {
    this.selectedAdditionalSources[key] = `additional_values_selected_${key}`;

    this.map.gl.addSource(this.selectedAdditionalSources[key], {
      type: 'geojson',
      data: data
    });

    this.selectedAdditionalLayers[key] = {
      point: this._additionalPointLayer(`selected_${key}`),
      line: this._additionalLineLayer(`selected_${key}`)
    };
  }
  drawAdditionalFeatures() {
    for (const [key, value] of Object.entries(this.additionalValues)) {
      this._addSelectedSourceAndLayers(key, value);
    }

    this._addPopup();
  }
  extendEditorInterface() {
    const uploadable = this.uploadable;

    class CustomEditorInterface extends MTK.EditorInterface {
      _replacefileUploadControl(parent, b) {
        const mtkImport = parent.querySelector('.mtk-editor-import');

        if (uploadable) {
          this.editor.loadFile = function ($input) {
            this.uploadFile($input, (_err, d) => {
              this.setWaypoints(d.waypoints);

              b.fitBounds(d.bounds, { padding: 50 });
            });
          };

          const el = document.createElement('button');
          el.className = 'dc-mtk-button dc-mtk-import-gpx';

          el.addEventListener('click', event => {
            event.preventDefault();
            event.stopImmediatePropagation();

            event.currentTarget.parentElement.querySelector('input[type="file"]').click();
          });

          const input = document.createElement('input');
          input.setAttribute('type', 'file');
          input.setAttribute('hidden', true);
          input.setAttribute('accept', '.gpx,.kml,.geojson');
          input.addEventListener('change', event => {
            event.preventDefault();
            event.stopImmediatePropagation();

            this.editor.loadFile(event.currentTarget);
          });

          while (mtkImport.firstChild) {
            mtkImport.firstChild.remove();
          }

          mtkImport.appendChild(input);
          mtkImport.appendChild(el);
        } else {
          mtkImport.remove();
        }
      }
      onAdd(b) {
        const container = super.onAdd(b);

        b.addControl(new mapboxgl.NavigationControl(), 'top-left');

        container.querySelector('.mtk-editor-routing').remove(); // remove bike/car/foot icons

        const buttons = container.querySelectorAll('.mtk-editor-button');

        for (let i = 0; i < buttons.length; ++i) {
          buttons[i].addEventListener('click', event => {
            event.preventDefault();
          });
        }

        this._replacefileUploadControl(container, b);

        return container;
      }
    }

    this.extendedEditorInterface = CustomEditorInterface;
  }
  _captureClickEvents() {
    const mapBoxControls = this.$container.get(0).querySelectorAll('.mapboxgl-ctrl');
    for (const control of mapBoxControls) {
      control.addEventListener('click', event => {
        event.preventDefault();
      });
    }
  }
  _changeMtkLineStyle() {
    const waypointLayerDefinition = this.editorGui.editor.getLayerDefinitions().find(v => v.type == 'symbol');

    const waypointLayerId = waypointLayerDefinition && waypointLayerDefinition.id;
    if (waypointLayerId) {
      this.map.gl.setLayoutProperty(waypointLayerId, 'icon-size', [
        'case',
        ['==', ['get', 'icon'], 'end'],
        0.8,
        ['==', ['get', 'icon'], 'start'],
        0.6,
        0.3
      ]);
    }

    this.editorGui.editor.outline.width = 0;
    Object.assign(this.editorGui.editor.line, this.lineStyle());
    Object.assign(this.editorGui.editor.dashedLine, this.lineStyle());
  }
  async _renderElevationProfile() {
    if (!this.elevationProfile) await fetchInject(mtkElevationProfile);

    this.elevationProfile = new MTK.ElevationProfile();
    this.elevationProfile._container.querySelector('rect.mtk-elevation-close').dispatchEvent(new Event('click'));
    if (this.showElevationProfile) this.elevationProfile.addTo(this.map);
    this.$container.trigger('dc:map:elevationProfileInitialized');
  }
  configureEditor() {
    this.map.gl.addControl(new mapboxgl.NavigationControl(), 'top-left');
    new MTK.GeocoderControl().addTo(this.map, 'top-right');
    this.map.gl.addControl(new mapboxgl.FullscreenControl(), 'top-right');
    this._styleControlWithOptions().addTo(this.map, 'bottom-right');

    this.extendEditorInterface();
    this._captureClickEvents();

    this.editorGui = new this.extendedEditorInterface().addTo(this.map);

    if (!isEmpty(this.additionalValuesOverlay))
      this.map.gl.addControl(new AdditionalValuesFilterControl(this), 'top-left');

    this._changeMtkLineStyle();
  }
  defaultView() {
    const viewOptions = {
      zoom: 7,
      center: [13.34576, 47.69642]
    };

    if (this.defaultPosition && this.defaultPosition.zoom) viewOptions.zoom = this.defaultPosition.zoom;
    if (this.defaultPosition && this.defaultPosition.longitude && this.defaultPosition.latitude)
      viewOptions.center = [this.defaultPosition.longitude, this.defaultPosition.latitude];

    return viewOptions;
  }
  getGeoJsonFromFeature() {
    if (!this.feature) return;

    let geometry = this.feature.toGeoJSON(this.precision).geometry;

    geometry.coordinates = this.shortenCoordinates(geometry.coordinates);

    return geometry;
  }
  updateFeature(_geometry) {
    if (this.feature) {
      this.feature.remove();
      this.feature = undefined;
    }

    if (this.value) this.drawInitialRoute();

    this.setNewCoordinates();
  }
  setNewCoordinates() {
    this.setHiddenFieldValue(this.getGeoJsonFromFeature());

    if (this.feature)
      this.map.gl.flyTo({
        center: this.feature.lngLat
      });
  }
  getBoundsForGeojson(geoJson) {
    const bounds = new mapboxgl.LngLatBounds();

    for (const feature of geoJson.features) {
      if (!feature || !feature.geometry) continue;

      if (feature.geometry.type === 'Point') bounds.extend(feature.geometry.coordinates);
      else if (feature.geometry.type === 'MultiLineString') {
        for (const lineStrings of feature.geometry.coordinates) {
          for (const coords of lineStrings) bounds.extend([coords[0], coords[1]]);
        }
      }
    }

    return bounds;
  }
  updateMapPosition() {
    let bounds = new mapboxgl.LngLatBounds();

    if (this.feature) bounds.extend(this.feature.getBounds());

    for (const geoJson of Object.values(this.additionalValues)) {
      bounds.extend(this.getBoundsForGeojson(geoJson));
    }

    if (isEmpty(bounds)) return;

    this.map.gl.fitBounds(bounds, {
      padding: 50,
      maxZoom: 15
    });
  }
}

export default TourSprungEditor;

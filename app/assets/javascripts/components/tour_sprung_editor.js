import OpenLayersEditor from './open_layers_editor';
import isEmpty from 'lodash/isEmpty';
import fetchInject from 'fetch-inject';
import AdditionalValuesFilterControl from './map_controls/mapbox_additional_values_filter_control';

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
    this.$poisTarget =
      this.additionalAttributes &&
      this.additionalAttributes.toursprung_pois_target &&
      this.$parentContainer
        .closest('.form-element.geographic')
        .siblings(`.form-element[data-key*="[${this.additionalAttributes.toursprung_pois_target}]"]`)
        .find('.object-browser');
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
    return await fetchInject(
      [
        'https://static.maptoolkit.net/mtk/v9.7.8/mtk.css',
        'https://static.maptoolkit.net/api/v9.7.8/editor-gui.css',
        'https://static.maptoolkit.net/api/v9.7.8/editor-gui.js'
      ],
      fetchInject(['https://static.maptoolkit.net/mtk/v9.7.8/mtk.js'])
    );
  }
  initMap() {
    MTK.init({ apiKey: this.credentials.api_key, language: document.documentElement.lang }).createMap(
      this.containerId,
      {
        map: {
          mapType: 'toursprung-terrain',
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
  }
  configureMap(map) {
    this.map = map;

    this.configureEditor();

    if (this.value) this.drawInitialRoute();
    this.initMtkEvents();

    this.drawAdditionalFeatures();
    this.updateMapPosition();
  }
  initMouseWheelZoom() {
    this.map.gl.scrollZoom.disable();

    this.map.gl.on('wheel', event => {
      if (!event.originalEvent[this.zoomMethod]) {
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
    this.initMouseWheelZoom();

    if (this.editorGui.pois && this.$poisTarget.length) {
      MTK.event.addListener(this.editorGui.pois, 'selected', (pois, triggerTarget = true) => {
        if (!triggerTarget) return;

        this.$poisTarget.trigger('dc:import:data', {
          value: Object.values(pois.getSelected()).map(v => v.remoteid),
          replace: true
        });
      });
    }

    MTK.event.addListener(this.editorGui.editor, 'update', () => {
      this.feature = this.editorGui.editor.getPolyline();

      this.setHiddenFieldValue(this.getGeoJsonFromFeature());
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
          'line-width': key.includes('selected') ? 7 : 5
        }
      },
      this._getLastLineLayerId()
    );

    // this._addPopupForLayer(layerId);

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

    // this._addPopupForLayer(layerId);

    return layerId;
  }
  _addPopup() {
    const popup = new mapboxgl.Popup({
      closeButton: false,
      closeOnClick: false,
      className: 'additional-feature-popup'
    });

    this.map.gl.on('mousemove', e => {
      // Change the cursor style as a UI indicator.
      // this.map.gl.getCanvas().style.cursor = 'pointer';

      console.log(this.selectedAdditionalLayers, this.map.gl);

      const features = this.map.gl.queryRenderedFeatures(e.point, { layers: ['Equipements'] });

      // const description = e.features[0].properties.name;

      // Populate the popup and set its coordinates
      // based on the feature found.
      // popup.setLngLat(e.lngLat).setHTML(description).addTo(this.map.gl);
    });

    // this.map.gl.on('mouseleave', layerId, e => {
    //   this.map.gl.getCanvas().style.cursor = '';
    //   popup.remove();
    // });
  }
  drawAdditionalFeatures() {
    for (const [key, value] of Object.entries(this.additionalValues)) {
      this.selectedAdditionalSources[key] = `additional_values_selected_${key}`;

      this.map.gl.addSource(this.selectedAdditionalSources[key], {
        type: 'geojson',
        data: value
      });

      this.selectedAdditionalLayers[key] = {
        point: this._additionalPointLayer(`selected_${key}`),
        line: this._additionalLineLayer(`selected_${key}`)
      };
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

        container.querySelector('.mtk-editor-routing').remove();
        container.querySelector('.mtk-editor-reverse-route').remove();

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
  configureEditor() {
    this.map.gl.addControl(new mapboxgl.NavigationControl(), 'top-left');
    this.map.gl.addControl(new mapboxgl.FullscreenControl(), 'top-right');
    if (!isEmpty(this.additionalValuesOverlay))
      this.map.gl.addControl(new AdditionalValuesFilterControl(this), 'bottom-left');

    this.extendEditorInterface();

    this.editorGui = new this.extendedEditorInterface().addTo(this.map);

    const waypointLayerDefinition = this.editorGui.editor.getLayerDefinitions().find(v => v.type == 'symbol');
    const waypointLayerId = waypointLayerDefinition && waypointLayerDefinition.id;
    if (waypointLayerId)
      this.map.gl.setLayoutProperty(waypointLayerId, 'icon-size', [
        'case',
        ['==', ['get', 'icon'], 'end'],
        0.8,
        ['==', ['get', 'icon'], 'start'],
        0.6,
        0
      ]);

    this.editorGui.editor.outline.width = 0;
    Object.assign(this.editorGui.editor.line, this.lineStyle());
    Object.assign(this.editorGui.editor.dashedLine, this.lineStyle());
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

    this.map.gl.fitBounds(bounds, {
      padding: 50,
      maxZoom: 15
    });
  }
}

export default TourSprungEditor;

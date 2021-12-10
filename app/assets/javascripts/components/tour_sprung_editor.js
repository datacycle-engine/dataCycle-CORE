import OpenLayersEditor from './open_layers_editor';
import lodashGet from 'lodash/get';
import fetchInject from 'fetch-inject';

class TourSprungEditor extends OpenLayersEditor {
  constructor(container) {
    super(container);

    this.credentials = this.mapOptions.credentials;
    this.routeMarkers = [];
    this.highlightedFeatures;
    this.map;
    this.editorGui;
    this.draggingMarker;
    this.pois = this.additionalAttributes && this.additionalAttributes.toursprung_pois;
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
    this.$container.on('dc:import:data', this.importData.bind(this));
  }
  configureMap(map) {
    this.map = map;

    this.configureEditor();

    if (this.value) this.drawInitialRoute();
    this.initMtkEvents();

    if (this.additionalValues && this.additionalValues.length) this.drawAdditionalFeatures();
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

      this.setHiddenFieldValue(this.feature.toGeoJSON().geometry);
    });
  }
  drawInitialRoute() {
    this.editorGui.editor.loadGeoJSON({
      type: 'FeatureCollection',
      features: [this.value]
    });

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
  _addAdditionalPointsLayer() {
    return new MTK.CollectionLayer(MTK.Marker, {
      states: {
        click: {
          'mtk:popup': {
            html: '${description}'
          }
        }
      }
    }).addTo(this.map);
  }
  _addAdditionalLinesLayer() {
    return new MTK.CollectionLayer(MTK.Polyline, {
      states: {
        click: {
          'mtk:popup': {
            html: '${description}'
          }
        }
      }
    }).addTo(this.map);
  }
  drawAdditionalFeatures() {
    this.additionalPointsLayer = this._addAdditionalPointsLayer();
    this.additionalLinesLayer = this._addAdditionalLinesLayer();

    const pois = [];

    for (let i = 0; i < this.additionalValues.length; ++i) {
      const feature = this.additionalValues[i];

      if (feature.geometry.type == 'Point') {
        if (this.pois && this.editorGui.pois) {
          pois.push(feature.properties.id);
        } else {
          const iconId = this.iconOptions('default', false, lodashGet(feature, 'properties.style.color', 'default'));
          const newMarker = new MTK.Marker({
            description: this.infoOverlayHtml(feature.properties)
          })
            .setLngLat(feature.geometry.coordinates)
            .setImage({ id: iconId, anchor: 'bottom' });

          this.additionalFeatures.push(newMarker);

          this.additionalPointsLayer.addLayer(newMarker);
        }
      } else {
        const newLine = new MTK.Polyline({
          description: this.infoOverlayHtml(feature.properties)
        }).setLngLats(feature.geometry.coordinates);

        this.additionalFeatures.push(newLine);

        this.additionalLinesLayer.addLayer(newLine);
      }
    }

    this._renderAdditionalPointsAsPois(pois);
  }
  _renderAdditionalPointsAsPois(pois) {
    if (!pois.length) return;

    for (let i = 0; i < this.pois.length; ++i) {
      fetch(
        `https://resource.maptoolkit.net/${this.pois[i].resource.name}/search.json?api_key=${
          this.credentials.api_key
        }&remoteids=${pois.join(',')}`
      ).then(response => {
        if (response.ok)
          response.json().then(result => {
            if (!result || !result.features || !result.features.length) return;

            for (let j = 0; j < result.features.length; ++j) {
              const feature = result.features[j];

              if (this.editorGui.pois._selected[feature.id]) return;

              feature.properties.resource = result.properties.resource;
              this.editorGui.pois._selected[feature.id] = feature;
              this.editorGui.pois._updateLayer();
              this.editorGui.pois._updateResource();
              this.editorGui.pois.fire('selected', this.editorGui.pois, false);
              this.editorGui.pois.enabled = false;
            }
          });
      });
    }
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

    this.extendEditorInterface();

    this.editorGui = new this.extendedEditorInterface({
      pois: this.pois
    }).addTo(this.map);

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
    this.setCoordinates();
    this.setHiddenFieldValue(this.getGeoJsonFromFeature());

    if (this.feature)
      this.map.gl.flyTo({
        center: this.feature.lngLat
      });
  }
  updateMapPosition() {
    let bounds = new mapboxgl.LngLatBounds();

    if (this.feature) bounds.extend(this.feature.getBounds());
    if (this.additionalFeatures && this.additionalFeatures.length) {
      bounds.extend(this.additionalPointsLayer.getBounds());
      bounds.extend(this.additionalLinesLayer.getBounds());
    }

    this.map.gl.fitBounds(bounds, {
      padding: 50,
      maxZoom: 15
    });
  }
}

export default TourSprungEditor;

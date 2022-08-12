import MapLibreGlViewer from './maplibre_gl_viewer';
import maplibregl from 'maplibre-gl/dist/maplibre-gl';

class MapLibreGlDashboard extends MapLibreGlViewer {
  constructor(container) {
    super(container);
    this.language = this.$container.data('language');

    this.definedColors = {
      default: '#cc4b37',
      blue: '#1779ba',
      lightBlue: '#1dbde5',
      red: '#cc4b37',
      green: '#90c062',
      white: '#ffffff',
      yellow: '#ffae00',
      gray: '#767676'
    };
  }
  configureMap() {
    this.initMvt();

    this.initControls();
    this.setZoomMethod();
    this.setIcons();

    this._disableScrollingOnMapOverlays();
    this.initMouseWheelZoom();
    this.initEventHandlers();
  }
  initMvt() {
    // TODO: add Popup, zoom to full extent?

    const searchForm = document.getElementById('search-form');
    if (!searchForm) return;
    const currentStoredFilterId = searchForm.dataset.storedFilter;

    this.map.addSource('mvt-source', {
      type: 'vector',
      tiles: [`http://localhost:3003/mvt/v1/endpoints/${currentStoredFilterId}/{z}/{x}/{y}.pbf`],
      minzoom: 0,
      maxzoom: 22
    });

    this.map.addLayer({
      id: 'mvt-points',
      type: 'circle',
      source: 'mvt-source',
      'source-layer': 'dataCycle',
      filter: ['==', '$type', 'Point'],
      paint: {
        'circle-radius': 5,
        'circle-stroke-width': 4,
        'circle-color': this.getStyleCaseExpression(
          'color',
          this.getColorMatchHexExpression(),
          this.definedColors.default
        ),
        'circle-stroke-color': this.definedColors.white
      }
    });
    this.map.addLayer({
      id: 'mvt-line',
      type: 'line',
      source: 'mvt-source',
      'source-layer': 'dataCycle',
      filter: ['==', '$type', 'LineString'],
      layout: {
        'line-cap': 'round',
        'line-join': 'round'
      },
      paint: {
        'line-color': this.getStyleCaseExpression(
          'color',
          this.getColorMatchHexExpression(),
          this.definedColors.default
        ),
        'line-opacity': 1,
        'line-width': this.getStyleCaseExpression('width', ['get', 'width'], 5)
      }
    });
  }
  initFeatures() {
    this.drawFeatures();
    this.drawAdditionalFeatures();
    this.updateMapPosition();
  }
  initEventHandlers() {
    this._addPopup();
    this._addClickHandler();
  }
  _addPopup() {
    const popup = new maplibregl.Popup({
      closeButton: false,
      closeOnClick: false,
      className: 'additional-feature-popup'
    });

    this.map.on('mousemove', e => {
      const feature = this.map.queryRenderedFeatures(e.point)[0];

      if (feature && feature.source == 'feature_source_primary') {
        this.map.getCanvas().style.cursor = 'pointer';
        popup
          .setLngLat(feature.geometry.type !== 'Point' ? e.lngLat : feature.geometry.coordinates)
          .setHTML(feature.properties.name)
          .addTo(this.map);

        this._highlightLinked(feature);
      } else {
        this.map.getCanvas().style.cursor = '';
        popup.remove();
      }
    });
  }
  _addClickHandler() {
    this.map.on('click', e => {
      const feature = this.map.queryRenderedFeatures(e.point)[0];
      if (feature && feature.source == 'feature_source_primary') {
        const url = new URL(window.location);
        url.search = '';
        window.open(`${url}things/${feature.id}`, '_blank');
      }
    });
  }
}

export default MapLibreGlDashboard;

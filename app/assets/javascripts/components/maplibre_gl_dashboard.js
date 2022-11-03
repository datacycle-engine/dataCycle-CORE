import MapLibreGlViewer from './maplibre_gl_viewer';
import maplibregl from 'maplibre-gl/dist/maplibre-gl';

class MapLibreGlDashboard extends MapLibreGlViewer {
  constructor(container) {
    super(container);
    this.language = this.$container.data('language');
    this.styleCaseProperty = '@type';
    this.iconColorBase = this.typeColors;
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
        let types = JSON.parse(feature.properties['@type']);
        let type = types[types.length - 1].replace('dcls:', '');
        popup
          .setLngLat(feature.geometry.type !== 'Point' ? e.lngLat : feature.geometry.coordinates)
          .setHTML(`<b>${type}</b><br> ${feature.properties.name}`)
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
  getColorMatchHexExpression() {
    let matchEx = ['case'];

    for (const [name, value] of Object.entries(this.typeColors)) {
      matchEx.push(['in', name, ['get', '@type']]);
      matchEx.push(value);
    }

    matchEx.push(this.typeColors.default);
    return matchEx;
  }
  getHoverColorMatchHexExpression() {
    return this.typeColors.hover;
  }
  getLineHoverColorExpression() {
    return 'start_hover';
  }
}

export default MapLibreGlDashboard;

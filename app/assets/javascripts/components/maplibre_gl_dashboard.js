import MapLibreGlViewer from './maplibre_gl_viewer';

class MapLibreGlDashboard extends MapLibreGlViewer {
  constructor(container) {
    super(container);
    this.language = this.$container.data('language');
    this.styleCaseProperty = '@type';
    this.iconColorBase = this.typeColors;
    this.sourceLayer = 'dataCycle';

    this.searchForm = document.getElementById('search-form');
    this.currentStoredFilterId = this.searchForm.dataset.storedFilter;
  }
  configureMap() {
    super.configureMap();
    this.initEventHandlers();
  }
  initFeatures() {
    this.drawFeatures();
  }
  initEventHandlers() {
    this._addPopup();
    this._addClickHandler();
  }
  drawFeatures() {
    this._addSourceAndLayer('primary', null);
  }
  _addSourceType(name, _data) {
    this.map.addSource(name, {
      type: 'vector',
      tiles: [`${location.protocol}//${location.host}/mvt/v1/endpoints/${this.currentStoredFilterId}/{z}/{x}/{y}.pbf`],
      promoteId: '@id',
      minzoom: 0,
      maxzoom: 22
    });
  }
  _addPopup() {
    const popup = new this.maplibreGl.Popup({
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
  updateMapPosition() {
    this.bboxForCurrentStoredFilter().then(bbox => {
      if (Object.values(bbox).includes(null)) return;

      const sw = new this.maplibreGl.LngLat(bbox.xmin, bbox.ymin);
      const ne = new this.maplibreGl.LngLat(bbox.xmax, bbox.ymax);
      const bounds = new this.maplibreGl.LngLatBounds(sw, ne);

      this.map.fitBounds(bounds, {
        padding: 50,
        maxZoom: 15
      });
    });
  }
  async bboxForCurrentStoredFilter() {
    const params = {
      bbox: true
    };

    let data = await DataCycle.httpRequest({
      url: `/mvt/v1/endpoints/${this.currentStoredFilterId}`,
      method: 'POST',
      data: params,
      dataType: 'json'
    });
    return data;
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

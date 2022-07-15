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
  setup() {
    super.setup();

    const $element = $(
      '<div class="loading-overlay"><div class="loading-overlay-text"><i class="fa fa-spinner fa-spin fa-fw fa-2xl"></i></div></div>'
    );
    this.$container.append($element);
  }
  configureMap() {
    this.storedFilterGeoJson().then(() => {
      this.$container.find('.loading-overlay').fadeOut(100);
      this.initFeatures();
    });

    this.initControls();
    this.setZoomMethod();
    this.setIcons();

    this._disableScrollingOnMapOverlays();
    this.initMouseWheelZoom();
    this.initEventHandlers();
  }
  initFeatures() {
    this.drawFeatures();
    this.drawAdditionalFeatures();
    this.updateMapPosition();
  }
  async storedFilterGeoJson() {
    const searchForm = document.getElementById('search-form');
    if (!searchForm) return;
    const currentStoredFilterId = searchForm.dataset.storedFilter;
    const params = {
      language: this.language.join(','),
      filter: { geo: { withGeometry: 'true' } }
    };

    let data = await DataCycle.httpRequest({
      url: `/api/v4/endpoints/${currentStoredFilterId}`,
      method: 'POST',
      data: params,
      dataType: 'json',
      headers: {
        Accept: 'application/vnd.geo+json'
      }
    });
    this.value = this.feature = data;
    return;
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

import DomElementHelpers from '../../helpers/dom_element_helpers';

class AdditionalValuesFilterControl {
  constructor(editor) {
    this.editor = editor;
    this.config = editor.additionalValuesOverlay;
    this.activeFilters = {};
    this.activeRequest = null;
  }
  onAdd(map) {
    this.map = map;

    this._setupControls();
    this._setupOverlay();
    this._addEventHandlers();
    this._addGeoJsonSource();

    return this.container;
  }
  onRemove() {
    this.container.parentNode.removeChild(this.container);
    this.map = undefined;
    this._removeGeoJsonSource();
  }
  _setupControls() {
    this.container = document.createElement('div');
    this.container.className = 'mapboxgl-ctrl mapboxgl-ctrl-group additional-values-overlay-control';

    this.controlButton = document.createElement('button');
    this.controlButton.className = 'dc-additional-values-overlay-button';
    this.controlButton.type = 'button';
    this.controlButton.title = 'show Additional Value Filters';
    this.container.appendChild(this.controlButton);

    const icon = document.createElement('i');
    icon.className = 'fa fa-map-marker';
    this.controlButton.appendChild(icon);
  }
  _setupOverlay() {
    this.controlOverlay = document.createElement('div');
    this.controlOverlay.className = 'dc-additional-values-overlay remote-render';
    this.controlOverlay.dataset.remotePath = 'data_cycle_core/contents/editors/geographic/additional_values_overlay';
    this.controlOverlay.dataset.remoteOptions = JSON.stringify({ additional_values: this.config });

    this.map.getContainer().appendChild(this.controlOverlay);
  }
  _addEventHandlers() {
    this.controlButton.addEventListener('click', this._openOverlay.bind(this));
  }
  _initializeOverlay(_event) {
    this.controlOverlay.querySelectorAll('.dc-additional-values-filter-item').forEach(group => {
      const definition = DomElementHelpers.parseDataAttribute(group.dataset.definition);

      this.activeFilters[group.dataset.groupKey] = {
        enabled: false,
        filters: {
          t: 'classification_alias_ids',
          m: 'i',
          v: []
        },
        definition: definition
      };

      group
        .querySelector('input.dc-additional-values-filter-group')
        .addEventListener('change', this._groupChanged.bind(this));
      group
        .querySelectorAll('input.dc-additional-values-filter-specific')
        .forEach(specificFilter => specificFilter.addEventListener('change', this._specificFilterChanged.bind(this)));
    });
  }
  _addGeoJsonSource() {
    this.map.addSource('additional_filtered_values', {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] }
    });

    this.map.addLayer({
      id: 'additional_filtered_lines',
      type: 'line',
      source: 'additional_filtered_values',
      filter: ['==', '$type', 'LineString'],
      paint: {
        'line-color': this.editor.definedColors.default,
        'line-opacity': 0.75,
        'line-width': 5
      }
    });

    this.map.addLayer({
      id: 'additional_filtered_points',
      type: 'circle',
      source: 'additional_filtered_values',
      filter: ['==', '$type', 'Point'],
      paint: {
        'circle-radius': 5,
        'circle-stroke-width': 2,
        'circle-color': this.editor.definedColors.red,
        'circle-stroke-color': this.editor.definedColors.white
      }
    });
  }
  _removeGeoJsonSource() {
    this.map.removeLayer('additional_filtered_points');
    this.map.removeLayer('additional_filtered_lines');
    this.map.removeSource('additional_filtered_values');
  }
  _openOverlay(event) {
    event.preventDefault();
    event.stopPropagation();

    if (this.controlOverlay.classList.contains('active')) this.controlOverlay.classList.remove('active');
    else {
      this.controlOverlay.classList.add('active');

      if (this.controlOverlay.classList.contains('remote-render')) {
        $(this.controlOverlay).one('dc:html:changed', this._initializeOverlay.bind(this));

        this.controlOverlay.dispatchEvent(
          new CustomEvent('dc:remote:render', {
            bubbles: true
          })
        );
      }
    }
  }
  _groupChanged(event) {
    const target = event.currentTarget;

    this.activeFilters[target.value].enabled = target.checked;

    this._loadGeoJson();
  }
  _specificFilterChanged(event) {
    const target = event.currentTarget;

    if (target.checked) this.activeFilters[target.dataset.groupKey].filters.v.push(target.value);
    else
      this.activeFilters[target.dataset.groupKey].filters.v = this.activeFilters[
        target.dataset.groupKey
      ].filters.v.filter(id => id !== target.value);

    if (this.activeFilters[target.dataset.groupKey].enabled) this._loadGeoJson();
  }
  _loadGeoJson() {
    // this.controlOverlay.classList.add('loading');

    const filters = Object.fromEntries(Object.entries(this.activeFilters).filter(([_k, v]) => v.enabled));

    this.map
      .getSource('additional_filtered_values')
      .setData(`/things/geojson_for_map_editor?${$.param({ filter: filters })}`);

    // const request = DataCycle.httpRequest({
    //   url: '/things/geojson_for_map_editor',
    //   method: 'POST',
    //   data: {
    //     filter: filters
    //   }
    // });

    // this.activeRequest = request;

    // request
    //   .then(data => {
    //     if (this.activeRequest !== request) return;

    //     this.map.getSource('additional_filtered_values').setData(data);
    //   })
    //   .finally(() => {
    //     this.controlOverlay.classList.remove('loading');
    //   });
  }
}

export default AdditionalValuesFilterControl;

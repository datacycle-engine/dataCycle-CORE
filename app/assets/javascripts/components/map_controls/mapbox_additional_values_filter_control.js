import DomElementHelpers from '../../helpers/dom_element_helpers';
import pull from 'lodash/pull';
import pick from 'lodash/pick';

class AdditionalValuesFilterControl {
  constructor(editor) {
    this.editor = editor;
    this.config = editor.additionalValuesOverlay;
    this.activeFilters = {};
    this.layerFilters = {};
    this.enabled = false;
  }
  onAdd(map) {
    this.map = map;

    this._setupControls();
    this._setupOverlay();
    this._addEventHandlers();

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
    this.controlButton.addEventListener('click', this._toggleOverlay.bind(this));
  }
  _initializeOverlay(_event) {
    this.controlOverlay.querySelectorAll('.dc-additional-values-filter-item').forEach(group => {
      const definition = DomElementHelpers.parseDataAttribute(group.dataset.definition) || {};

      this.activeFilters[group.dataset.groupKey] = {
        enabled: false,
        filter: [],
        definition: pick(definition, ['template_name', 'stored_filter'])
      };

      group
        .querySelector('input.dc-additional-values-filter-group')
        .addEventListener('change', this._groupChanged.bind(this));
      group
        .querySelectorAll('input.dc-additional-values-filter-specific')
        .forEach(specificFilter => specificFilter.addEventListener('change', this._specificFilterChanged.bind(this)));
    });
  }
  _addGeoJsonSource(key, data) {
    const sourceId = `additional_values_${key}`;
    this.editor.additionalSources[key] = sourceId;

    this.map.addSource(sourceId, {
      type: 'geojson',
      data: data,
      generateId: true
    });

    this.map.on('sourcedata', data => {
      if (data.sourceId === sourceId && this.map.isSourceLoaded(sourceId))
        this.controlOverlay
          .querySelector(`.dc-additional-values-filter-item[data-group-key="${key}"]`)
          .classList.remove('source-loading');
    });

    this.editor.additionalLayers[key] = {
      point: this.editor._additionalPointLayer(key),
      line: this.editor._additionalLineLayer(key)
    };

    this._addClickableFeatures(key, 'point');
    this._addClickableFeatures(key, 'line');
  }
  _addClickableFeatures(key, type) {
    console.log(this.editor.additionalLayers[key]);

    this.map.on('click', this.editor.additionalLayers[key][type], e => {
      if (!this.enabled) return;

      e.preventDefault();

      const feature = e.features[0];

      console.log('click on feature', feature);

      this.map.setFeatureState(
        { source: this.editor.additionalSources[key], id: feature.id },
        { selected: !feature.state.selected }
      );

      feature.properties.selected = !feature.state.selected;

      if (feature.state.selected) {
        // trigger objectbrowser event
      } else {
        // trigger objectbrowser event
      }
    });
  }
  _removeGeoJsonSource(key) {
    this.map.removeLayer(this.editor.additionalLayers[key].point);
    this.map.removeLayer(this.editor.additionalLayers[key].line);
    this.map.removeSource(this.editor.additionalSources[key]);
    delete this.editor.additionalSources[key];
    delete this.editor.additionalLayers[key];
  }
  _toggleOverlay(event) {
    event.preventDefault();
    event.stopPropagation();

    if (this.controlOverlay.classList.contains('active')) {
      this.enabled = false;
      this.controlOverlay.classList.remove('active');
      this.editor.editorGui.editor.clickable = true;
      this.editor.editorGui.editor._enabled = true;
      this.editor.editorGui.editor.visibility = 'visible';
    } else {
      this.enabled = true;
      this.controlOverlay.classList.add('active');
      this.editor.editorGui.editor.clickable = false;
      this.editor.editorGui.editor._enabled = false;
      this.editor.editorGui.editor.visibility = 'none';

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

    this._loadGeoJson(target.value);
  }
  _specificFilterChanged(event) {
    const target = event.currentTarget;

    if (target.checked) this.activeFilters[target.dataset.groupKey].filter.push(target.value);
    else pull(this.activeFilters[target.dataset.groupKey].filter, target.value);

    if (this.activeFilters[target.dataset.groupKey].enabled) this._loadGeoJson(target.dataset.groupKey);
  }
  _showAdditionalFeatures(key) {
    this.map.setFilter('airport', ['has', 'abbrev']);
  }
  _hideAdditionalFeatures(key) {
    console.log('_hideAdditionalFeatures', this.map.getLayer(this.editor.additionalLayers[key].point));

    this.layerFilters[key] = {
      point: this.map.getLayer(this.editor.additionalLayers[key].point).filter,
      line: this.map.getLayer(this.editor.additionalLayers[key].line).filter
    };

    this.map.setFilter(this.editor.additionalLayers[key].point, ['==', 'selected', true]);
    this.map.setFilter(this.editor.additionalLayers[key].line, ['==', 'selected', true]);
  }
  _loadGeoJson(key) {
    let dataSource;

    if (this.activeFilters[key].enabled) {
      const params = Object.assign({}, this.activeFilters[key].definition);
      params.filter = this.activeFilters[key].filter;

      dataSource = `/things/geojson_for_map_editor?${$.param(params)}`;
    } else {
      this._hideAdditionalFeatures(key);
    }

    this.controlOverlay
      .querySelector(`.dc-additional-values-filter-item[data-group-key="${key}"]`)
      .classList.add('source-loading');

    if (!this.editor.additionalSources[key]) this._addGeoJsonSource(key, dataSource);
    else this.map.getSource(`additional_values_${key}`).setData(dataSource);
  }
}

export default AdditionalValuesFilterControl;

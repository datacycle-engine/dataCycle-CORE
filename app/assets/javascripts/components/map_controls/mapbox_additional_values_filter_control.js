import DomElementHelpers from '../../helpers/dom_element_helpers';
import pull from 'lodash/pull';
import pick from 'lodash/pick';
import isEqual from 'lodash/isEqual';

class AdditionalValuesFilterControl {
  constructor(editor) {
    this.editor = editor;
    this.config = editor.additionalValuesOverlay;
    this.activeFilters = {};
    this.layerFilters = {};
    this.geojsonValues = {};
    this.lastLoadedFilter = {};
    this.additionalSources = {};
    this.additionalLayers = {};
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
    // additionalValues layer
    this._addClickableFeatures('additional_values_point_selected');
    this._addClickableFeatures('additional_values_line_selected');

    this.controlOverlay.querySelectorAll('.dc-additional-values-filter-item').forEach(group => {
      const definition = DomElementHelpers.parseDataAttribute(group.dataset.definition) || {};

      this.activeFilters[group.dataset.groupKey] = {
        enabled: false,
        filter: [],
        definition: pick(definition, ['template_name', 'stored_filter'])
      };

      this.geojsonValues[group.dataset.groupKey] = this.editor._createFeatureCollection();

      this._addGeoJsonSource(group.dataset.groupKey, this.geojsonValues[group.dataset.groupKey]);

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
    this.additionalSources[key] = sourceId;

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

    this.additionalLayers[key] = {
      point: this.editor._additionalPointLayer(key),
      line: this.editor._additionalLineLayer(key)
    };

    this._addClickableFeatures(this.additionalLayers[key].point, key);
    this._addClickableFeatures(this.additionalLayers[key].line, key);
  }
  _findRenderedFeature(featureId, key = null) {
    if (key) return [key, this.geojsonValues[key].features.find(f => f.properties.id === featureId)];

    let feature;

    for (const [k, v] of Object.entries(this.geojsonValues)) {
      feature = v.features.find(f => f.properties.id === featureId);

      if (feature) {
        key = k;
        break;
      }
    }

    return [key, feature];
  }
  _unselectFeature(feature, featureId) {
    if (feature) delete feature.properties.selected;

    const index = this.editor.additionalValues.features.findIndex(f => f.properties.id === featureId);

    if (index === -1) return;

    const additionalValueFeature = this.editor.additionalValues.features.splice(index, 1)[0];

    console.log('_unselectFeature', additionalValueFeature);

    // trigger objectbrowser event
  }
  _selectFeature(feature) {
    feature.properties.selected = true;

    this.editor.additionalValues.features.push(feature);

    console.log('_selectFeature', feature);

    // trigger objectbrowser event
  }
  _addClickableFeatures(layerId, layerKey = null) {
    this.map.on('click', layerId, e => {
      if (!this.enabled) return;

      e.preventDefault();

      const featureId = e.features[0].properties.id;
      const [key, feature] = this._findRenderedFeature(featureId, layerKey);

      if (layerId.includes('selected')) this._unselectFeature(feature, featureId);
      else this._selectFeature(feature);

      if (key) this.map.getSource(this.additionalSources[key]).setData(this.geojsonValues[key]);
      this.map.getSource(this.editor.selectedAdditionalSource).setData(this.editor.additionalValues);
    });
  }
  _removeGeoJsonSource(key) {
    this.map.removeLayer(this.additionalLayers[key].point);
    this.map.removeLayer(this.additionalLayers[key].line);
    this.map.removeSource(this.additionalSources[key]);
    delete this.additionalSources[key];
    delete this.additionalLayers[key];
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

    this._reloadData(target.value);
  }
  _specificFilterChanged(event) {
    const target = event.currentTarget;

    if (target.checked) this.activeFilters[target.dataset.groupKey].filter.push(target.value);
    else pull(this.activeFilters[target.dataset.groupKey].filter, target.value);

    if (this.activeFilters[target.dataset.groupKey].enabled) this._reloadData(target.dataset.groupKey);
  }
  async _reloadData(key) {
    if (this.activeFilters[key].enabled) {
      this.controlOverlay
        .querySelector(`.dc-additional-values-filter-item[data-group-key="${key}"]`)
        .classList.add('source-loading');

      if (!isEqual(this.activeFilters[key].filter, this.lastLoadedFilter[key])) await this._reloadGeoJson(key);

      this.map.setLayoutProperty(this.additionalLayers[key].point, 'visibility', 'visible');
      this.map.setLayoutProperty(this.additionalLayers[key].line, 'visibility', 'visible');
    } else {
      this.map.setLayoutProperty(this.additionalLayers[key].point, 'visibility', 'none');
      this.map.setLayoutProperty(this.additionalLayers[key].line, 'visibility', 'none');
    }
  }
  async _reloadGeoJson(key) {
    const params = Object.assign({}, this.activeFilters[key].definition);
    params.filter = this.activeFilters[key].filter;

    const data = await DataCycle.httpRequest({
      url: '/things/geojson_for_map_editor',
      method: 'GET',
      data: params,
      dataType: 'json'
    });

    if (!data || !data.features) return;

    this.lastLoadedFilter[key] = this.activeFilters[key].filter.slice();

    for (let i = 0; i < data.features.length; ++i) {
      data.features[i].properties.id = data.features[i].id;

      if (this.editor.additionalValues.features.some(v => v.properties.id === data.features[i].id))
        data.features[i].properties.selected = true;
    }

    this.geojsonValues[key] = data;
    this.map.getSource(this.additionalSources[key]).setData(this.geojsonValues[key]);
  }
}

export default AdditionalValuesFilterControl;

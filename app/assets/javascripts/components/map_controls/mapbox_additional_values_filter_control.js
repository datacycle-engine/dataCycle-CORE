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
    this.additionalValueTargets = {};
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
    this.container.className = 'maplibregl-ctrl maplibregl-ctrl-group additional-values-overlay-control';

    this.controlButton = document.createElement('button');
    this.controlButton.className = 'dc-additional-values-overlay-button';
    this.controlButton.type = 'button';
    I18n.translate('frontend.map.filter.button_title').then(text => (this.controlButton.title = text));
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

    this._initOverlayData();
  }
  _initOverlayData() {
    for (const [key, value] of Object.entries(this.config)) {
      this.activeFilters[key] = {
        enabled: false,
        filter: [],
        definition: pick(value.definition, ['template_name', 'stored_filter'])
      };

      this.geojsonValues[key] = this.editor._createFeatureCollection();
      this._addGeoJsonSource(key, this.geojsonValues[key]);
    }
  }
  _reloadOverlayData(_event = undefined) {
    for (const key of Object.keys(this.config)) {
      this._addGeoJsonSource(key, this.geojsonValues[key]);
    }
  }
  _addEventHandlers() {
    this.controlButton.addEventListener('click', this._toggleOverlay.bind(this));

    this.editor.map.on('maptypechanged', this._reloadOverlayData.bind(this));

    this._addOverlayTargetEvents();
  }
  _addOverlayTargetEvents() {
    for (const key of Object.keys(this.config)) {
      this.additionalValueTargets[key] = this.editor.$parentContainer
        .closest('.form-element.geographic')
        .siblings(`.form-element[data-key*="[${key}]"]`)
        .find('.object-browser');

      if (!this.additionalValueTargets[key].length) continue;

      this.additionalValueTargets[key].on('dc:objectBrowser:change', this._linkedChangeHandler.bind(this));
    }
  }
  async _linkedChangeHandler(event, data) {
    event.preventDefault();
    event.stopPropagation();

    const key = data.key.getAttributeKey();
    let changedFeatures = [];

    if (data.ids && data.ids.length) {
      const geoJson = await this._loadGeojson(key, { ids: data.ids });
      changedFeatures = geoJson.features || [];
    }

    this._additionalValuesByKey(key).features = changedFeatures;
    this.map.getSource(this._additionalValueSourceByKey(key)).setData(this._additionalValuesByKey(key));
  }
  _initializeOverlay(_event) {
    this._initClickableFeatures(this.editor.selectedAdditionalLayers);
    this._initClickableFeatures(this.additionalLayers);

    this.controlOverlay.querySelectorAll('.dc-additional-values-filter-item').forEach(group => {
      group
        .querySelector('input.dc-additional-values-filter-group')
        .addEventListener('change', this._groupChanged.bind(this));
      group
        .querySelectorAll('input.dc-additional-values-filter-specific')
        .forEach(specificFilter => specificFilter.addEventListener('change', this._specificFilterChanged.bind(this)));
    });
  }
  _initClickableFeatures(layers) {
    for (const [key, value] of Object.entries(layers)) {
      if (!this.config[key]) continue;

      this._addClickableFeatures(value.point, key);
      this._addClickableFeatures(value.line, key);
    }
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
      if (this.enabled && data.sourceId === sourceId && this.map.isSourceLoaded(sourceId))
        this.controlOverlay
          .querySelector(`.dc-additional-values-filter-item[data-group-key="${key}"]`)
          .classList.remove('source-loading');
    });

    this.additionalLayers[key] = {
      point: this.editor._additionalPointLayer(key),
      line: this.editor._additionalLineLayer(key)
    };
  }
  _additionalValuesByKey(key) {
    if (!this.editor.additionalValues[key]) this.editor.additionalValues[key] = this.editor._createFeatureCollection();

    return this.editor.additionalValues[key];
  }
  _additionalValueSourceByKey(key) {
    if (!this.editor.selectedAdditionalSources[key])
      this.editor._addSelectedSourceAndLayers(key, this.editor._createFeatureCollection());

    return this.editor.selectedAdditionalSources[key];
  }
  _unselectFeature(featureId, key) {
    const index = this._additionalValuesByKey(key).features.findIndex(f => f.properties.id === featureId);

    if (index === -1) return;

    this._additionalValuesByKey(key).features.splice(index, 1)[0];

    $(this.additionalValueTargets[key])
      .find(`ul.object-thumbs li.item[data-id="${featureId}"] .delete-thumbnail`)
      .trigger('click', { preventDefault: true });
  }
  _selectFeature(feature, key) {
    this._additionalValuesByKey(key).features.push(feature);

    this.additionalValueTargets[key].trigger('dc:import:data', {
      value: [feature.properties.id]
    });
  }
  _addClickableFeatures(layerId, key) {
    this.map.on('click', layerId, e => {
      if (!this.enabled || e.defaultPrevented) return;

      e.preventDefault();

      const featureId = e.features[0].properties.id;
      const feature = this.geojsonValues[key].features.find(f => f.properties.id === featureId);

      if (layerId.includes('selected')) this._unselectFeature(featureId, key);
      else this._selectFeature(feature, key);

      this.map.getSource(this._additionalValueSourceByKey(key)).setData(this._additionalValuesByKey(key));
    });
  }
  _removeGeoJsonSource(key) {
    this.map.removeLayer(this.additionalLayers[key].point);
    this.map.removeLayer(this.additionalLayers[key].line);
    this.editor.allRenderedLayers = this.editor.allRenderedLayers.filter(
      l => l !== this.additionalLayers[key].point && l !== this.additionalLayers[key].line
    );

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
  async _groupChanged(event) {
    const target = event.currentTarget;

    this.activeFilters[target.value].enabled = target.checked;

    await this._reloadData(target.value);

    this._updateLayerVisibilities(target.value);
  }
  _updateLayerVisibilities(key) {
    const visibility = this.activeFilters[key].enabled ? 'visible' : 'none';

    this.map.setLayoutProperty(this.additionalLayers[key].point, 'visibility', visibility);
    this.map.setLayoutProperty(this.additionalLayers[key].line, 'visibility', visibility);
  }
  _updateParentsRecursive(target) {
    const parent = target
      .closest('ul')
      .closest('li')
      .querySelector(':scope > .overlay-filter-label > input[type="checkbox"]');

    if (!parent.classList.contains('dc-additional-values-filter-specific')) return;

    const siblings = parent.closest('li').querySelector('ul').querySelectorAll('input[type="checkbox"]');
    const status = Array.from(siblings).map(cb => cb.checked);

    parent.checked = status.every(Boolean);
    parent.indeterminate = !parent.checked && status.some(Boolean);
  }
  _updateAllChildren(target) {
    const children = target.closest('li').querySelectorAll('input[type="checkbox"]');
    for (const child of children) child.checked = target.checked;
  }
  _specificFilterChanged(event) {
    const target = event.currentTarget;

    this._updateAllChildren(target);
    this._updateParentsRecursive(target);

    this.activeFilters[target.dataset.groupKey].filter = Array.from(
      target
        .closest('.dc-additional-values-filter-item')
        .querySelectorAll('input.dc-additional-values-filter-specific:checked')
    ).map(v => v.value);

    if (this.activeFilters[target.dataset.groupKey].enabled) this._reloadData(target.dataset.groupKey);
  }
  async _reloadData(key) {
    if (!this.activeFilters[key].enabled) return;

    this.controlOverlay
      .querySelector(`.dc-additional-values-filter-item[data-group-key="${key}"]`)
      .classList.add('source-loading');

    if (!isEqual(this.activeFilters[key].filter, this.lastLoadedFilter[key])) await this._reloadGeoJson(key);
  }
  async _loadGeojson(key, additionalParams = {}) {
    const params = Object.assign({}, this.activeFilters[key].definition, additionalParams);
    params.filter = this.activeFilters[key].filter;

    let data = await DataCycle.httpRequest({
      url: '/things/geojson_for_map_editor',
      method: 'POST',
      data: params,
      dataType: 'json'
    });

    if (!data) data = this.editor._createFeatureCollection();
    if (!data.features) data.features = [];

    for (const feature of data.features) {
      feature.properties.id = feature.id;
      feature.properties.clickable = true;
    }

    return data;
  }
  async _reloadGeoJson(key) {
    const data = await this._loadGeojson(key);

    if (!data) data = this.editor._createFeatureCollection();
    if (!data.features) data.features = [];

    this.lastLoadedFilter[key] = this.activeFilters[key].filter.slice();

    this.geojsonValues[key] = data;

    await this.map.getSource(this.additionalSources[key]).setData(this.geojsonValues[key]);
  }
}

export default AdditionalValuesFilterControl;

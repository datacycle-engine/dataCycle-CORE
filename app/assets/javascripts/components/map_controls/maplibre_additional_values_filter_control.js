import pick from "lodash/pick";
import isEqual from "lodash/isEqual";
import ObserverHelpers from "../../helpers/observer_helpers";

class AdditionalValuesFilterControl {
	constructor(editor) {
		this.editor = editor;
		this.config = editor.additionalValuesOverlay;
		this.activeFilters = {};
		this.layerFilters = {};
		this.geojsonValues = {};
		this.lastLoadedFilter = {};
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
		this.container = document.createElement("div");
		this.container.className =
			"maplibregl-ctrl maplibregl-ctrl-group mapboxgl-ctrl-group additional-values-overlay-control";

		this.controlButton = document.createElement("button");
		this.controlButton.className =
			"dc-additional-values-overlay-button dc-map-control-button";
		this.controlButton.type = "button";
		I18n.translate("frontend.map.filter.button_title").then((text) => {
			this.controlButton.title = text;
		});
		this.container.appendChild(this.controlButton);

		const icon = document.createElement("i");
		icon.className = "fa fa-map-marker";
		this.controlButton.appendChild(icon);
	}
	_setupOverlay() {
		this.controlOverlay = document.createElement("div");
		this.controlOverlay.className =
			"dc-additional-values-overlay remote-render";
		this.controlOverlay.dataset.remotePath =
			"data_cycle_core/contents/editors/geographic/additional_values_overlay";
		this.controlOverlay.dataset.remoteOptions = JSON.stringify({
			additional_values: this.config,
		});

		this.map.getContainer().appendChild(this.controlOverlay);

		this._initOverlayData();
	}
	_initOverlayData() {
		for (const [key, value] of Object.entries(this.config)) {
			this.activeFilters[key] = {
				enabled: false,
				filter: [],
				definition: pick(value.definition, ["template_name", "stored_filter"]),
			};

			this.geojsonValues[key] = this.editor._createFeatureCollection();
			this._addGeoJsonSource(key, this.geojsonValues[key]);
		}
	}
	_addEventHandlers() {
		this.controlButton.addEventListener(
			"click",
			this._toggleOverlay.bind(this),
		);
	}
	_initializeOverlay(_event) {
		this._initClickableFeatures();

		if (
			this.controlOverlay.querySelector(".dc-additional-values-filter-item")
		) {
			for (const group of this.controlOverlay.querySelectorAll(
				".dc-additional-values-filter-item",
			)) {
				group
					.querySelector("input.dc-additional-values-filter-group")
					.addEventListener("change", this._groupChanged.bind(this));

				if (group.querySelector("input.dc-additional-values-filter-specific")) {
					for (const specificFilter of group.querySelectorAll(
						"input.dc-additional-values-filter-specific",
					)) {
						specificFilter.addEventListener(
							"change",
							this._specificFilterChanged.bind(this),
						);
					}
				}
			}
		}
	}
	_initClickableFeatures() {
		this._addClickableFeatures();
	}
	_addGeoJsonSource(key, data) {
		const { sourceId } = this.editor._addAdditionalSourceAndLayers(key, data);

		this.map.on("sourcedata", (d) => {
			if (
				this.enabled &&
				d.sourceId === sourceId &&
				this.map.isSourceLoaded(sourceId)
			)
				this.controlOverlay
					.querySelector(
						`.dc-additional-values-filter-item[data-group-key="${key}"]`,
					)
					.classList.remove("source-loading");
		});
	}
	_unselectFeature(feature, key) {
		const index = this.editor
			._additionalValuesByKey(key)
			.features.findIndex(
				(f) => f.properties["@id"] === feature.properties["@id"],
			);

		if (index === -1) return;

		this.editor._additionalValuesByKey(key).features.splice(index, 1)[0];

		$(this.editor.additionalValueTargets[key])
			.find(
				`ul.object-thumbs li.item[data-id="${feature.properties["@id"]}"] .delete-thumbnail`,
			)
			.trigger("click", { preventDefault: true });
	}
	_selectFeature(feature, key) {
		this.editor._additionalValuesByKey(key).features.push(feature);

		this.editor.additionalValueTargets[key].trigger("dc:import:data", {
			value: [feature.properties["@id"]],
		});
	}
	_findFeatureAndKey(features) {
		const keys = [];
		let feature = features.find(
			this._checkFeature.bind(
				this,
				this.editor.selectedAdditionalSources,
				keys,
			),
		);
		if (!feature)
			feature = features.find(
				this._checkFeature.bind(this, this.editor.additionalSources, keys),
			);

		return [feature, keys.pop()];
	}
	_checkFeature(sources, keys, feature) {
		for (const [k, v] of Object.entries(sources)) {
			if (feature.source !== v) continue;

			keys.push(k);
			return true;
		}

		return false;
	}
	_addClickableFeatures() {
		this.map.on("click", (e) => {
			if (!this.enabled) return;

			const [feature, key] = this._findFeatureAndKey(
				this.map.queryRenderedFeatures(e.point),
			);

			if (!(feature && key)) return;

			if (feature.source.includes("_selected"))
				this._unselectFeature(feature, key);
			else this._selectFeature(feature, key);

			this.editor._setSelectedAdditionalDataForSource(key);
		});
	}
	_removeGeoJsonSource(key) {
		this.map.removeLayer(this.editor.additionalLayers[key].point);
		this.map.removeLayer(this.editor.additionalLayers[key].line);
		this.editor.allRenderedLayers = this.editor.allRenderedLayers.filter(
			(l) =>
				l !== this.editor.additionalLayers[key].point &&
				l !== this.editor.additionalLayers[key].line,
		);

		this.map.removeSource(this.editor.additionalSources[key]);
		this.editor.additionalSources[key] = undefined;
		this.editor.additionalLayers[key] = undefined;
	}
	_showOverlay() {
		this.enabled = true;
		this.controlOverlay.classList.add("active");
		this.controlButton.classList.add("active");

		if (this.editor.draw) {
			this.editor.draw.changeMode("simple_select", {});
			this.editor.map.fire("draw.modechange", { mode: "simple_select" });
		}

		if (this.controlOverlay.classList.contains("remote-render")) {
			const changeObserver = new MutationObserver(
				this._checkForChangedFormData.bind(this),
			);
			changeObserver.observe(
				this.controlOverlay,
				ObserverHelpers.changedClassConfig,
			);

			this.controlOverlay.dispatchEvent(
				new CustomEvent("dc:remote:render", {
					bubbles: true,
				}),
			);
		}
	}
	_hideOverlay() {
		this.enabled = false;
		this.controlOverlay.classList.remove("active");
		this.controlButton.classList.remove("active");
	}
	_toggleOverlay(event) {
		event.preventDefault();
		event.stopPropagation();

		if (this.controlOverlay.classList.contains("active")) this._hideOverlay();
		else this._showOverlay();
	}
	_checkForChangedFormData(mutations, observer) {
		if (
			mutations.some(
				(m) =>
					m.type === "attributes" &&
					m.target.classList.contains("remote-rendered") &&
					(!m.oldValue || m.oldValue.includes("remote-rendering")),
			)
		) {
			observer.disconnect();
			this._initializeOverlay();
		}
	}
	async _groupChanged(event) {
		const target = event.currentTarget;

		this.activeFilters[target.value].enabled = target.checked;

		await this._reloadData(target.value);

		this._updateLayerVisibilities(target.value);
	}
	_updateLayerVisibilities(key) {
		const visibility = this.activeFilters[key].enabled ? "visible" : "none";

		this._setLayerVisibility(
			this.editor.additionalLayers[key].point,
			visibility,
		);
		this._setLayerVisibility(
			`${this.editor.additionalLayers[key].point}_hover`,
			visibility,
		);

		this._setLayerVisibility(
			this.editor.additionalLayers[key].line,
			visibility,
		);
		this._setLayerVisibility(
			`${this.editor.additionalLayers[key].line}_hover`,
			visibility,
		);
		this._setLayerVisibility(
			`${this.editor.additionalLayers[key].line}_hover_foreground`,
			visibility,
		);
		this._setLayerVisibility(
			`${this.editor.additionalLayers[key].line}_hover_start`,
			visibility,
		);
	}
	_setLayerVisibility(layedId, visibility) {
		this.map.setLayoutProperty(layedId, "visibility", visibility);
	}
	_updateParentsRecursive(target) {
		const parent = target
			.closest("ul")
			.closest("li")
			.querySelector(':scope > .overlay-filter-label > input[type="checkbox"]');

		if (!parent.classList.contains("dc-additional-values-filter-specific"))
			return;

		const siblings = parent
			.closest("li")
			.querySelector("ul")
			.querySelectorAll('input[type="checkbox"]');
		const status = Array.from(siblings).map((cb) => cb.checked);

		parent.checked = status.every(Boolean);
		parent.indeterminate = !parent.checked && status.some(Boolean);
	}
	_updateAllChildren(target) {
		const children = target
			.closest("li")
			.querySelectorAll('input[type="checkbox"]');
		for (const child of children) child.checked = target.checked;
	}
	_specificFilterChanged(event) {
		const target = event.currentTarget;

		this._updateAllChildren(target);
		this._updateParentsRecursive(target);

		this.activeFilters[target.dataset.groupKey].filter = Array.from(
			target
				.closest(".dc-additional-values-filter-item")
				.querySelectorAll("input.dc-additional-values-filter-specific:checked"),
		).map((v) => v.value);

		if (this.activeFilters[target.dataset.groupKey].enabled)
			this._reloadData(target.dataset.groupKey);
	}
	async _reloadData(key) {
		if (!this.activeFilters[key].enabled) return;

		this.controlOverlay
			.querySelector(
				`.dc-additional-values-filter-item[data-group-key="${key}"]`,
			)
			.classList.add("source-loading");

		if (!isEqual(this.activeFilters[key].filter, this.lastLoadedFilter[key]))
			await this._reloadGeoJson(key);
	}

	async _reloadGeoJson(key) {
		const data = await this.editor._loadGeojson(
			Object.assign({}, this.activeFilters[key].definition, {
				filter: this.activeFilters[key].filter,
			}),
		);

		this.lastLoadedFilter[key] = this.activeFilters[key].filter.slice();

		this.geojsonValues[key] = data;

		await this.map
			.getSource(this.editor.additionalSources[key])
			.setData(this.geojsonValues[key]);
	}
}

export default AdditionalValuesFilterControl;

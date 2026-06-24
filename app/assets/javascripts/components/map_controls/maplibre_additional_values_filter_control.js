import isEqual from "lodash/isEqual";
import pick from "lodash/pick";
import ConfirmationModal from "../../components/confirmation_modal";
import {
	getFormDataAsObject,
	isVisible,
} from "../../helpers/dom_element_helpers";
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

		this.#initOverlayData();
	}
	#initOverlayData() {
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
	#initGroupCheckboxes() {
		const groupCheckboxes = this.controlOverlay.querySelectorAll(
			"input.dc-additional-values-filter-group",
		);
		for (const checkbox of groupCheckboxes) {
			checkbox.addEventListener("change", this.#groupChanged.bind(this));
			const groupItem = checkbox.closest(".dc-additional-values-filter-item");
			const config = this.activeFilters[groupItem.dataset.groupKey];
			config.enabled = checkbox.checked;
			config.element = checkbox;
			config.groupElement = groupItem;
		}

		const addAllButtons =
			this.controlOverlay.querySelectorAll(".dc-add-all-button");
		for (const button of addAllButtons) {
			button.addEventListener(
				"click",
				this.#handleAddAllButtonClick.bind(this),
			);
		}
	}
	async #handleAddAllButtonClick(event) {
		event.stopPropagation();
		event.preventDefault();
		const target = event.currentTarget;
		const groupKey = target.dataset.groupKey;

		DataCycle.disableElement(target);

		const features = this.map.queryRenderedFeatures({
			layers: Object.values(this.editor.additionalLayers[groupKey]).flat(),
		});
		await this.#selectFeatures(features, groupKey);
		this.editor._setSelectedAdditionalDataForSource(groupKey);
		DataCycle.enableElement(target);
	}
	#initSpecificCheckboxes() {
		const specificCheckboxes = this.controlOverlay.querySelectorAll(
			"input.dc-additional-values-filter-specific",
		);
		for (const checkbox of specificCheckboxes) {
			checkbox.addEventListener(
				"change",
				this.#specificFilterChanged.bind(this),
			);
		}
	}
	#initGeoRadius() {
		const geoFilter = this.controlOverlay.querySelectorAll(
			".geo-radius-filter-container input[type='number'], .geo-radius-filter-container select",
		);
		for (const checkbox of geoFilter) {
			checkbox.addEventListener("change", this.#geoFilterChanged.bind(this));
		}
	}
	#initVisibilityUpdate() {
		for (const [key, target] of Object.entries(
			this.editor.additionalValueTargets,
		)) {
			const element = target[0].closest(".form-element");
			if (!element) continue;

			this.#updateFilterVisibilityForKey(key, element);
			// observe visibility changes of the filter target to update the filter visibility accordingly
			const observer = new MutationObserver(() =>
				this.#updateFilterVisibilityForKey(key, element),
			);
			observer.observe(element, ObserverHelpers.changedClassConfig);
		}
	}
	#updateFilterVisibilityForKey(key, target) {
		if (isVisible(target)) this.#showOverlayFilterForKey(key);
		else this.#hideOverlayFilterForKey(key);
	}
	#showOverlayFilterForKey(key) {
		this.activeFilters[key].groupElement?.classList?.remove("hidden");
	}
	#hideOverlayFilterForKey(key) {
		this.activeFilters[key].element.checked = false;
		this.activeFilters[key].element.dispatchEvent(new Event("change"));
		this.activeFilters[key].groupElement?.classList?.add("hidden");
	}
	#initializeOverlay(_event) {
		this.#addClickableFeatures();
		this.#initGroupCheckboxes();
		this.#initSpecificCheckboxes();
		this.#initGeoRadius();
		this.#initVisibilityUpdate();
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
	#unselectFeatures(features, key) {
		if (!features) return;

		const ids = features.map((f) => f.properties["@id"]);
		if (ids.length === 0) return;

		const config = this.editor._additionalValuesByKey(key);
		config.features = config.features.filter(
			(f) => !ids.includes(f.properties["@id"]),
		);

		this.editor.additionalValueTargets[key].trigger("dc:remove:data", {
			value: ids,
		});
	}
	async #triggerImport(ids, key) {
		const $element = this.editor.additionalValueTargets[key];

		return new Promise((resolve) => {
			$element.one("dc:import:data:complete", () => resolve());

			this.editor.additionalValueTargets[key].trigger("dc:import:data", {
				value: ids,
			});
		});
	}
	async #selectFeatures(features, key) {
		const featureIds = features.map((feature) => feature.properties["@id"]);

		if (featureIds.length >= 100) {
			const text = await I18n.t(
				"frontend.map.additional_values_overlay.confirm_text",
				{ count: featureIds.length },
			);

			return new Promise((resolve) => {
				new ConfirmationModal({
					text: text,
					confirmationCallback: () => {
						this.editor._additionalValuesByKey(key).features.push(...features);
						resolve(this.#triggerImport(featureIds, key));
					},
					cancelable: true,
					cancelCallback: resolve,
				});
			});
		} else {
			this.editor._additionalValuesByKey(key).features.push(...features);
			return this.#triggerImport(featureIds, key);
		}
	}
	#findFeatureAndKey(features) {
		const keys = [];
		let feature = features.find(
			this.#checkFeature.bind(
				this,
				this.editor.selectedAdditionalSources,
				keys,
			),
		);
		if (!feature)
			feature = features.find(
				this.#checkFeature.bind(this, this.editor.additionalSources, keys),
			);

		return [feature, keys.pop()];
	}
	#checkFeature(sources, keys, feature) {
		for (const [k, v] of Object.entries(sources)) {
			if (feature.source !== v) continue;

			keys.push(k);
			return true;
		}

		return false;
	}
	#addClickableFeatures() {
		this.map.on("click", (e) => {
			if (!this.enabled) return;

			const [feature, key] = this.#findFeatureAndKey(
				this.map.queryRenderedFeatures(e.point),
			);

			if (!(feature && key)) return;

			if (feature.source.includes("_selected"))
				this.#unselectFeatures([feature], key);
			else this.#selectFeatures([feature], key);

			this.editor._setSelectedAdditionalDataForSource(key);
		});
	}
	_removeGeoJsonSource(key) {
		this.editor.removeAdditionalSource(key);
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
			this.#initializeOverlay();
		}
	}
	async #groupChanged(event) {
		event.stopPropagation();
		const target = event.currentTarget;

		for (const [key, value] of Object.entries(this.activeFilters)) {
			value.enabled = key === target.value ? target.checked : false;
			await this.#reloadData(key);
			this._updateLayerVisibilities(key);

			if (target !== value.element) value.element.checked = false;
		}
	}
	_updateLayerVisibilities(key) {
		const visibility = this.activeFilters[key].enabled ? "visible" : "none";
		const layerGroups = this.editor.additionalLayers[key];
		if (!layerGroups) return;

		for (const layerId of Object.values(layerGroups)) {
			const layers = this.editor.renderedLayers[layerId];
			if (!layers) continue;

			for (const id of layers) this.#setLayerVisibility(id, visibility);
		}
	}
	#setLayerVisibility(layedId, visibility) {
		this.map.setLayoutProperty(layedId, "visibility", visibility);
	}
	#updateParentsRecursive(target) {
		const parent = target
			.closest("ul.additional-map-values-filter-items")
			?.closest("li.additional-map-values-filter-item")
			?.querySelector(
				':scope > .overlay-filter-label > input[type="checkbox"]',
			);

		if (!parent?.classList.contains("dc-additional-values-filter-specific"))
			return;

		const siblings = parent
			.closest("li.additional-map-values-filter-item")
			.querySelector("ul")
			.querySelectorAll('input[type="checkbox"]');
		const status = Array.from(siblings).map((cb) => cb.checked);

		parent.checked = status.every(Boolean);
		parent.indeterminate = !parent.checked && status.some(Boolean);
	}
	#updateAllChildren(target) {
		const children = target
			.closest("li")
			.querySelectorAll('input[type="checkbox"]');
		for (const child of children) child.checked = target.checked;
	}
	#addActiveFilter(key, filter) {
		this.activeFilters[key].filter ||= [];
		const existingFilter = this.activeFilters[key].filter.find(
			(f) => f.t === filter.t,
		);
		if (existingFilter) {
			existingFilter.m = filter.m;
			existingFilter.v = filter.v;
		} else {
			this.activeFilters[key].filter.push(filter);
		}
	}
	#geoFilterChanged(event) {
		event.stopPropagation();
		const target = event.currentTarget;
		const formData = getFormDataAsObject(
			target.closest(".geo-radius-filter-container"),
		);
		const value = {
			...formData.additional_values_filter?.geo_radius?.v,
			geom: this.editor.getCurrentValueAsGeoJSON(),
		};

		this.#addActiveFilter(target.dataset.groupKey, {
			t: "geo_radius",
			m: "i",
			v: value,
		});

		if (this.activeFilters[target.dataset.groupKey].enabled)
			this.#reloadData(target.dataset.groupKey);
	}
	#specificFilterChanged(event) {
		event.stopPropagation();
		const target = event.currentTarget;

		this.#updateAllChildren(target);
		this.#updateParentsRecursive(target);

		const ids = Array.from(
			target
				.closest(".dc-additional-values-filter-item")
				.querySelectorAll("input.dc-additional-values-filter-specific:checked"),
		).map((v) => v.value);

		this.#addActiveFilter(target.dataset.groupKey, {
			t: "classification_alias_ids",
			m: "i",
			v: ids,
		});

		if (this.activeFilters[target.dataset.groupKey].enabled)
			this.#reloadData(target.dataset.groupKey);
	}
	async #reloadData(key) {
		if (!this.activeFilters[key].enabled) return;

		this.controlOverlay
			.querySelector(
				`.dc-additional-values-filter-item[data-group-key="${key}"]`,
			)
			.classList.add("source-loading");

		if (!isEqual(this.activeFilters[key].filter, this.lastLoadedFilter[key]))
			await this.#reloadGeoJson(key);
	}

	async #reloadGeoJson(key) {
		const data = await this.editor._loadGeojson(
			Object.assign({}, this.activeFilters[key].definition, {
				filter: this.activeFilters[key].filter,
			}),
		);

		this.lastLoadedFilter[key] = structuredClone(
			this.activeFilters[key].filter,
		);
		this.geojsonValues[key] = data;

		await this.map
			.getSource(this.editor.additionalSources[key])
			.setData(this.geojsonValues[key]);
	}
}

export default AdditionalValuesFilterControl;

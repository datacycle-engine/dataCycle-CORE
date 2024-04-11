import MapLibreGlViewer from "./maplibre_gl_viewer";
const MapboxDrawLoader = () =>
	import("@mapbox/mapbox-gl-draw").then((mod) => mod.default);
import MaplibreDrawControl from "./map_controls/maplibre_draw_control";
import MaplibreDrawRoutingMode from "./map_controls/maplibre_draw_routing_mode";
import turfFlatten from "@turf/flatten";

import isEmpty from "lodash/isEmpty";
import UploadGpxControl from "./map_controls/maplibre_upload_gpx_control";
import domElementHelpers from "../helpers/dom_element_helpers";
import AdditionalValuesFilterControl from "./map_controls/maplibre_additional_values_filter_control";
import ConfirmationModal from "./confirmation_modal";

class MapLibreGlEditor extends MapLibreGlViewer {
	constructor(container) {
		super(container);

		this.uploadable = this.$container.data("allowUpload");
		this.translateInteraction;
		this.modifyInteraction;
		this.drawableInteraction;
		this.drawing = false;
		this.draw;
		this.precision = 5;
		this.additionalValueTargets = {};
		this.routingOptions = this.mapOptions.routing_options || {};
		this.$mapEditContainer = this.$parentContainer
			.siblings(".map-edit")
			.first();
		this.$mapInfoContainer = this.$parentContainer
			.siblings(".map-info")
			.first();
		this.$uploadButton = this.$mapEditContainer
			.children(".upload-gpx-button")
			.first();
		this.$uploadInput = this.$mapEditContainer
			.children(".upload-gpx-input")
			.first();
		this.$latitudeField = this.$mapInfoContainer
			.find(".latitude input")
			.first();
		this.$longitudeField = this.$mapInfoContainer
			.find(".longitude input")
			.first();
		this.$elevationField = this.$mapInfoContainer
			.find(".elevation input")
			.first();
		this.$locationField = this.$parentContainer
			.siblings("input.location-data:hidden")
			.first();
		this.$geoCodeButton = this.$mapInfoContainer
			.find(".geocode-address-button")
			.first();
		this.geoCodeAttributes = [
			"street_address",
			"postal_code",
			"address_locality",
			"address_country",
		];
	}
	static isAllowedType(_type) {
		return true;
	}
	configureMap() {
		super.configureMap();
		this.initEventHandlers();
	}
	async initFeatures() {
		if (!this.feature && this.value) this.feature = this.value;
		// to ensure additional features are drawn last, the editor is initiallized here
		await this.initAdditionalControls();
		this.drawAdditionalFeatures();
	}
	drawAdditionalFeatures() {
		super.drawAdditionalFeatures();

		for (const key of new Set([
			...Object.keys(this.additionalValues),
			...Object.keys(this.additionalValuesOverlay),
		])) {
			this.additionalValueTargets[key] = this.$parentContainer
				.closest(".form-element.geographic")
				.siblings(`.form-element[data-key*="[${key}]"]`)
				.find(".object-browser");

			if (!this.additionalValueTargets[key].length) continue;

			this.additionalValueTargets[key].on(
				"dc:objectBrowser:change",
				this._linkedChangeHandler.bind(this),
			);
		}
	}
	async _linkedChangeHandler(event, data) {
		event.preventDefault();
		event.stopPropagation();

		const key = data.key.attributeNameFromKey();
		let changedFeatures = [];

		if (data.ids?.length) {
			const geoJson = await this._loadGeojson({ ids: data.ids });
			changedFeatures = geoJson.features || [];
		}

		this._additionalValuesByKey(key).features = changedFeatures;
		this._setSelectedAdditionalDataForSource(key);
	}
	_additionalValuesByKey(key) {
		if (!this.additionalValues[key])
			this.additionalValues[key] = this._createFeatureCollection();

		return this.additionalValues[key];
	}
	_additionalValueSourceByKey(key) {
		if (!this.selectedAdditionalSources[key])
			this._addAdditionalSourceAndLayers(
				key,
				this._createFeatureCollection(),
				"_selected",
			);

		return this.selectedAdditionalSources[key];
	}
	_setSelectedAdditionalDataForSource(key) {
		this.map
			.getSource(this._additionalValueSourceByKey(key))
			.setData(this._additionalValuesByKey(key));
	}
	async _loadGeojson(additionalParams = {}) {
		let data = await DataCycle.httpRequest("/things/geojson_for_map_editor", {
			method: "POST",
			body: additionalParams,
		});

		if (!data) data = this._createFeatureCollection();
		if (!data.features) data.features = [];
		for (const feature of data.features) feature.properties.clickable = true;

		return data;
	}
	initEventHandlers() {
		this.$container
			.on("dc:import:data", this.importData.bind(this))
			.addClass("dc-import-data");
		this.$latitudeField.on("change", this.updateMapMarker.bind(this));
		this.$longitudeField.on("change", this.updateMapMarker.bind(this));
		if (this.$geoCodeButton)
			this.$geoCodeButton.on("click", this.geoCodeAddress.bind(this));
	}

	async initAdditionalControls() {
		await this.initDrawControl();
		if (this.uploadable)
			this.map.addControl(new UploadGpxControl(this), "top-left");

		if (!isEmpty(this.additionalValuesOverlay)) {
			this.additionalValuesFilterControl = new AdditionalValuesFilterControl(
				this,
			);
			this.map.addControl(this.additionalValuesFilterControl, "top-left");
		}
	}
	availableControlsByType() {
		if (this.isPoint()) return ["trash", "draw_point"];
		if (this.isLineString()) {
			const options = ["trash", "draw_line_string"];

			if (this.routingOptions?.type)
				options.push(
					"draw_line_string_auto",
					"draw_line_string_bicycle",
					"draw_line_string_pedestrian",
				);

			return options;
		}
	}
	async initDrawControl() {
		const MapboxDraw = await MapboxDrawLoader().catch(console.error);

		this.draw = new MapboxDraw({
			displayControlsDefault: false,
			defaultMode: this.getMapDrawMode().mode,
			styles: this.getMapDrawStyle(),
			routingOptions: this.routingOptions,
			modes: {
				...MapboxDraw.modes,
				draw_line_string_auto: MaplibreDrawRoutingMode,
				draw_line_string_bicycle: MaplibreDrawRoutingMode,
				draw_line_string_pedestrian: MaplibreDrawRoutingMode,
			},
		});

		this.map.addControl(
			new MaplibreDrawControl({
				editor: this,
				draw: this.draw,
				routingOptions: this.routingOptions,
				controls: this.availableControlsByType(),
			}),
			"top-right",
		);

		this.initDrawEventHandlers();
		if (this.feature) {
			this.initEditFeature();
		}
	}
	initDrawEventHandlers() {
		this.map.on("draw.create", (event) => {
			this.feature = event.features[0];
			this.setCoordinates();
			this.setHiddenFieldValue(this.feature);
		});

		this.map.on("draw.delete", (_event) => {
			this.removeFeature();
		});

		this.map.on("draw.update", (event) => {
			this.feature = event.features[0];
			this.setCoordinates();
			this.setHiddenFieldValue(this.feature);
		});
	}
	getMapDrawMode(mode = undefined) {
		const modeConfig = {
			mode: mode,
			options: {},
		};

		if (this.feature && this.isPoint()) {
			const feature = this.draw?.getAll()?.features[0];
			modeConfig.mode = "simple_select";
			if (feature?.id) modeConfig.options.featureIds = [feature.id];
		} else if (this.feature && this.isLineString()) {
			const feature = this.draw?.getAll()?.features[0];
			if (!modeConfig.mode) modeConfig.mode = "simple_select";

			if (modeConfig.mode !== "simple_select" && feature?.id) {
				const coordinates = feature?.geometry?.coordinates || [];
				modeConfig.options.featureId = feature.id;
				modeConfig.options.from = coordinates[coordinates.length - 1].slice(
					0,
					2,
				);
			} else if (modeConfig.mode === "simple_select" && feature?.id) {
				modeConfig.options.featureIds = [feature.id];
			}
		} else if (this.isPoint() && !modeConfig.mode)
			modeConfig.mode = "draw_point";
		else if (this.isLineString() && !modeConfig.mode)
			modeConfig.mode = "draw_line_string";

		modeConfig.options.mode = modeConfig.mode;

		return modeConfig;
	}
	getMapDrawStyle() {
		return this.isPoint()
			? this._getDrawPointStyle()
			: this._getDrawLineStyle();
	}
	initEditFeature() {
		this.draw.deleteAll();

		this.draw.add(turfFlatten(this.feature));
		this.changeDrawMode();
	}
	changeDrawMode() {
		const { mode, options } = this.getMapDrawMode();
		this.draw.changeMode(mode, options);
		this.map.fire("draw.modechange", { mode: mode });
	}
	async importData(event, data) {
		if (!this.value || data?.force) {
			this.setUploadedFeature(data.value);
		} else {
			const target = event.currentTarget;

			domElementHelpers.renderImportConfirmationModal(
				target,
				data.sourceId,
				() => this.setUploadedFeature(data.value),
			);
		}
	}
	getNamesFromClassificationAttribute(elem) {
		let value = elem.querySelector("select")?.value;

		if (Array.isArray(value)) value = value.filter((x) => x)[0];

		return elem.querySelector(`option[value="${value}"]`)?.textContent;
	}
	getAddressFromAttributes() {
		const locale = this.$geoCodeButton[0].dataset.locale;
		const address = {
			locale: locale,
		};

		for (const key of this.geoCodeAttributes) {
			const elem = document.querySelector(
				`.form-element[data-key$="[${key}]"], .form-element[data-geocode-attribute-name="${key}"]`,
			);

			if (!elem) continue;

			let value;

			if (elem.classList.contains("classification"))
				value = this.getNamesFromClassificationAttribute(elem);
			else if (elem.classList.contains("string"))
				value = elem.querySelector("input")?.value;

			if (value) address[key] = value;
		}

		return address;
	}
	geoCodeAddress(event) {
		event.preventDefault();

		if (this.$geoCodeButton.hasClass("disabled")) return;

		this.$geoCodeButton.append(' <i class="fa fa-spinner fa-spin fa-fw"></i>');
		this.$geoCodeButton.addClass("disabled");

		const address = this.getAddressFromAttributes();

		const promise = DataCycle.httpRequest("/things/geocode_address", {
			body: address,
		});

		promise
			.then((data) => {
				if (data.error) {
					new ConfirmationModal({
						text: data.error,
					});
				} else if (data && data.length === 2) {
					this.setGeocodedValue(data);
				}
			})
			.catch((_jqxhr, textStatus, error) => {
				console.error(`${textStatus}, ${error}`);
			})
			.finally(() => {
				this.$geoCodeButton.find("i.fa").remove();
				this.$geoCodeButton.removeClass("disabled");
			});

		return promise;
	}
	setGeocodedValue(data) {
		if (!this.feature) {
			this.updateFeature(this.getGeoJsonFromCoordinates(data, "Point"));
		} else {
			this.feature.geometry.coordinates = data;
			this.updateFeature(this.feature);
			this.setNewCoordinates();
		}
	}
	setUploadedFeature(geometry) {
		this.updateFeature(this.getGeoJsonFromGeometry(geometry));
	}
	updateFeature(geoJson) {
		if (this.feature) this.draw.deleteAll();

		this.feature = geoJson;
		this.initEditFeature();
		this.setNewCoordinates();
	}
	updateMapMarker(_event) {
		let valid = true;
		const geoJson = this.getGeoJsonFromInputs();
		const coords = geoJson.geometry.coordinates;
		coords.forEach((element, index) => {
			// TODO: catch error and show some warning "Uncaught Error: Invalid LngLat latitude value: must be between -90 and 90"
			valid =
				valid &&
				!Number.isNaN(element) &&
				((index === 0 && element >= -180.0 && element <= 180.0) ||
					(index === 1 && element >= -90.0 && element <= 90.0));
		});

		if (valid) {
			this.updateFeature(geoJson);
		} else {
			if (this.feature) {
				this.draw.trash();
			}
		}
	}
	removeFeature() {
		if (this.feature) {
			this.feature = undefined;
		}

		this.resetCoordinates();
		this.resetHiddenFieldValue();
		this.changeDrawMode();
	}
	shortenCoordinates(coords) {
		for (let i = 0; i < coords.length; i++) {
			if (Array.isArray(coords[i]))
				coords[i] = this.shortenCoordinates(coords[i]);
			else coords[i] = Number(coords[i].toFixed(this.precision));
		}

		return coords;
	}
	getFeatureLatLon() {
		const coords = this.feature.geometry.coordinates;

		return this.shortenCoordinates(coords);
	}
	setNewCoordinates() {
		this.setCoordinates();
		this.setHiddenFieldValue(this.feature);
		if (this.feature) this.updateMapPosition();
	}
	setCoordinates() {
		if (!(this.feature && this.isPoint())) return;

		const latLon = this.getFeatureLatLon();
		this.$latitudeField.val(latLon[1]);
		this.$longitudeField.val(latLon[0]);
	}
	resetCoordinates() {
		if (!this.isPoint()) return;

		this.$latitudeField.val("");
		this.$longitudeField.val("");
	}
	getGeoJsonFromInputs() {
		return this.getGeoJsonFromCoordinates(
			[
				Number.parseFloat(this.$longitudeField.val()),
				Number.parseFloat(this.$latitudeField.val()),
			],
			this.type,
		);
	}
	getGeoJsonFromGeometry(geometry) {
		return this.getGeoJsonFromCoordinates(geometry.coordinates, geometry.type);
	}
	getGeoJsonFromCoordinates(coords, type) {
		return {
			type: "Feature",
			properties: {},
			geometry: {
				type: type,
				coordinates: coords,
			},
		};
	}
	setHiddenFieldValue(geoJson) {
		this.value = geoJson;

		if (geoJson?.geometry?.type?.startsWith("LineString")) {
			geoJson.geometry.type = `Multi${geoJson.geometry.type}`;
			geoJson.geometry.coordinates = [geoJson.geometry.coordinates];
		}

		this.$locationField.val(JSON.stringify(geoJson));
		this.$locationField.trigger("change");
	}
	resetHiddenFieldValue() {
		this.value = null;
		this.$locationField.val("");
		this.$locationField.trigger("change");
	}
	_getDrawPointStyle() {
		return [
			{
				id: "gl-draw-point-highlight",
				type: "circle",
				filter: [
					"all",
					["==", "$type", "Point"],
					["==", "meta", "feature"],
					["==", "active", "true"],
				],
				paint: {
					"circle-radius": 7,
					"circle-color": this.definedColors.default,
					"circle-stroke-width": 4,
					"circle-stroke-color": this.definedColors.white,
				},
			},
			{
				id: "gl-draw-point",
				type: "circle",
				filter: [
					"all",
					["==", "$type", "Point"],
					["==", "meta", "feature"],
					["==", "active", "false"],
				],
				paint: {
					"circle-radius": 5,
					"circle-color": this.definedColors.default,
					"circle-stroke-width": 4,
					"circle-stroke-color": this.definedColors.white,
				},
			},
		];
	}
	_getDrawLineStyle() {
		return [
			{
				id: "gl-draw-line",
				type: "line",
				filter: [
					"all",
					["==", "$type", "LineString"],
					["!=", "mode", "static"],
				],
				layout: {
					"line-cap": "round",
					"line-join": "round",
				},
				paint: {
					"line-color": this.definedColors.default,
					"line-dasharray": [0.2, 2],
					"line-width": 5,
				},
			},
			{
				id: "gl-draw-polygon-midpoint-halo",
				type: "circle",
				filter: ["all", ["==", "$type", "Point"], ["==", "meta", "midpoint"]],
				paint: {
					"circle-radius": 5,
					"circle-color": this.definedColors.white,
				},
			},
			{
				id: "gl-draw-polygon-midpoint",
				type: "circle",
				filter: ["all", ["==", "$type", "Point"], ["==", "meta", "midpoint"]],
				paint: {
					"circle-radius": 3,
					"circle-color": this.definedColors.default,
				},
			},
			{
				id: "gl-draw-polygon-and-line-vertex-halo-active",
				type: "circle",
				filter: [
					"all",
					["==", "meta", "vertex"],
					["==", "$type", "Point"],
					["!=", "mode", "static"],
				],
				paint: {
					"circle-radius": 7,
					"circle-color": this.definedColors.white,
				},
			},
			{
				id: "gl-draw-polygon-and-line-vertex-active",
				type: "circle",
				filter: [
					"all",
					["==", "meta", "vertex"],
					["==", "$type", "Point"],
					["!=", "mode", "static"],
				],
				paint: {
					"circle-radius": 5,
					"circle-color": this.definedColors.default,
				},
			},
		];
	}
}

export default MapLibreGlEditor;

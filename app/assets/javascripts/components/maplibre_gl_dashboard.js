import MapLibreGlViewer from "./maplibre_gl_viewer";
import urlJoin from "url-join";
import DomElementHelpers from "../helpers/dom_element_helpers";
import turfCircle from "@turf/circle";
import turfBbox from "@turf/bbox";
import isEmpty from "lodash/isEmpty";

class MapLibreGlDashboard extends MapLibreGlViewer {
	constructor(container) {
		super(container);
		this.filterLayers = DomElementHelpers.parseDataAttribute(
			this.container.dataset.filterLayers,
		);
		this.filterFeatures;
		this.mapBounds = DomElementHelpers.parseDataAttribute(
			this.container.dataset.mapBounds,
		);
		this.defaultOptions.bounds =
			!this.mapBounds || Object.values(this.mapBounds).includes(null)
				? undefined
				: Object.values(this.mapBounds);
		this.defaultOptions.fitBoundsOptions = {
			padding: 20,
			maxZoom: 15,
		};
		this.turfCircleOptions = {
			steps: 128,
			units: "kilometers",
		};

		this.searchForm = document.getElementById("search-form");
		this.currentEndpointId = this.searchForm.dataset.endpointId;
	}
	configureMap() {
		super.configureMap();
		this.initEventHandlers();
	}
	async parseInitialFeatures() {
		const features = [];

		if (this.filterLayers?.geo_radius) {
			for (const filter of Object.values(this.filterLayers.geo_radius)) {
				features.push(
					Object.assign(
						turfCircle(
							[parseFloat(filter.lon), parseFloat(filter.lat)],
							filter.unit === "km"
								? parseFloat(filter.distance)
								: parseFloat(filter.distance) / 1000,
						),
						{
							properties: {
								"@id": DomElementHelpers.randomId(),
								"@type": [await I18n.t("filter.geo_radius")],
								name: await I18n.t("frontend.map.filter.geo_radius.popup", {
									lat: filter.lat,
									lon: filter.lon,
									radius: filter.distance,
									unit: filter.unit || "m",
								}),
							},
						},
					),
				);
			}
		}

		if (features.length)
			this.filterFeatures = this._createFeatureCollection(features);

		const bounds = this.getCurrentBounds();

		if (isEmpty(bounds)) return;

		if (
			this.filterLayers?.geo_within_classification &&
			!isEmpty(this.defaultOptions.bounds)
		)
			bounds.extend(this.defaultOptions.bounds);

		this.defaultOptions.bounds = bounds;
	}
	initFeatures() {
		this.drawFeatures();
	}
	initEventHandlers() {
		this._addPopup();
		this._addClickHandler();
	}
	drawFeatures() {
		this._addSourceAndLayer({
			key: "primary",
			sourceLayer: "dataCycle",
			popup: true,
			styleProperty: "@type",
		});

		if (this.filterLayers?.geo_within_classification) {
			const key = "filter_geo_within_classification";
			this.sources[key] = `filter_source_${key}`;
			this._addVectorSource(
				this.sources[key],
				`/concepts/select/${this.filterLayers.geo_within_classification.join(
					",",
				)}`,
			);
			this._polygonLayer({
				layerId: `filter_polygon_${key}`,
				source: this.sources[key],
				sourceLayer: "dcConcepts",
				popup: true,
			});
		}

		if (this.filterFeatures) {
			const key = "filter_geo";
			this.sources[key] = `filter_source_${key}`;
			this._addGeoJsonSource(this.sources[key], this.filterFeatures);
			this._polygonLayer({
				layerId: `filter_polygon_${key}`,
				source: this.sources[key],
				sourceLayer: "",
				popup: true,
			});
		}
	}
	getCurrentBounds() {
		let bounds = super.getCurrentBounds();
		if (!bounds) bounds = new this.maplibreGl.LngLatBounds();
		if (this.filterFeatures) bounds.extend(turfBbox(this.filterFeatures));
		if (isEmpty(bounds)) return;

		return bounds;
	}
	_addSourceType(name, _data) {
		this._addVectorSource(name);
	}
	_addVectorSource(name, path = `/endpoints/${this.currentEndpointId}`) {
		this.map.addSource(name, {
			type: "vector",
			tiles: [
				`${location.protocol}//${location.host}/mvt/v1/${path}/{z}/{x}/{y}.pbf`,
			],
			promoteId: "@id",
			minzoom: 0,
			maxzoom: 22,
		});
	}
	_addClickHandler() {
		this.map.on("click", (e) => {
			const feature = this.map.queryRenderedFeatures(e.point)[0];
			if (feature && feature.source === "feature_source_primary") {
				const url = new URL(window.location);
				url.search = "";
				window.open(urlJoin(url.toString(), `things/${feature.id}`), "_blank");
			}
		});
	}
	getColorMatchHexExpression() {
		const matchEx = ["case"];

		for (const [name, value] of Object.entries(this.typeColors)) {
			matchEx.push(["in", name, ["get", "@type"]]);
			matchEx.push(value);
		}

		matchEx.push(this.typeColors.default);
		return matchEx;
	}
	getHoverColorMatchHexExpression() {
		return this.typeColors.hover;
	}
	getLineHoverColorExpression() {
		return "start_hover";
	}
}

export default MapLibreGlDashboard;

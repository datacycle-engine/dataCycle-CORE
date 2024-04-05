import pick from "lodash/pick";
import isEmpty from "lodash/isEmpty";
import turfBbox from "@turf/bbox";
import turfCircle from "@turf/circle";
import DomElementHelpers from "../helpers/dom_element_helpers";
import throttle from "lodash/throttle";
import MaplibreElevationProfileControl from "./map_controls/maplibre_elevation_profile_control";

const MaplibreGl = () =>
	import("maplibre-gl/dist/maplibre-gl").then((mod) => mod.default);

const iconPaths = {
	start:
		'data:image/svg+xml;utf8,<svg width="21.091" height="33.117" version="1.1" viewBox="0 0 21.091 33.117" xmlns="http://www.w3.org/2000/svg"><path d="m10.545 1c-5.2719 0-9.5453 4.2748-9.5453 9.5484 0 9.5484 9.5453 21.006 9.5453 21.006s9.5453-11.458 9.5453-21.006c0-5.2736-4.2734-9.5484-9.5453-9.5484z" fill="${color}" stroke="${strokeColor}" stroke-width="2" style="paint-order:normal"/><path d="m15.944 11.969-8.9451 5.0275 0.11862-10.26z" fill="%23fff" fill-opacity="1"/></svg>',
};

class MapLibreGlViewer {
	constructor(container) {
		this.container = container;
		this.$container = $(container);
		this.$parentContainer = this.$container.parent(".geographic");
		this.containerId = this.$container.attr("id");
		this.thingId = DomElementHelpers.parseDataAttribute(
			this.container.dataset.thingId,
		);
		this.hasElevation = DomElementHelpers.parseDataAttribute(
			this.container.dataset.hasElevation,
		);
		this.maplibreGl;
		this.map;
		this.value = this.$container.data("value");
		this.beforeValue = this.$container.data("before-position");
		this.afterValue = this.$container.data("after-position");
		this.type = this.$container.data("type") || "Collection";
		this.additionalValues = this.$container.data("additionalValues") || {};
		this.additionalValuesOverlay = this.$container.data(
			"additionalValuesOverlay",
		);
		this.feature;
		this.additionalFeatures = {};
		this.filterLayers = DomElementHelpers.parseDataAttribute(
			this.container.dataset.filterLayers,
		);
		this.filterFeatures;
		this.mapBounds = DomElementHelpers.parseDataAttribute(
			this.container.dataset.mapBounds,
		);
		this.icons = iconPaths;
		this.colorsHandler = {
			get: (target, name) => {
				if (Object.hasOwn(target, name)) return target[name];
				if (name) return name;

				return target.default;
			},
		};
		this.turfCircleOptions = {
			steps: 128,
			units: "kilometers",
		};
		this.definedColors = {
			default: getComputedStyle(document.documentElement).getPropertyValue(
				"--dark-blue",
			),
			lightBlue: getComputedStyle(document.documentElement).getPropertyValue(
				"--light-blue",
			),
			red: getComputedStyle(document.documentElement).getPropertyValue("--red"),
			green: getComputedStyle(document.documentElement).getPropertyValue(
				"--dark-green",
			),
			white: getComputedStyle(document.documentElement).getPropertyValue(
				"--white",
			),
			yellow: getComputedStyle(document.documentElement).getPropertyValue(
				"--yellow",
			),
			gray: getComputedStyle(document.documentElement).getPropertyValue(
				"--gray",
			),
		};
		this.iconColorBase = this.definedColors;
		this.colors = new Proxy(this.definedColors, this.colorsHandler);
		this.zoomMethod = "ctrlKey";
		this.mouseZoomTimeout;
		this.mapOptions = this.$container.data("map-options");
		this.mapStyles = this.mapOptions.styles;
		this.mapBackend = this.mapOptions.viewer || this.mapOptions.editor;
		this.typeColors = this.mapOptions.type_colors;
		this.defaultOptions = pick(this.mapOptions, [
			"center",
			"zoom",
			"minZoom",
			"maxZoom",
			"maxBounds",
		]);
		// fallback for old config files main projects
		if (!("center" in this.defaultOptions)) {
			this.defaultOptions.center = [
				this.mapOptions.longitude,
				this.mapOptions.latitude,
			];
		}
		this.defaultOptions.fitBoundsOptions = {
			padding: 50,
			maxZoom: 15,
		};
		this.defaultOptions.bounds =
			!this.mapBounds || Object.values(this.mapBounds).includes(null)
				? undefined
				: Object.values(this.mapBounds);
		this.highDpi = window.devicePixelRatio > 1;

		this.credentials = this.mapOptions.credentials;
		this.additionalSources = {};
		this.additionalLayers = {};
		this.selectedAdditionalSources = {};
		this.selectedAdditionalLayers = {};
		this.sources = {};
		this.layers = {};
		this.allRenderedLayers = [];
		this.hoveredStateId = {};
		this.throttledHighlight = throttle(this._highlightLinked.bind(this), 1000);
	}
	async setup() {
		try {
			this.maplibreGl = await MaplibreGl();
			await this.initMap();
			this.map.on("load", this.configureMap.bind(this));
		} catch (error) {
			console.error(error);
		}
	}
	async initMap() {
		await this.parseInitialFeatures();

		this.map = new this.maplibreGl.Map(
			Object.assign(this.defaultOptions, {
				container: this.containerId,
				style: await this.mapBaseStyle(),
				transformRequest: this.transformRequest.bind(this),
			}),
		);
	}
	transformRequest(url, _resourceType) {
		if (
			url.includes("tiles.pixelmap.at/") ||
			url.includes("tiles.pixelpoint.at/")
		) {
			return {
				headers: {
					Authorization: `Bearer ${this.credentials.api_key}`,
				},
				url: url,
			};
		}

		if (url.includes(location.host)) {
			return {
				headers: {
					"X-CSRF-Token": document.getElementsByName("csrf-token")[0].content,
				},
				url: `${url}?cache=false`,
			};
		}

		return;
	}
	async configureMap() {
		await this.initControls();
		await this.setZoomMethod();
		await this.setIcons();

		await this.initFeatures();
		await this._disableScrollingOnMapOverlays();
		await this.initMouseWheelZoom();
	}
	initFeatures() {
		this.drawFeatures();
		this.drawAdditionalFeatures();
	}
	async parseInitialFeatures() {
		if (!this.feature && this.value) this.feature = this.value;

		const beforeFeature = this.beforeValue
			? { beforeValue: this.beforeValue }
			: {};
		const afterFeature = this.afterValue ? { afterValue: this.afterValue } : {};

		this.additionalFeatures = {
			...beforeFeature,
			...afterFeature,
			...this.additionalValues,
		};

		await this.parseFilterFeatures();

		const bounds = this.getCurrentBounds();

		if (isEmpty(bounds)) return;

		if (
			this.filterLayers?.geo_within_classification &&
			!isEmpty(this.defaultOptions.bounds)
		)
			bounds.extend(this.defaultOptions.bounds);

		this.defaultOptions.bounds = bounds;
	}
	async parseFilterFeatures() {
		const features = [];

		if (this.filterLayers?.geo_radius) {
			for (const filter of Object.values(this.filterLayers.geo_radius)) {
				features.push(
					Object.assign(
						turfCircle(
							[Number.parseFloat(filter.lon), Number.parseFloat(filter.lat)],
							filter.unit === "km"
								? Number.parseFloat(filter.distance)
								: Number.parseFloat(filter.distance) / 1000,
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
	}
	mergeStyles(oldStyle, newStyle, layerOverrides) {
		if (!newStyle) return oldStyle;

		oldStyle.version = Math.max(oldStyle.version ?? 0, newStyle.version);
		oldStyle.sources = Object.assign({}, oldStyle.sources, newStyle.sources);

		if (!oldStyle.layers) oldStyle.layers = [];
		for (const layer of newStyle.layers)
			oldStyle.layers.push(Object.assign({}, layer, layerOverrides));

		for (const [key, value] of Object.entries(newStyle)) {
			if (Object.hasOwn(oldStyle, key)) continue;

			oldStyle[key] = value;
		}

		return oldStyle;
	}
	async mapBaseStyle() {
		const styles = {};

		if (!this.mapStyles) throw "No Map-Style defined!";

		for (const style of this.mapStyles) {
			let newStyle;

			if (
				typeof style.value === "string" &&
				typeof this[`baseLayer${style.value}`] === "function"
			)
				newStyle = this[`baseLayer${style.value}`]();
			else if (typeof style.value === "string" && style.value) {
				const options = { Accept: "application/json" };
				if (this.credentials?.api_key) {
					options.Authorization = `Bearer ${this.credentials.api_key}`;
				}
				const response = await fetch(style.value, { headers: options });
				newStyle = await response.json();
			} else if (typeof style.value === "object" && style.value)
				newStyle = style.value;

			this.mergeStyles(styles, newStyle, pick(style, ["minzoom", "maxzoom"]));
		}

		return styles;
	}
	baseLayerOSM() {
		return {
			version: 8,
			sources: {
				"osm-tiles": {
					type: "raster",
					tiles: [
						"https://a.tile.openstreetmap.org/{z}/{x}/{y}.png",
						"https://b.tile.openstreetmap.org/{z}/{x}/{y}.png",
						"https://c.tile.openstreetmap.org/{z}/{x}/{y}.png",
					],
					tileSize: 256,
					attribution:
						'&#169; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors.',
				},
			},
			layers: [
				{
					id: "osm-tiles",
					type: "raster",
					source: "osm-tiles",
					minzoom: 0,
					maxzoom: 19,
				},
			],
		};
	}
	baseLayerBaseMapAt() {
		const layer = this.highDpi ? "bmaphidpi" : "geolandbasemap";
		const matrixSet = "google3857";
		const style = "normal";
		const fileType = this.highDpi ? "jpeg" : "png";
		return {
			version: 8,
			sources: {
				"basemap-at-tiles": {
					type: "raster",
					tiles: [
						`https://maps.wien.gv.at/basemap/${layer}/${style}/${matrixSet}/{z}/{y}/{x}.${fileType}`,
						`https://maps1.wien.gv.at/basemap/${layer}/${style}/${matrixSet}/{z}/{y}/{x}.${fileType}`,
						`https://maps2.wien.gv.at/basemap/${layer}/${style}/${matrixSet}/{z}/{y}/{x}.${fileType}`,
						`https://maps3.wien.gv.at/basemap/${layer}/${style}/${matrixSet}/{z}/{y}/{x}.${fileType}`,
						`https://maps4.wien.gv.at/basemap/${layer}/${style}/${matrixSet}/{z}/{y}/{x}.${fileType}`,
					],
					tileSize: 256,
					attribution:
						'© <a href="https://www.basemap.at" target="_blank">basemap.at</a>',
				},
			},
			layers: [
				{
					id: "basemap-at-tiles",
					type: "raster",
					source: "basemap-at-tiles",
					minzoom: 0,
					maxzoom: 18,
				},
			],
		};
	}
	baseLayerTourSprung() {
		return {
			version: 8,
			sources: {
				"toursprung-tiles": {
					type: "raster",
					tiles: [
						`https://rtc-cdn.maptoolkit.net/rtc/toursprung-terrain/{z}/{x}/{y}${
							this.highDpi ? "@2x" : ""
						}.png?api_key=${this.credentials.api_key}`,
					],
					tileSize: 256,
					attribution:
						'© <a href="http://www.toursprung.com" target="_blank">Toursprung</a> © <a href="https://www.openstreetmap.org/copyright" target="_blank">OSM Contributors</a>',
				},
			},
			layers: [
				{
					id: "toursprung-tiles",
					type: "raster",
					source: "toursprung-tiles",
					minzoom: 0,
					maxzoom: 22,
				},
			],
		};
	}
	setZoomMethod() {
		const platform = window.navigator.platform;

		if (/Mac/.test(platform)) {
			this.zoomMethod = "metaKey";
		} else {
			this.zoomMethod = "ctrlKey";
		}
	}
	setIcons() {
		for (const [iconKey, iconValue] of Object.entries(this.icons)) {
			for (const [colorKey, colorValue] of Object.entries(this.iconColorBase)) {
				const icon = new Image(21, 33);
				icon.onload = () => this.map.addImage(`${iconKey}_${colorKey}`, icon);
				icon.src = iconValue.interpolate({
					color: escape(colorValue),
					strokeColor: escape(this.colors.white),
				});
			}
		}
	}
	drawFeatures() {
		if (!this.afterValue && this.feature)
			this._addSourceAndLayer({ key: "primary", data: this.feature });
	}
	drawAdditionalFeatures() {
		for (const [key, value] of Object.entries(this.additionalFeatures)) {
			this._addAdditionalSourceAndLayers(
				key,
				value,
				this.constructor.name.includes("Editor") ? "_selected" : "",
			);
		}

		this.drawFilterFeatures();

		this._addPopup();
	}
	drawFilterFeatures() {
		if (this.filterLayers?.geo_within_classification) {
			const key = "filter_geo_within_classification";
			this.sources[key] = `filter_source_${key}`;
			this._addVectorSource(
				this.sources[key],
				`concepts/select/${this.filterLayers.geo_within_classification.join(
					",",
				)}`,
			);

			this._pointLayer({
				layerId: `filter_point_${key}`,
				source: this.sources[key],
				sourceLayer: "dcConcepts",
				popup: true,
			});
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
	_getLastLayerId(idRegex) {
		return this.map
			.getStyle()
			.layers.find(
				(l) => l.metadata?.namespace === "dataCycle" && l.id?.match(idRegex),
			)?.id;
	}
	_lineLayer({
		layerId,
		source,
		sourceLayer = "",
		popup = layerId.includes("additional"),
		styleProperty = "color",
	}) {
		let lineColor = this.definedColors.gray;
		let iconColor = "gray";

		if (layerId.includes("feature")) {
			lineColor = this.definedColors.default;
			iconColor = "default";
		} else if (layerId.includes("_selected")) {
			lineColor = this.definedColors.lightBlue;
			iconColor = "lightBlue";
		}

		this.map.addLayer(
			{
				id: `${layerId}_hover_start`,
				type: "symbol",
				source: source,
				"source-layer": sourceLayer,
				filter: ["==", ["geometry-type"], "LineString"],
				layout: {
					"icon-image": this.getStyleCaseExpression(
						styleProperty,
						this.getLineHoverColorExpression(),
						`start_${iconColor}`,
					),
					"icon-offset": [0, -15],
					"symbol-placement": "point",
				},
				paint: {
					"icon-opacity": [
						"case",
						["boolean", ["feature-state", "hover"], false],
						1,
						0,
					],
				},
				metadata: {
					namespace: "dataCycle",
				},
			},
			this._getLastLayerId("point"),
		);

		this.map.addLayer(
			{
				id: `${layerId}_hover_foreground`,
				type: "line",
				source: source,
				"source-layer": sourceLayer,
				filter: ["==", ["geometry-type"], "LineString"],
				layout: {
					"line-cap": "round",
					"line-join": "round",
				},
				paint: {
					"line-color": this.getStyleCaseExpression(
						styleProperty,
						this.getHoverColorMatchHexExpression(),
						lineColor,
					),
					"line-opacity": [
						"case",
						["boolean", ["feature-state", "hover"], false],
						1,
						0,
					],
					"line-width": [
						"interpolate",
						["linear"],
						["zoom"],
						0,
						1.75,
						5,
						2,
						15,
						this.getStyleCaseExpression("width", ["get", "width"], 5),
					],
				},
				metadata: {
					namespace: "dataCycle",
				},
			},
			this._getLastLayerId(`${layerId}_hover_start`),
		);

		this.map.addLayer(
			{
				id: layerId,
				type: "line",
				source: source,
				"source-layer": sourceLayer,
				filter: ["==", "$type", "LineString"],
				layout: {
					"line-cap": "round",
					"line-join": "round",
				},
				paint: {
					"line-color": this.getStyleCaseExpression(
						styleProperty,
						this.getColorMatchHexExpression(),
						lineColor,
					),
					"line-opacity": iconColor === "gray" ? 0.75 : 1,
					"line-width": [
						"interpolate",
						["linear"],
						["zoom"],
						0,
						1.75,
						5,
						2,
						15,
						this.getStyleCaseExpression("width", ["get", "width"], 5),
					],
				},
				metadata: {
					namespace: "dataCycle",
				},
			},
			this._getLastLayerId(`${layerId}_hover_foreground`),
		);

		this.map.addLayer(
			{
				id: `${layerId}_hover`,
				type: "line",
				source: source,
				"source-layer": sourceLayer,
				filter: ["==", ["geometry-type"], "LineString"],
				layout: {
					"line-cap": "round",
					"line-join": "round",
				},
				paint: {
					"line-color": this.definedColors.white,
					"line-opacity": [
						"case",
						["boolean", ["feature-state", "hover"], false],
						1,
						0,
					],
					"line-width": [
						"interpolate",
						["linear"],
						["zoom"],
						0,
						3,
						5,
						5,
						15,
						this.getStyleCaseExpression("width", ["+", ["get", "width"], 4], 9),
					],
				},
				metadata: {
					namespace: "dataCycle",
				},
			},
			this._getLastLayerId(layerId),
		);

		this.initMapHoverActions(`${layerId}_hover`, source, sourceLayer);

		if (popup)
			this.allRenderedLayers.push(
				`${layerId}_hover`,
				layerId,
				`${layerId}_hover_start`,
			);

		return layerId;
	}
	_pointLayer({
		layerId,
		source,
		sourceLayer = "",
		popup = layerId.includes("additional"),
		styleProperty = "color",
	}) {
		let pointColor = this.definedColors.gray;
		let circleRadius = 5;

		if (layerId.includes("feature")) {
			pointColor = this.definedColors.default;
			circleRadius = 7;
		} else if (layerId.includes("_selected")) {
			pointColor = this.definedColors.lightBlue;
			circleRadius = 7;
		}

		this.map.addLayer({
			id: `${layerId}_hover`,
			type: "circle",
			source: source,
			"source-layer": sourceLayer,
			filter: ["==", "$type", "Point"],
			paint: {
				"circle-radius": [
					"interpolate",
					["linear"],
					["zoom"],
					0,
					1.75,
					5,
					2,
					15,
					circleRadius + 2,
				],
				"circle-stroke-width": [
					"interpolate",
					["linear"],
					["zoom"],
					5,
					0,
					15,
					4,
				],
				"circle-color": this.getStyleCaseExpression(
					styleProperty,
					this.getHoverColorMatchHexExpression(),
					pointColor,
				),
				"circle-stroke-color": this.definedColors.white,
				"circle-opacity": [
					"case",
					["boolean", ["feature-state", "hover"], false],
					1,
					0,
				],
				"circle-stroke-opacity": [
					"case",
					["boolean", ["feature-state", "hover"], false],
					1,
					0,
				],
			},
			metadata: {
				namespace: "dataCycle",
			},
		});

		this.map.addLayer(
			{
				id: layerId,
				type: "circle",
				source: source,
				"source-layer": sourceLayer,
				filter: ["==", "$type", "Point"],
				paint: {
					"circle-radius": [
						"interpolate",
						["linear"],
						["zoom"],
						0,
						1.75,
						5,
						2,
						15,
						circleRadius,
					],
					"circle-stroke-width": [
						"interpolate",
						["linear"],
						["zoom"],
						5,
						0,
						15,
						4,
					],
					"circle-color": this.getStyleCaseExpression(
						styleProperty,
						this.getColorMatchHexExpression(),
						pointColor,
					),
					"circle-stroke-color": this.definedColors.white,
				},
				metadata: {
					namespace: "dataCycle",
				},
			},
			this._getLastLayerId(`${layerId}_hover`),
		);

		this.initMapHoverActions(`${layerId}_hover`, source, sourceLayer);

		if (popup) this.allRenderedLayers.push(`${layerId}_hover`, layerId);

		return layerId;
	}
	_polygonLayer({
		layerId,
		source,
		sourceLayer = "",
		popup = layerId.includes("additional"),
		styleProperty = "color",
	}) {
		let polygonColor = this.definedColors.gray;
		let opacity = 0.5;

		if (layerId.includes("feature")) {
			polygonColor = this.definedColors.default;
		} else if (layerId.includes("_selected")) {
			polygonColor = this.definedColors.lightBlue;
		} else if (layerId.includes("filter")) {
			opacity = 0.3;
		}

		this.map.addLayer(
			{
				id: `${layerId}_hover`,
				type: "fill",
				source: source,
				"source-layer": sourceLayer,
				filter: ["==", "$type", "Polygon"],
				paint: {
					"fill-color": this.getStyleCaseExpression(
						styleProperty,
						this.getHoverColorMatchHexExpression(),
						polygonColor,
					),
					"fill-opacity": opacity,
				},
				metadata: {
					namespace: "dataCycle",
				},
			},
			this._getLastLayerId("line"),
		);

		this.map.addLayer(
			{
				id: layerId,
				type: "fill",
				source: source,
				"source-layer": sourceLayer,
				filter: ["==", "$type", "Polygon"],
				paint: {
					"fill-color": this.getStyleCaseExpression(
						styleProperty,
						this.getColorMatchHexExpression(),
						polygonColor,
					),
					"fill-opacity": opacity,
				},
				metadata: {
					namespace: "dataCycle",
				},
			},
			this._getLastLayerId(`${layerId}_hover`),
		);

		this.initMapHoverActions(`${layerId}_hover`, source, sourceLayer);

		if (popup) this.allRenderedLayers.push(`${layerId}_hover`, layerId);

		return layerId;
	}
	_addPopup() {
		const popup = new this.maplibreGl.Popup({
			closeButton: false,
			closeOnClick: false,
			className: "additional-feature-popup",
		});

		this.map.on("mousemove", async (e) => {
			const feature = this.map.queryRenderedFeatures(e.point, {
				layers: this.allRenderedLayers,
			})[0];

			if (feature?.properties?.name) {
				let html = feature.properties.name;
				if (feature.properties["@type"]) {
					const types = DomElementHelpers.parseDataAttribute(
						feature.properties["@type"],
					);
					if (Array.isArray(types) && types.length) {
						const type = types[types.length - 1].replace("dcls:", "");

						html = `<b>${await I18n.t(`template_names.${type}`, {
							default: type,
						})}</b><br>${html}`;
					}
				}

				popup
					.setLngLat(
						feature.geometry.type !== "Point"
							? e.lngLat
							: feature.geometry.coordinates,
					)
					.setHTML(html)
					.addTo(this.map);

				this.throttledHighlight(feature);
			} else {
				popup.remove();
			}
		});
	}
	_highlightLinked(feature) {
		if (!feature.properties["@id"]) return;

		const listElement = $(`li[data-id*="${feature.properties["@id"]}"]`);

		listElement.addClass("highlight");

		setTimeout(() => {
			listElement.removeClass("highlight");
		}, 1000);
	}
	_addSourceAndLayer({
		key,
		data = null,
		popup = key.includes("additional"),
		styleProperty = "color",
		sourceLayer = "",
	}) {
		this.sources[key] = `feature_source_${key}`;

		this._addSourceType(this.sources[key], data);

		this.layers[key] = {
			polygon: this._polygonLayer({
				layerId: `feature_polygon_${key}`,
				source: this.sources[key],
				popup: popup,
				styleProperty: styleProperty,
				sourceLayer: sourceLayer,
			}),
			line: this._lineLayer({
				layerId: `feature_line_${key}`,
				source: this.sources[key],
				popup: popup,
				styleProperty: styleProperty,
				sourceLayer: sourceLayer,
			}),
			point: this._pointLayer({
				layerId: `feature_point_${key}`,
				source: this.sources[key],
				popup: popup,
				styleProperty: styleProperty,
				sourceLayer: sourceLayer,
			}),
		};
	}
	_addAdditionalSourceAndLayers(key, data, postfix = "") {
		const additionalSources = postfix.includes("_selected")
			? this.selectedAdditionalSources
			: this.additionalSources;
		const additionalLayers = postfix.includes("_selected")
			? this.selectedAdditionalLayers
			: this.additionalLayers;
		const configs = {
			sourceId: `additional_values_source${postfix}_${key}`,
			layerIds: {
				line: `additional_values_line${postfix}_${key}`,
				point: `additional_values_point${postfix}_${key}`,
				polygon: `additional_values_polygon${postfix}_${key}`,
			},
		};

		if (additionalSources[key]) return;

		additionalSources[key] = configs.sourceId;

		this._addSourceType(additionalSources[key], data);
		additionalLayers[key] = {
			polygon: this._polygonLayer({
				layerId: configs.layerIds.polygon,
				source: additionalSources[key],
			}),
			line: this._lineLayer({
				layerId: configs.layerIds.line,
				source: additionalSources[key],
			}),
			point: this._pointLayer({
				layerId: configs.layerIds.point,
				source: additionalSources[key],
			}),
		};

		return configs;
	}
	_addSourceType(name, data) {
		this._addGeoJsonSource(name, data);
	}
	_addGeoJsonSource(name, data) {
		this.map.addSource(name, {
			type: "geojson",
			data: data,
			promoteId: "@id",
		});
	}
	_addVectorSource(name, path) {
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
	_disableScrollingOnMapOverlays() {
		this.$parentContainer.siblings(".map-info").on("wheel", (event) => {
			if (event.originalEvent[this.zoomMethod]) event.preventDefault();
		});

		this.$container.on("wheel", "*", (event) => {
			if (event.originalEvent[this.zoomMethod]) event.preventDefault();
		});
	}
	initControls() {
		this.map.addControl(new this.maplibreGl.NavigationControl(), "top-left");
		this.map.addControl(new this.maplibreGl.FullscreenControl(), "top-right");
		if (this.isLineString() && this.hasElevation)
			this.map.addControl(
				new MaplibreElevationProfileControl({ thingId: this.thingId }),
				"top-right",
			);
	}
	initMouseWheelZoom() {
		this.map.scrollZoom.disable();

		this.map.on("wheel", (event) => {
			if (
				!event.originalEvent[this.zoomMethod] &&
				document.fullscreenElement !== this.$container.get(0)
			) {
				if (this.map.scrollZoom._enabled) this.map.scrollZoom.disable();

				if (!this.$container.find(".scroll-overlay").length) {
					const $element = $(
						'<div class="scroll-overlay" style="display: none;"><div class="scroll-overlay-text"></div></div>',
					);

					this.$container.append($element);
					$element.fadeIn(100);

					I18n.translate(`frontend.map.scroll_notice.${this.zoomMethod}`).then(
						(text) => {
							$($element).find(".scroll-overlay-text").text(text);
						},
					);
				} else {
					this.$container.find(".scroll-overlay").fadeIn(100);
				}

				window.clearTimeout(this.mouseZoomTimeout);
				this.mouseZoomTimeout = window.setTimeout(() => {
					this.$container.find(".scroll-overlay").fadeOut(100);
				}, 1000);
			} else {
				event.originalEvent.preventDefault();

				if (!this.map.scrollZoom._enabled) this.map.scrollZoom.enable();

				this.$container.find(".scroll-overlay").fadeOut(100);
			}
		});
	}
	_createFeatureCollection(data = []) {
		return {
			type: "FeatureCollection",
			features: data,
		};
	}
	initMapHoverActions(layerId, source, sourceLayer = "") {
		this.map.on("mousemove", layerId, (e) => {
			this.map.getCanvas().style.cursor = e.features.length ? "pointer" : "";

			if (e.features.length > 0) {
				if (this.hoveredStateId[layerId]) {
					this.map.setFeatureState(
						{
							source: source,
							sourceLayer: sourceLayer,
							id: this.hoveredStateId[layerId],
						},
						{ hover: false },
					);
				}
				this.hoveredStateId[layerId] = e.features[0].id;
				this.map.setFeatureState(
					{
						source: source,
						sourceLayer: sourceLayer,
						id: this.hoveredStateId[layerId],
					},
					{ hover: true },
				);
			}
		});
		this.map.on("mouseleave", layerId, () => {
			this.map.getCanvas().style.cursor = "";

			if (this.hoveredStateId[layerId] != null) {
				this.map.setFeatureState(
					{
						source: source,
						sourceLayer: sourceLayer,
						id: this.hoveredStateId[layerId],
					},
					{ hover: false },
				);
			}
			this.hoveredStateId[layerId] = null;
		});
	}
	getCurrentBounds() {
		const bounds = new this.maplibreGl.LngLatBounds();

		if (this.feature) bounds.extend(turfBbox(this.feature));

		for (const geoJson of Object.values(this.additionalFeatures)) {
			const bbox = turfBbox(geoJson);

			if (
				Object.values(bbox).includes(Number.POSITIVE_INFINITY) ||
				Object.values(bbox).includes(Number.NEGATIVE_INFINITY)
			)
				continue;

			bounds.extend(bbox);
		}
		if (this.filterFeatures) bounds.extend(turfBbox(this.filterFeatures));

		if (isEmpty(bounds)) return;

		return bounds;
	}
	updateMapPosition() {
		const bounds = this.getCurrentBounds();

		if (isEmpty(bounds)) return;

		return this.map.fitBounds(bounds, {
			padding: 50,
			maxZoom: 15,
		});
	}
	getStyleCaseExpression(property, output, fallback) {
		return [
			"case",
			["boolean", ["to-boolean", ["get", property]]],
			output,
			fallback,
		];
	}
	getColorMatchHexExpression() {
		const matchEx = ["match", ["get", "color"]];

		for (const [name, value] of Object.entries(this.definedColors)) {
			matchEx.push(name, value);
		}

		matchEx.push(this.definedColors.default);

		return matchEx;
	}
	getHoverColorMatchHexExpression() {
		return this.getColorMatchHexExpression();
	}
	getLineHoverColorExpression() {
		return ["concat", "start_", ["get", "color"]];
	}
	isPoint() {
		return this.type?.includes("Point");
	}
	isLineString() {
		return this.type?.includes("LineString");
	}
}

export default MapLibreGlViewer;

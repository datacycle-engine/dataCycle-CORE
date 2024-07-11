import MapLibreGlEditor from "./maplibre_gl_editor";
import isEmpty from "lodash/isEmpty";
import fetchInject from "fetch-inject";
import MtkAdditionalValuesFilterControl from "./map_controls/mtk_additional_values_filter_control";
import UndoRedoControl from "./map_controls/mtk_maplibre_undo_redo_control";
import pick from "lodash/pick";

const mtkLibrary = ["https://static.maptoolkit.net/mtk/v10.0.1/mtk.js"];
const defaultMtkScripts = [
	"https://static.maptoolkit.net/mtk/v10.0.1/mtk.css",
	"https://static.maptoolkit.net/mtk/v10.0.1/editor-gui.css",
	"https://static.maptoolkit.net/mtk/v10.0.1/editor-gui.js",
];
const mtkElevationProfile = [
	"https://static.maptoolkit.net/mtk/v10.0.1/elevationprofile.css",
	"https://static.maptoolkit.net/mtk/v10.0.1/elevationprofile.js",
];

class TourSprungEditor extends MapLibreGlEditor {
	constructor(container) {
		super(container);

		this.credentials = this.mapOptions.credentials;
		this.routeMarkers = [];
		this.highlightedFeatures;
		this.mtkMap;
		this.feature = this.value;
		this.featurePolyLine;
		this.editorGui;
		this.draggingMarker;
		this.allRenderedLayers = [];
		this.showElevationProfile = this.$container.data("elevationProfile");
		this.elevationProfile;
		this.elevationProfilePromise;
		this.keyFiguresMapping = {
			length: "distance",
			max_altitude: "elevation_max",
			min_altitude: "elevation_min",
			ascent: "ascend",
			descent: "descend",
		};
	}
	static isAllowedType(type) {
		return type?.includes("LineString");
	}
	setup() {
		this.setZoomMethod();

		this.loadExtenalScripts()
			.then(this.initMap.bind(this))
			.catch((e) => {
				console.error("failed to load MapToolKit!", e);
			});
	}
	async loadExtenalScripts() {
		return await fetchInject(defaultMtkScripts, fetchInject(mtkLibrary));
	}
	_styleControlWithOptions() {
		const controlConfig = {};

		if (this.mapOptions.maptypes)
			controlConfig.maptypes = this.mapOptions.maptypes;
		if (this.mapOptions.maplayers)
			controlConfig.layers = this.mapOptions.maplayers.map((v) => {
				v.value = new MTK.StyleLayer(v.value);
				return v;
			});

		return new MTK.StyleControl(controlConfig);
	}
	initMap() {
		this.maplibreGl = window.maplibregl;
		this.parseInitialFeatures();

		MTK.init({
			apiKey: this.credentials.api_key,
			language: DataCycle.uiLocale,
		}).createMap(
			this.containerId,
			{
				map: {
					mapType: this.mapOptions.maptype || "toursprung-terrain",
					location: pick(this.defaultOptions, ["center", "zoom", "bounds"]),
					controls: [],
				},
			},
			this.configureMap.bind(this),
		);
		this.initEventHandlers();
	}
	initEventHandlers() {
		super.initEventHandlers();

		this.$container.on(
			"dc:geoKeyFigure:compute",
			this._computeKeyFigure.bind(this),
		);
	}
	_setElevationProfileFromFeature() {
		this.elevationProfilePromise = (async () => {
			if (!this.elevationProfile) await this._renderElevationProfile();

			return new Promise((resolve, _reject) => {
				this.elevationProfile.setPolyline(this.featurePolyLine, {}, () =>
					resolve(),
				);
			});
		})();
	}
	async _computeKeyFigure(event, data = {}) {
		event.preventDefault();

		if (!(this.elevationProfile || this.elevationProfilePromise))
			this._setElevationProfileFromFeature();

		await this.elevationProfilePromise;
		this.elevationProfilePromise = null;

		const keyFigures = this.elevationProfile.getData();
		const key = data.attributeKey;

		if (!(key && keyFigures && keyFigures.elevation)) return;

		data.callback(
			Math.round(keyFigures.elevation[this.keyFiguresMapping[key] || key]),
		);
	}
	configureMap(map) {
		this.mtkMap = map;
		this.map = this.mtkMap.gl;

		this.configureScrolling();

		if (this.mapOptions.i18n)
			MTK.i18n = Object.assign({}, this.mapOptions.i18n);

		this.configureEditor();

		if (this.value) this.drawInitialRoute();
		this.initMtkEvents();

		this.drawAdditionalFeatures();
	}
	initMtkEvents() {
		this._disableScrollingOnMapOverlays();
		this.initMouseWheelZoom();

		MTK.event.addListener(this.editorGui.editor, "update", () => {
			this.featurePolyLine = this.editorGui.editor.getPolyline();
			this.feature = this.editorGui.editor.exportGeoJSON().features[0];

			this.setHiddenFieldValue(this.feature);

			if (this.showElevationProfile || this.elevationProfile)
				this._setElevationProfileFromFeature();
		});

		this.mtkMap.on("maptypechanged", (_event) => {
			this.allRenderedLayers = [];
			this.drawAdditionalFeatures();
			this._changeMtkLineStyle();
		});
	}
	drawInitialRoute() {
		this.editorGui.editor.loadGeoJSON(
			this._createFeatureCollection([this.value]),
		);

		this.featurePolyLine = this.editorGui.editor.getPolyline();
	}
	iconOptions(type = "default", hover = false, color = "default") {
		const iconId = `marker-icon-${type}-${color}-${
			hover ? "hovered" : "not-hovered"
		}`;

		const imageUrl = this.icons[type].interpolate({
			color: escape(this.colors[color]),
			strokeColor: escape(this.colors[hover ? "white" : color]),
			opacity: hover ? 1 : 0.9,
		});

		if (this.map.hasImage(iconId)) return iconId;

		let customIcon = new Image(21, 33);
		customIcon.onload = () => {
			if (this.map.hasImage(iconId)) {
				customIcon = null;
				return;
			}

			this.map.addImage(iconId, customIcon);
		};
		customIcon.src = imageUrl;

		return iconId;
	}
	lineStyle(options = {}) {
		return Object.assign(
			{
				color: this.colors.default,
				opacity: 1,
				width: 5,
			},
			options,
		);
	}
	extendEditorInterface() {
		const uploadable = this.uploadable;

		class CustomEditorInterface extends MTK.EditorInterface {
			_replacefileUploadControl(parent, b) {
				const mtkImport = parent.querySelector(".mtk-editor-import");

				if (uploadable) {
					this.editor.loadFile = function ($input) {
						this.uploadFile($input, (_err, d) => {
							this.setWaypoints(d.waypoints);

							if (d.bounds) b.fitBounds(d.bounds, { padding: 50 });
						});
					};

					const el = document.createElement("button");
					el.className = "dc-mtk-button dc-mtk-import-gpx";

					el.addEventListener("click", (event) => {
						event.preventDefault();
						event.stopImmediatePropagation();

						event.currentTarget.parentElement
							.querySelector('input[type="file"]')
							.click();
					});

					const input = document.createElement("input");
					input.setAttribute("type", "file");
					input.setAttribute("hidden", true);
					input.setAttribute("accept", ".gpx,.kml,.geojson");
					input.addEventListener("change", (event) => {
						event.preventDefault();
						event.stopImmediatePropagation();

						this.editor.loadFile(event.currentTarget);
					});

					while (mtkImport.firstChild) {
						mtkImport.firstChild.remove();
					}

					mtkImport.appendChild(input);
					mtkImport.appendChild(el);
				} else {
					mtkImport.remove();
				}
			}
			onAdd(b) {
				const container = super.onAdd(b);
				const buttons = container.querySelectorAll(".mtk-editor-button");

				for (let i = 0; i < buttons.length; ++i) {
					buttons[i].addEventListener("click", (event) => {
						event.preventDefault();
					});
				}

				this._replacefileUploadControl(container, b);

				return container;
			}
		}

		this.extendedEditorInterface = CustomEditorInterface;
	}
	_captureClickEvents() {
		const mapBoxControls = this.$container
			.get(0)
			.querySelectorAll(".maplibregl-ctrl");
		for (const control of mapBoxControls) {
			control.addEventListener("click", (event) => {
				event.preventDefault();
			});
		}
	}
	_changeMtkLineStyle() {
		const waypointLayerDefinition = this.editorGui.editor
			.getLayerDefinitions()
			.find((v) => v.type === "symbol");
		const waypointLayerId = waypointLayerDefinition?.id;

		if (waypointLayerId) {
			this.map.setLayoutProperty(waypointLayerId, "icon-size", [
				"case",
				["==", ["get", "icon"], "end"],
				0.8,
				["==", ["get", "icon"], "start"],
				0.7,
				0.5,
			]);
		}

		this.editorGui.editor.outline.width = 0;
		Object.assign(this.editorGui.editor.line, this.lineStyle());
		Object.assign(this.editorGui.editor.dashedLine, this.lineStyle());
	}
	async _renderElevationProfile() {
		if (!this.elevationProfile) await fetchInject(mtkElevationProfile);

		this.elevationProfile = new MTK.ElevationProfile();
		this.elevationProfile._container
			.querySelector("rect.mtk-elevation-close")
			.dispatchEvent(new Event("click"));
		if (this.showElevationProfile) this.elevationProfile.addTo(this.mtkMap);
		this.$container.trigger("dc:map:elevationProfileInitialized");
	}
	configureEditor() {
		this.map.addControl(new maplibregl.NavigationControl(), "bottom-left");
		new MTK.GeocoderControl().addTo(this.mtkMap, "top-right");
		this.map.addControl(new maplibregl.FullscreenControl(), "top-right");
		this._styleControlWithOptions().addTo(this.mtkMap, "bottom-right");

		this.extendEditorInterface();
		this._captureClickEvents();

		const options = { editor: {} };
		if (this.mapOptions.editor_default_routing)
			options.editor.routeType = this.mapOptions.editor_default_routing;

		this.editorGui = new this.extendedEditorInterface(options).addTo(
			this.mtkMap,
		);

		this.map.addControl(new UndoRedoControl(this), "top-left");

		if (!isEmpty(this.additionalValuesOverlay))
			this.map.addControl(
				new MtkAdditionalValuesFilterControl(this),
				"top-left",
			);

		this._changeMtkLineStyle();
	}
}

export default TourSprungEditor;

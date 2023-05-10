import MapLibreGlViewer from "./maplibre_gl_viewer";
import urlJoin from "url-join";

class MapLibreGlDashboard extends MapLibreGlViewer {
	constructor(container) {
		super(container);

		this.defaultOptions.fitBoundsOptions = {
			padding: 20,
			maxZoom: 15,
		};

		this.searchForm = document.getElementById("search-form");
		this.currentEndpointId = this.searchForm.dataset.endpointId;
	}
	configureMap() {
		super.configureMap();
		this.initEventHandlers();
	}
	initFeatures() {
		this.drawFeatures();
		this.drawAdditionalFeatures();
	}
	initEventHandlers() {
		this._addClickHandler();
	}
	drawFeatures() {
		this._addSourceAndLayer({
			key: "primary",
			sourceLayer: "dataCycle",
			popup: true,
			styleProperty: "@type",
		});
	}
	_addSourceType(name, _data) {
		this._addVectorSource(name, `/endpoints/${this.currentEndpointId}`);
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

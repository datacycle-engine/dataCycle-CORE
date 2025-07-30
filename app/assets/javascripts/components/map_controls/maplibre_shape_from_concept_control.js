import { nanoid } from "nanoid";
import {
	getFormDataAsObject,
	parseDataAttribute,
} from "../../helpers/dom_element_helpers";
import ConfirmationModal from "../confirmation_modal";

export default class MaplibreShapeFromConceptControl {
	static containerClassName = "shape-from-concept-control";
	static controlButtonClassName = "dc-shape-from-concept-overlay-button";
	static controlButtonIconClassName = "fa fa-tags";
	constructor(editor) {
		this.editor = editor;
		this.id = nanoid();
		this.observer = new MutationObserver(this.updateGeometry.bind(this));
	}
	onAdd(map) {
		this.map = map;

		this.#setupControls();
		this.#setupOverlay();

		return this.container;
	}
	onRemove() {
		this.container.parentNode.removeChild(this.container);
		this.map = undefined;
	}
	#setupControls() {
		this.container = document.createElement("div");
		this.container.className = `maplibregl-ctrl maplibregl-ctrl-group mapboxgl-ctrl mapboxgl-ctrl-group ${this.constructor.containerClassName}`;

		this.controlButton = document.createElement("button");
		this.controlButton.className = this.constructor.controlButtonClassName;
		this.controlButton.dataset.open = this.id;
		this.controlButton.type = "button";
		I18n.translate("frontend.map.shape_from_concept.button_title", {
			types: this.accept,
		}).then((text) => {
			this.controlButton.title = text;
		});
		this.container.appendChild(this.controlButton);

		const icon = document.createElement("i");
		icon.className = this.constructor.controlButtonIconClassName;
		this.controlButton.appendChild(icon);

		this.geometryContainer = document.createElement("turbo-frame");
		this.geometryContainer.id = `${this.id}-geometry`;
		this.controlButton.appendChild(this.geometryContainer);
		this.observer.observe(this.geometryContainer, {
			attributes: true,
			attributeFilter: ["data-geojson"],
		});
	}
	async #setupOverlay() {
		this.overlay = document.createElement("turbo-frame");
		this.overlay.dataset.reveal = true;
		this.overlay.id = this.id;
		this.overlay.loading = "lazy";
		this.overlay.src = DataCycle.remoteRenderUrl({
			options: { overlay_id: this.id },
			partial:
				"data_cycle_core/contents/editors/geographic/shape_from_concept_overlay",
		});
		this.overlay.className = "maplibre-shape-from-concept-overlay reveal";
		this.overlay.addEventListener(
			"turbo:frame-load",
			this.#initOverlay.bind(this),
		);
		document.body.appendChild(this.overlay);
	}
	#initOverlay(event) {
		this.form = event.target.querySelector(".shape-from-concept-form");
		this.select = this.form.querySelector(".shape-from-concept-select");
		this.previewMap = this.form.querySelector(".geographic-map");
		$(this.select).on("change", this.updateMap.bind(this));
	}
	updateMap(_event) {
		const conceptIds = getFormDataAsObject(this.form)?.concepts || [];
		this.previewMap.dataset.filterLayers = JSON.stringify({
			concept_ids: conceptIds,
		});
	}
	async _handleUploadFile(_evt) {
		this.editor.setUploadedFeature(featureGeometry);
	}
	async renderError(key) {
		I18n.translate(`frontend.map.upload.error.${key}`).then((text) => {
			new ConfirmationModal({
				text: text,
				confirmationText: "Ok",
			});
		});
	}
	updateGeometry(_mutations) {
		const featureGeometry = parseDataAttribute(
			this.geometryContainer.dataset.geojson,
		);
		this.editor.setUploadedFeature(featureGeometry);
		if (typeof $(this.overlay).foundation === "function")
			$(this.overlay).foundation("close");
	}
}

import { gpx } from "@tmcw/togeojson";
import ConfirmationModal from "../confirmation_modal";

class UploadGpxControl {
	constructor(editor) {
		this.editor = editor;
	}
	onAdd(map) {
		this.map = map;

		this._setupControls();

		this.container
			.querySelector("button")
			.addEventListener("click", (event) => {
				event.preventDefault();
				event.stopImmediatePropagation();
				event.currentTarget.parentElement
					.querySelector('input[type="file"]')
					.click();
			});

		this.input = document.createElement("input");
		this.input.setAttribute("type", "file");
		this.input.setAttribute("hidden", true);
		this.input.setAttribute("accept", ".gpx,.kml,.geojson");
		this.input.addEventListener("change", (event) => {
			event.preventDefault();
			event.stopImmediatePropagation();

			this._handleUploadFile(event);
		});
		this.container.appendChild(this.input);

		return this.container;
	}
	onRemove() {
		this.container.parentNode.removeChild(this.container);
		this.map = undefined;
	}
	_setupControls() {
		this.container = document.createElement("div");
		this.container.className =
			"mapboxgl-ctrl mapboxgl-ctrl-group upload-gpx-control";

		this.controlButton = document.createElement("button");
		this.controlButton.className = "dc-upload-gpx-overlay-button";
		this.controlButton.type = "button";
		I18n.translate("frontend.map.upload_gpx.button_title").then((text) => {
			this.controlButton.title = text;
		});
		this.container.appendChild(this.controlButton);

		const icon = document.createElement("i");
		icon.className = "fa fa-upload";
		this.controlButton.appendChild(icon);
	}
	async _handleUploadFile(evt) {
		const file = evt.target.files[0] || null;
		if (!file) {
			new ConfirmationModal({
				text: await I18n.translate("frontend.gpx.file_missing"),
			});
		} else {
			const reader = new FileReader();
			reader.onload = ((_gpxFile) => {
				return async (e) => {
					const xmlString = e.target.result;
					const parser = new DOMParser();
					const xmlDoc = parser.parseFromString(xmlString, "text/xml");
					const geoJSON = gpx(xmlDoc);
					const featureGeometry = {
						type: "MultiLineString",
						coordinates: [],
					};
					if (geoJSON?.features?.length) {
						geoJSON.features.forEach((feature) => {
							if (feature.geometry.type.includes("MultiLineString"))
								featureGeometry.coordinates.push(
									...feature.geometry.coordinates,
								);
							else if (feature.geometry.type.includes("LineString"))
								featureGeometry.coordinates.push(feature.geometry.coordinates);
						});
					}

					if (
						!featureGeometry.coordinates ||
						!featureGeometry.coordinates.length
					) {
						new ConfirmationModal({
							text: await I18n.translate("frontend.gpx.empty"),
							confirmationText: "Ok",
						});
					} else {
						this.editor.setUploadedFeature(featureGeometry);
					}
					this.input.value = "";
				};
			})(file);
			reader.readAsText(file);
		}
	}
}

export default UploadGpxControl;

import { gpx } from '@tmcw/togeojson';
import ConfirmationModal from '../confirmation_modal';

class UploadControl {
	static containerClassName = 'upload-control';
	static controlButtonClassName = 'dc-upload-overlay-button';
	static controlButtonIconClassName = 'fa fa-upload';
	constructor(editor) {
		this.editor = editor;
		this.setExtensionHandler();
		this.setAccept();
	}
	setExtensionHandler() {
		this.extensionHandler = {
			geojson: this.parseJSON.bind(this),
			json: this.parseJSON.bind(this),
		};

		if (this.editor.isLineString()) {
			this.extensionHandler.gpx = this.parseGPX.bind(this);
			this.extensionHandler.kml = this.parseGPX.bind(this);
		}
	}
	setAccept() {
		if (this.editor.isLineString()) this.accept = '.gpx,.kml,.geojson,.json';
		else if (this.editor.isPolygon()) this.accept = '.geojson,.json';
	}
	onAdd(map) {
		this.map = map;

		this._setupControls();

		this.container
			.querySelector('button')
			.addEventListener('click', (event) => {
				event.preventDefault();
				event.stopImmediatePropagation();
				event.currentTarget.parentElement
					.querySelector('input[type="file"]')
					.click();
			});

		this.input = document.createElement('input');
		this.input.setAttribute('type', 'file');
		this.input.setAttribute('hidden', true);
		this.input.setAttribute('accept', this.accept);
		this.input.addEventListener('change', (event) => {
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
		this.container = document.createElement('div');
		this.container.className = `maplibregl-ctrl maplibregl-ctrl-group mapboxgl-ctrl mapboxgl-ctrl-group ${this.constructor.containerClassName}`;

		this.controlButton = document.createElement('button');
		this.controlButton.className = this.constructor.controlButtonClassName;
		this.controlButton.type = 'button';
		I18n.translate('frontend.map.upload.button_title', {
			types: this.accept,
		}).then((text) => {
			this.controlButton.title = text;
		});
		this.container.appendChild(this.controlButton);

		const icon = document.createElement('i');
		icon.className = this.constructor.controlButtonIconClassName;
		this.controlButton.appendChild(icon);
	}
	async _handleUploadFile(evt) {
		const file = evt.target.files[0] || null;
		if (!file) this.renderError('file_missing');
		else {
			const reader = new FileReader();
			reader.onload = ((file) => {
				return async (e) => {
					const handler =
						this.extensionHandler[file.name.split('.').pop().toLowerCase()];

					if (!handler) this.renderError('file_type_not_supported');

					const featureGeometry = handler(e.target.result);

					if (
						!featureGeometry?.coordinates ||
						!featureGeometry?.coordinates?.length
					) {
						this.renderError('empty');
					} else {
						this.editor.setUploadedFeature(featureGeometry);
					}
					this.input.value = '';
				};
			})(file);
			reader.readAsText(file);
		}
	}
	parseJSON(jsonString) {
		try {
			const json = JSON.parse(jsonString);
			const feature = this.getFeatureFromGeoJSON(json);

			if (feature && typeof feature === 'object') return feature;
		} catch (_error) {
			this.renderError('invalid_json');
			return null;
		}
	}
	validTypes() {
		return this.editor.validTypes();
	}
	getFeatureFromGeoJSON(json) {
		if (!json || typeof json !== 'object') return null;

		switch (json.type) {
			case 'FeatureCollection':
				return json.features?.find((item) =>
					this.validTypes().includes(item.geometry?.type),
				)?.geometry;
			case 'Feature':
				if (this.validTypes().includes(json.geometry?.type))
					return json.geometry;
				return null;
			case 'GeometryCollection':
				return json.geometries?.find((item) =>
					this.validTypes().includes(item.type),
				);
		}
	}
	parseGPX(gpxString) {
		const parser = new DOMParser();
		const xmlDoc = parser.parseFromString(gpxString, 'text/xml');
		const geoJSON = gpx(xmlDoc);
		const featureGeometry = {
			type: 'MultiLineString',
			coordinates: [],
		};

		if (geoJSON?.features?.length) {
			for (const feature of geoJSON.features) {
				if (feature.geometry.type.includes('MultiLineString'))
					featureGeometry.coordinates.push(...feature.geometry.coordinates);
				else if (feature.geometry.type.includes('LineString'))
					featureGeometry.coordinates.push(feature.geometry.coordinates);
			}
		}

		return featureGeometry;
	}
	async renderError(key) {
		I18n.translate(`frontend.map.upload.error.${key}`).then((text) => {
			new ConfirmationModal({
				text: text,
				confirmationText: 'Ok',
			});
		});
	}
}

export default UploadControl;

import camelCase from "lodash/camelCase";
import DurationHelpers from "../../helpers/duration_helpers";

class AssetDetailLoader {
	constructor(assetFile) {
		this.assetFile = assetFile;
		this.validation = assetFile.uploader.validation;
		this.loader;

		this.setup();
	}
	setup() {
		const loaderString = camelCase(
			(this.validation && `${this.validation.class.split("::").pop()}Loader`) ||
				"",
		);

		if (typeof this[loaderString] === "function")
			this.loader = this[loaderString].bind(this);
		else this.loader = this.defaultLoader.bind(this);
	}
	async load() {
		await this.loader();
	}
	_fileThumbHtml(thumbHtml) {
		return `<div class="file-thumb">${thumbHtml}<span class="upload-number-container"><span class="upload-number"></span></span></div>`;
	}
	_addImage(src) {
		return new Promise((resolve, reject) => {
			const image = new Image();
			image.onload = () => resolve(image);
			image.onerror = () => reject();
			image.src = src;
		});
	}
	async imageLoader() {
		this.assetFile.prependHtml = this._fileThumbHtml(
			`<object class="" data="${this.assetFile.fileUrl}" type="${this.assetFile.file.type}"><i class="fa fa-picture-o" aria-hidden="true"></i></object>`,
		);

		try {
			const image = await this._addImage(this.assetFile.fileUrl);

			this.assetFile.mediaHtml = await this.assetFile.fileMediaHTML(
				`, ${image.naturalWidth}x${image.naturalHeight}px`,
			);

			this.assetFile.validationOptions = {
				width: image.naturalWidth,
				height: image.naturalHeight,
			};

			this.assetFile._validateAndRender();
		} catch (e) {
			this.assetFile._validateAndRender();
		}
	}
	_addVideo(src) {
		return new Promise((resolve, reject) => {
			const vid = document.createElement("video");
			vid.onloadedmetadata = () => resolve(vid);
			vid.onerror = () => reject();
			vid.setAttribute("src", src);
		});
	}
	async videoLoader() {
		this.assetFile.prependHtml = this._fileThumbHtml(
			'<i class="fa fa-video-camera" aria-hidden="true"></i>',
		);

		try {
			const video = await this._addVideo(this.assetFile.fileUrl);

			window.URL.revokeObjectURL(video.src);

			this.assetFile.mediaHtml = await this.assetFile.fileMediaHTML(
				`, ${video.videoWidth}x${
					video.videoHeight
				}px, ${DurationHelpers.seconds_to_human_time(video.duration)}`,
			);
			this.assetFile.validationOptions = {
				width: video.videoWidth,
				height: video.videoHeight,
			};
			this.assetFile._validateAndRender();
		} catch (_e) {
			this.assetFile._validateAndRender();
		}
	}
	async audioLoader() {
		this.assetFile.prependHtml = this._fileThumbHtml(
			'<i class="fa fa-file-audio-o" aria-hidden="true"></i>',
		);
		this.assetFile._validateAndRender();
	}
	async pdfLoader() {
		this.assetFile.prependHtml = this._fileThumbHtml(
			'<i class="fa fa-file-pdf-o" aria-hidden="true"></i>',
		);
		this.assetFile._validateAndRender();
	}
	async textFileLoader() {
		this.assetFile.prependHtml = this._fileThumbHtml(
			'<i class="fa fa-file-text-o" aria-hidden="true"></i>',
		);
		this.assetFile._validateAndRender();
	}
	async defaultLoader() {
		this.assetFile.prependHtml = this._fileThumbHtml(
			'<i class="fa fa-file-o" aria-hidden="true"></i>',
		);
		this.assetFile._validateAndRender();
	}
}

export default AssetDetailLoader;

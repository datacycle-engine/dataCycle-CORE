import cloneDeep from "lodash/cloneDeep";
import unionBy from "lodash/unionBy";
import DomElementHelpers from "../../helpers/dom_element_helpers";
import uploadDuplicate from "../../templates/uploadDuplicate";
import MimeTypes from "mime";
import AssetDetailLoader from "./asset_detail_loader";
import AssetValidator from "../asset_validator";
import DurationHelpers from "../../helpers/duration_helpers";
import ConfirmationModal from "../confirmation_modal";

class AssetFile {
	constructor(uploader, config = {}) {
		this.id = DomElementHelpers.randomId("asset");
		this.uploaded = config.uploaded;
		this.file = config.file || {};
		this.fileUrl = config.fileUrl;
		this.asset = config.asset;
		this.dataImported = config.dataImported;
		this.attributeFieldValues = [];
		this.attributeFieldsValidated = false;
		this.fileField;
		this.fileFormField;
		this.uploading = false;
		this.valid = {
			valid: false,
		};
		this.uploader = uploader;
		this.validation = this.uploader.validation;
		this.attributeValues =
			config.attributeValues ||
			cloneDeep(this.uploader.renderedAttributes) ||
			{};
		this.retryUpload = false;
		this.target = this.uploader.fileField;
		this.html = '<i class="fa fa-spinner fa-fw fa-spin file-data-loading"></i>';
		this.fileExtension = this._getFileExtension();
	}
	async renderFile() {
		this._renderInitialFileField();
		await this._validateFile();
		this.addEventHandlers();
	}
	addEventHandlers() {
		this.fileField.on(
			"click",
			".retry-upload-button",
			this._retryUpload.bind(this),
		);

		if (this.uploader.contentUploader) {
			this.fileField.on(
				"dc:upload:setFormFields",
				this._setFormFieldValues.bind(this),
			);
			this.fileField.on(
				"dc:upload:syncWithForm",
				this._syncWithForm.bind(this),
			);
		}
	}
	_syncWithForm(event, data = null) {
		event.preventDefault();

		let fileAttributes = this.attributeFieldValues;
		if (!fileAttributes) return;

		if (data.key)
			fileAttributes = fileAttributes.filter((a) => a.name.includes(data.key));

		window.requestAnimationFrame(() => {
			this.fileField.trigger("dc:form:importAttributeValues", {
				locale: data?.locale,
				attributes: fileAttributes,
			});
		});
	}
	_setFormFieldValues(event, data = undefined) {
		event.preventDefault();

		if (!data?.formData) return;

		this.uploader.globalFieldValues = unionBy(
			this.uploader.globalFieldValues,
			data.formData.filter((elem) => elem.name.indexOf("thing") !== 0),
			"name",
		);

		this._renderSpecificFields(
			data.formData.filter((elem) => elem.name.indexOf("thing") === 0),
			data.allFiles,
			data.primaryAttributeKey,
		);
	}
	_renderSpecificFields(fields, all = false, primaryAttributeKey = null) {
		if (all) {
			this.uploader.files.forEach((file) => {
				file.updateFileField(
					file.id === this.id
						? fields
						: fields.filter(
								(v) => !v.name.includes(`[${primaryAttributeKey}]`),
						  ),
				);
			});

			this._updateNeighborForms();
		} else {
			this.updateFileField(fields);
		}
	}
	_updateNeighborForms() {
		const neighbors = this.uploader.files.filter((file) => file.id !== this.id);

		window.requestAnimationFrame(() => {
			neighbors.forEach((file) => {
				file.fileField.trigger("dc:form:importAttributeValues", {
					attributes: file.attributeFieldValues,
				});
			});
		});
	}
	_getFileExtension() {
		if (!this.file) return;

		const mimeType = MimeTypes.getType(this.file.name) || this.file.type;

		return MimeTypes.getExtension(mimeType) || this.file.type.split("/").pop();
	}
	assetId() {
		if (!this.asset) return;

		return this.asset.id;
	}
	updateValidated(data) {
		if (data?.errors && Object.keys(data.errors).length) {
			this.attributeFieldsValidated = false;
		} else {
			this.attributeFieldsValidated = true;
			this.fileField
				.add(this.fileFormField)
				.addClass("validated")
				.removeAttr("title");
		}

		this.uploader.updateCreateButton();
	}
	async updateFileField(fields) {
		if (!this.valid.valid) return;

		if (this.attributeFieldValues) {
			this.attributeFieldValues = this.attributeFieldValues
				.filter((v) => !fields.find((f) => f.name === v.name))
				.concat(cloneDeep(fields));
		} else {
			this.attributeFieldValues = cloneDeep(fields);
		}

		this._updateAttributeFieldValues();
	}
	_setAttributeFieldValues(value) {
		this.attributeFieldValues = this.attributeFieldValues.filter(
			(v) => v.name !== value[0].name,
		);
		this.attributeFieldValues.push(...value);
	}
	async _updateAttributeFieldValues() {
		await this.setAttributeValues();
		this.validateAttributes();
		this._renderAllAttributes();
	}
	async setAttributeValues() {
		for (const [key, attribute] of Object.entries(this.attributeValues)) {
			const values = this.attributeFieldValues.filter(
				(f) =>
					f.name.includes(key) &&
					(!f.name.includes("[translations]") ||
						f.name.includes(`[translations][${this.uploader.locale}]`)),
			);

			if (attribute.type === "boolean") {
				const otherAttributeFieldValues = this.attributeFieldValues.filter(
					(v) => v.name.attributeNameFromKey() !== key,
				);
				const attributeFieldValue = this.attributeFieldValues
					.filter((v) => v.name.attributeNameFromKey() === key)
					.pop();
				this.attributeFieldValues = otherAttributeFieldValues;
				if (attributeFieldValue)
					this.attributeFieldValues.push(attributeFieldValue);

				let value = "false";
				if (values?.length) value = values.pop().value;

				value = await I18n.translate(`common.${value}`);

				Object.assign(attribute, {
					name: key,
					value: this.renderAttributeHtml(attribute, value),
				});
			} else if (values?.length) {
				Object.assign(attribute, {
					name: key,
					value: this.renderAttributeHtml(
						attribute,
						values
							.map((v) => v.text || v.value)
							.filter(Boolean)
							.join(", "),
					),
				});
			} else if (!attribute.value) {
				Object.assign(attribute, {
					name: key,
					value: this.renderAttributeHtml(attribute),
				});
			}
		}
	}
	renderAttributeHtml(attribute, value = "") {
		let v = value;
		if (attribute.type === "datetime" && v && v.length) {
			v = new Date(v).toLocaleDateString();
		}

		const label = attribute.label;

		return `<span class="file-label" title="${label}">${label}</span><span class="file-attribute-value" title="${$(
			`<span>${v}</span>`,
		).text()}">${v}</span>`;
	}
	async validateAttributes() {
		if (this.uploader.showNewForm && !this.attributeFieldValues?.length) {
			this.updateValidated({
				errors: {
					metadata: await I18n.translate("frontend.upload.missing_metadata"),
				},
			});
			return;
		}

		const formData = new FormData();
		formData.append("template", this.uploader.templateName);
		formData.append("strict", "1");
		formData.append(
			`thing[datahash][${this.uploader.assetKey}]`,
			this.assetId(),
		);

		if (this.attributeFieldValues)
			for (const data of this.attributeFieldValues)
				formData.append(data.name, data.value);

		DataCycle.httpRequest("/things/validate", {
			method: "POST",
			body: formData,
		})
			.then((data) => {
				this.updateValidated(data);
			})
			.catch((response) => {
				this.updateValidated({ errors: { reponse: response.statusText } });
			});
	}
	_renderAllAttributes() {
		Object.keys(this.attributeValues).forEach((field, i, arr) => {
			this._renderSpecificField(
				this.attributeValues[field],
				this.attributeValues[arr[i - 1]],
			);
		});
	}
	_renderSpecificField(field, previousField = null) {
		if (
			this.fileField.find(`.asset-attribute[data-name="${field.name}"]`).length
		)
			this.fileField
				.find(`.asset-attribute[data-name="${field.name}"]`)
				.html(field.value);
		else if (previousField)
			this.fileField
				.find(
					`.new-asset-attributes .asset-attribute[data-name="${previousField.name}"]`,
				)
				.after(this._attributeValueHtml(field));
		else
			this.fileField
				.find(".new-asset-attributes .file-attributes-container")
				.append(this._attributeValueHtml(field));
	}
	_attributeValueHtml(field) {
		return `<div class="asset-attribute ${field.type}" data-name="${field.name}">${field.value}</div>`;
	}
	_prepareFileForUpload() {
		this.fileField
			.add(this.fileFormField)
			.removeClass("error finished")
			.addClass("uploading")
			.find(".error")
			.remove();
	}
	_resetFileField() {
		this.fileField.add(this.fileFormField).removeClass("uploading error");
		this.fileField.add(this.fileFormField).find(".upload-number").html("");
		this.fileField
			.add(this.fileFormField)
			.find(".upload-progress-bar")
			.css("width", "0");
	}
	_updateOverlayButtons() {
		if (this.retryUpload) this.fileField.addClass("retry");
		else this.fileField.removeClass("retry");
	}
	async _renderError(error) {
		this.fileField
			.add(this.fileFormField)
			.addClass("error")
			.find(".upload-number")
			.html(await I18n.translate("frontend.upload.upload_error"));

		this._renderErrorHtml("error", error);
		this._updateOverlayButtons();
	}
	async _renderWarning(warning) {
		new ConfirmationModal({
			text: warning,
			confirmationClass: "warning",
			cancelable: true,
			cancelCallback: this._warningCancelCallback.bind(this),
		});
	}
	_warningCancelCallback() {
		DataCycle.httpRequest(`/files/assets/${this.asset.id}`, {
			method: "DELETE",
		}).catch(() => console.warn("asset not destroyed"));
		this.fileField.find(".cancel-upload-button").trigger("click");
	}
	_updateIdsInClonedErrors(errorText) {
		let text = errorText;
		const randomId = DomElementHelpers.randomId("cloned_asset");

		text = text.replaceAll(
			/(")([^"-]*)(-duplicates-list)/gi,
			`$1${randomId}$3`,
		);

		return text;
	}
	_renderErrorHtml(cssClass, message) {
		const fileInfoField = this.fileField.find(".file-info");
		if (fileInfoField.find(`.${cssClass}`).length)
			fileInfoField.find(`.${cssClass}`).html(message);
		else fileInfoField.append(`<span class="${cssClass}">${message}</span>`);

		if (!this.fileFormField) return;

		const fileFormInfoField = this.fileFormField.find(".file-info");
		if (fileFormInfoField.length) {
			if (!fileFormInfoField.find(`.${cssClass}`).length)
				fileFormInfoField.append(`<span class="${cssClass}"></span>`);

			fileFormInfoField
				.find(`.${cssClass}`)
				.html(this._updateIdsInClonedErrors(message));
		}
	}
	async _renderDuplicateHtml(duplicates) {
		const randomId = DomElementHelpers.randomId("duplicate");
		return await uploadDuplicate(randomId, duplicates);
	}
	_attributesWithBlankDefaultValues() {
		return Object.entries(this.attributeValues)
			.filter(([_key, value]) => value.default_value)
			.map((v) => v[0])
			.filter((key) => {
				return !(
					this.attributeFieldValues?.length &&
					this.attributeFieldValues.some((f) => {
						return (
							f.name.includes(`[${key}]`) &&
							(!f.name.includes("[translations]") ||
								f.name.includes(`[translations][${this.uploader.locale}]`)) &&
							f.value &&
							f.value !== false
						);
					})
				);
			});
	}
	_loadDefaultValues() {
		const data_hash = {};
		data_hash[this.uploader.assetKey] = this.assetId();

		const promise = DataCycle.httpRequest("/things/attribute_default_value", {
			method: "POST",
			body: {
				locale: this.uploader.locale,
				template_name: this.uploader.templateName,
				keys: this._attributesWithBlankDefaultValues(),
				data_hash: data_hash,
			},
		});

		promise
			.then((data) => {
				const blankValues = this._attributesWithBlankDefaultValues();
				const defaultValues = Object.fromEntries(
					Object.entries(data).filter(([key]) => blankValues.includes(key)),
				);

				for (const value of Object.values(defaultValues)) {
					this._setAttributeFieldValues(value);
				}

				this._updateAttributeFieldValues();
			})
			.catch((e) => {
				if (e.status !== 404) console.error(e.statusText);
			});

		return promise;
	}
	_renderEditOverlay() {
		this.uploader.remoteOptions.search_required = false;
		if (!this.uploader.remoteOptions.options)
			this.uploader.remoteOptions.options = {
				force_render: true,
			};
		this.uploader.remoteOptions.content_uploader = true;
		this.uploader.remoteOptions.asset_class = this.uploader.validation.class;
		this.uploader.remoteOptions.asset_key = this.uploader.assetKey;
		this.uploader.remoteOptions.options.prefix = this.id;
		this.uploader.remoteOptions.options.render_attributes = true;
		this.uploader.remoteOptions.asset = {
			class: this.uploader.validation.class,
			id: this.assetId(),
		};

		const html = $(
			`<div class="reveal new-content-reveal" id="${this.id}_edit_overlay" data-reveal><button class="close-button" data-close aria-label="Close modal" type="button"><span aria-hidden="true">&times;</span></button><div class="new-content-form remote-render" id="${this.id}_new_form" data-remote-path="data_cycle_core/contents/new/shared/new_form"></div></div>`,
		);

		$(html)
			.find(".new-content-form")
			.attr("data-remote-options", JSON.stringify(this.uploader.remoteOptions));

		const clonedHtml = DomElementHelpers.$cloneElement(
			this.fileField,
		).removeAttr("data-open");

		clonedHtml.html(this._updateIdsInClonedErrors(clonedHtml.html()));
		this.fileFormField = $(clonedHtml).prependTo(html);

		this.fileField
			.find(".file-buttons .edit-upload-button")
			.attr("data-open", `${this.id}_edit_overlay`);

		return html;
	}
	async _initEditForm() {
		if (this.uploader.contentUploader && this.uploader.showNewForm)
			this.fileField
				.append(this._renderEditOverlay())
				.find(".file-buttons .edit-upload-button")
				.prop("disabled", false)
				.attr("title", await I18n.translate("frontend.upload.edit_content"));

		this.fileField
			.siblings(".file-for-upload.finished")
			.trigger("dc:form:uploadedFilesChanged");
	}
	async _updateFileAttributes(data) {
		this.retryUpload = false;

		this.fileField
			.add(this.fileFormField)
			.find(".upload-progress-bar")
			.css("width", "100%");

		if (data.error) {
			this._resetFileField();
			this._renderError(data.error);
			this.errors = data.error;
		} else if (
			!this.uploader.createDuplicates &&
			data.duplicateCandidates &&
			data.duplicateCandidates.length
		) {
			this._resetFileField();
			this._renderError(
				await this._renderDuplicateHtml(data.duplicateCandidates),
			);
			this.errors = await I18n.translate("frontend.upload.found_duplicate");
		} else {
			if (data.duplicateCandidates?.length)
				this._renderErrorHtml(
					"notice",
					await this._renderDuplicateHtml(data.duplicateCandidates),
				);

			if (data.warning) this._renderWarning(data.warning);

			this.uploaded = true;
			this.fileField
				.add(this.fileFormField)
				.removeClass("uploading")
				.addClass("finished")
				.find(".upload-number")
				.html(await I18n.translate("frontend.upload.uploaded_successfully"));
			this.asset = Object.assign({}, this.asset, data);
			if (!this.uploader.showNewForm) {
				this.updateValidated({});
			} else {
				this._loadDefaultValues();
				this._initEditForm();
			}
		}

		this.uploader.updateCreateButton(this.errors);
	}
	async updateProgress(startTime, e) {
		if (!e.lengthComputable) return;

		const elapsedtime = (new Date().getTime() - startTime) / 1000;
		const eta = Math.round((e.total / e.loaded) * elapsedtime - elapsedtime);
		this.fileField
			.add(this.fileFormField)
			.find(".upload-progress-bar")
			.css("width", `${(e.loaded / e.total) * 100}%`);
		this.fileField
			.add(this.fileFormField)
			.find(".upload-number")
			.html(
				`${Math.round(
					(e.loaded / e.total) * 100,
				)}%, <span class="eta">${DurationHelpers.seconds_to_human_time(
					eta,
				)}</span>`,
			);
		if (e.loaded === e.total) {
			this.fileField
				.add(this.fileFormField)
				.find(".upload-number")
				.html(
					`<i class="fa fa-cog fa-spin fa-fw working-spinner"></i>${await I18n.translate(
						"frontend.upload.processing",
					)}`,
				);
		}
	}
	uploadFailed(req) {
		return {
			status: req.status,
			statusText: req.statusText,
			responseJSON: DomElementHelpers.parseDataAttribute(req.response),
		};
	}
	_uploadFile() {
		if (this.uploaded)
			return this._updateFileAttributes(this.dataImported || {});

		this.uploading = true;
		this.uploader.uploadForm.find(".upload-file").attr("disabled", true);
		DataCycle.disableElement(this.uploader.assetReloadButton);

		const data = new FormData();
		data.append("asset[file]", this.file);
		data.append("asset[type]", this.uploader.validation.class);
		data.append("asset[name]", this.file.name);
		this._prepareFileForUpload();
		const startTime = new Date().getTime();

		const promise = new Promise((resolve, reject) => {
			const req = new XMLHttpRequest();

			req.addEventListener(
				"progress",
				this.updateProgress.bind(this, startTime),
				false,
			);
			req.upload.addEventListener(
				"progress",
				this.updateProgress.bind(this, startTime),
				false,
			);
			req.addEventListener("load", () => {
				if (req.status >= 200 && req.status < 300)
					resolve(DomElementHelpers.parseDataAttribute(req.response));
				else reject(this.uploadFailed(req));
			});
			req.addEventListener("error", () => reject(this.uploadFailed(req)));
			req.addEventListener("abort", () => reject(this.uploadFailed(req)));
			req.open("POST", this.uploader.uploadForm.data("url"));
			req.setRequestHeader("Accept", "application/json");
			req.setRequestHeader(
				"X-CSRF-Token",
				document.getElementsByName("csrf-token")[0].content,
			);
			req.send(data);
		});

		promise
			.then(async (data) => {
				if (!document.querySelector(`[data-id="${this.id}"]`)) return;

				await this._updateFileAttributes(data);
			})
			.catch(async (data) => {
				if (!document.querySelector(`[data-id="${this.id}"]`)) {
					this.errors = "already removed";
					return;
				}

				this.retryUpload = true;
				this._resetFileField();
				let error = data.statusText;
				if (data?.responseJSON?.error) error = data.responseJSON.error;
				this.errors = error;
				await this._renderError(error);
			})
			.finally(() => {
				if (!document.querySelector(`[data-id="${this.id}"]`)) return;

				this._updateOverlayButtons();
				this.uploading = false;
				this.uploader.startNextFileUpload();
				DataCycle.enableElement(this.uploader.assetReloadButton);
			});

		this.uploader.ajaxRequests.push(promise);

		this.uploader.checkRequests();
	}
	_renderInitialFileField() {
		this.fileField = $(
			`<div class="file-for-upload" data-file="${this.file.name}" data-id="${this.id}"></div>`,
		).insertBefore(this.target);

		I18n.translate("frontend.upload.metadata_warning.one").then((text) =>
			this.fileField.attr("title", text),
		);
	}
	async _buttonHtml() {
		let html = '<div class="file-buttons">';
		if (this.uploader.contentUploader && this.uploader.showNewForm)
			html += `<button class="button edit-upload-button" disabled="true" title="${await I18n.translate(
				"frontend.upload.edit_locked",
			)}"><i class="fa fa-pencil" aria-hidden="true"></i></button>`;
		html += `<button class="button retry-upload-button" title="${await I18n.translate(
			"frontend.upload.retry_upload",
		)}"><i class="fa fa-refresh" aria-hidden="true"></i></button><button class="button cancel-upload-button alert" title="${await I18n.translate(
			"frontend.upload.remove_file",
		)}"><i class="fa fa-minus" aria-hidden="true"></i></button></div>`;

		return html;
	}
	async fileMediaHTML(additionalFileInfo = "") {
		return `
      <div class="file-info">
        <span class="file-label">${await I18n.translate("frontend.upload.file")}</span>
        <span class="file-name" title="${this.file?.name}">${this.file?.name}</span>
        <span class="file-details">(${
					this.fileExtension
				}, ${this.file.size.file_size(1)}${additionalFileInfo})</span>
      </div>
      ${await this._buttonHtml()}`;
	}
	_fileAppendHTML() {
		return '<div class="upload-progress"><span class="upload-progress-bar"></span></div>';
	}
	async _validateFile() {
		this.mediaHtml = await this.fileMediaHTML();
		this.appendHtml = this._fileAppendHTML();
		if (!this.fileUrl) this.fileUrl = URL.createObjectURL(this.file);

		const detailLoader = new AssetDetailLoader(this);
		await detailLoader.load();
	}
	_initialAttributeHtml() {
		const attributesHtml = [];

		for (const [key, value] of Object.entries(this.attributeValues)) {
			attributesHtml.push(
				this._attributeValueHtml({
					name: key,
					type: value.type,
					value: this.renderAttributeHtml(value),
				}),
			);
		}

		return attributesHtml.join("");
	}
	_renderFileField() {
		this.fileField.html(this.html);

		if (this.errors) {
			this._renderError(this.errors);
			this.fileField
				.find(".file-buttons .edit-upload-button")
				.prop("disabled", true)
				.attr("title", this.errors);
		} else this._updateOverlayButtons();
	}
	async _validateAndRender() {
		this.html = `<div class="new-asset-attributes">${this.prependHtml}
      <div class="file-info-container">
        <div class="file-detail-container">
          ${this.mediaHtml}
        </div>
        <div class="file-attributes-container">
          ${this._initialAttributeHtml()}
        </div>
      </div>
    </div>${this.appendHtml}`;

		this.validator = new AssetValidator(this);
		this.valid = await this.validator.validate();

		if (this.validation && !this.valid.valid) {
			this.errors = this.valid.messages.join(", ");
		} else if (!this.validation) {
			this.errors = await I18n.translate(
				"frontend.upload.format_not_supported",
				{
					data: this.fileExtension,
				},
			);
		}
		this._renderFileField();

		if (this.uploaded) this._updateFileAttributes(this.dataImported || {});
	}
	_retryUpload(event) {
		event.preventDefault();
		event.stopPropagation();

		if (this.fileField.hasClass("uploading")) return;

		this._uploadFile();
	}
}

export default AssetFile;

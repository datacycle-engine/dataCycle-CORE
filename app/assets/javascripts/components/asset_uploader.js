import cloneDeep from "lodash/cloneDeep";
import AssetFile from "./asset_uploader/asset_file";
import CalloutHelpers from "../helpers/callout_helpers";

class AssetUploader {
	constructor(reveal) {
		this.reveal = $(reveal);
		this.validation = this.reveal.data("validation");
		this.type = this.reveal.data("type");
		this.templateName = this.reveal.data("template");
		this.remoteOptions = this.reveal.data("remote-options") || {};
		this.contentUploader = this.reveal.data("content-uploader");
		this.contentUploaderField = $(
			`.content-uploader[data-asset-uploader="${this.reveal.attr("id")}"]`,
		);
		this.fileField = this.reveal.find('input[type="file"].upload-file');
		this.uploadForm = this.reveal.find(".content-upload-form");
		this.createButton = this.uploadForm.find(".content-create-button");
		this.assetReloadButton = this.uploadForm.find(".asset-reload-button");
		this.renderedAttributes = this.reveal.data("rendered-attributes") || {};
		this.formAttributes = this.reveal.data("form-attributes") || {};
		this.showNewForm = Object.keys(this.formAttributes).length > 0;
		this.createDuplicates = this.reveal.data("create-duplicates");
		this.locale = this.reveal.data("locale") || "de";
		this.overlayId = this.reveal.attr("id");
		this.assetKey = this.reveal.data("asset-key") || "asset";
		this.globalFieldValues = [];
		this.ajaxRequests = [];
		this.autocompleteRequests = {};
		this.bulkCreateChannel;
		this.files = [];
		this.saving = false;
		this.createAssetsRequest;
		this.eventHandlers = {
			pageLeave: this.pageLeaveHandler.bind(this),
		};

		this.init();
	}
	init() {
		this.reveal.addClass("dc-asset-uploader");
		this.reveal.on("open.zf.reveal", this.openReveal.bind(this));
		this.reveal.on("closed.zf.reveal", this.closeReveal.bind(this));
		this.reveal.on("dc:upload:setFiles", (_e, data) =>
			this.validateFiles(data.fileList),
		);
		this.reveal.on("dc:upload:setIds", this.importAssetIds.bind(this));
		this.reveal.on(
			"click",
			".file-for-upload .cancel-upload-button",
			this.removeFileHandler.bind(this),
		);

		if (this.contentUploader)
			this.createButton.on("click", this.createAssets.bind(this));

		this.initActionCable();
	}
	pageLeaveHandler(e) {
		e.preventDefault();
		e.returnValue = "";
		return e.returnValue;
	}
	removeFileHandler(event) {
		event.preventDefault();
		event.stopPropagation();

		const target = $(event.currentTarget).closest(".file-for-upload").remove();

		this.files = this.files.filter((f) => f.id !== target.data("id"));
		this.updateCreateButton();
	}
	importAssetIds(event, data) {
		event.preventDefault();
		event.stopPropagation();

		this.reveal.foundation("open");

		const parsedAssets = this.parseAssetsForImport(data.assets);

		if (parsedAssets.length) {
			parsedAssets.forEach((f) => {
				this.checkFileAndQueue(f.file, f);
			});
		}
	}
	parseAssetsForImport(assets) {
		if (!assets?.length) return [];

		return assets.map((a) => {
			let duplicateCandidates = a.duplicate_candidates;

			if (duplicateCandidates?.length)
				duplicateCandidates = duplicateCandidates.map((d) => {
					return {
						id: d.id,
						thumbnail_url: d.metadata?.thumbnail_url,
					};
				});

			return {
				uploaded: true,
				file: {
					type: a.content_type,
					name: a.name,
					size: a.file_size,
				},
				fileUrl: a.file.url,
				asset: a,
				dataImported: {
					duplicateCandidates: duplicateCandidates,
					warning: a.warning,
				},
			};
		});
	}
	openReveal(_event) {
		$(window).on("beforeunload", this.eventHandlers.pageLeave);
		this.reveal.parent(".reveal-overlay").addClass("content-reveal-overlay");
	}
	closeReveal(_event) {
		$(window).off("beforeunload", this.eventHandlers.pageLeave);
		this.contentUploaderField.trigger("dc:upload:filesChanged");
		$(".asset-selector-reveal:visible").trigger("open.zf.reveal");
	}
	initActionCable() {
		this.bulkCreateChannel = window.actionCable.subscriptions.create(
			{
				channel: "DataCycleCore::BulkCreateChannel",
				overlay_id: this.overlayId,
			},
			{
				received: (data) => {
					if (data.progress && this.saving) this.advanceProgress(data);
					else if (data.content_ids) this.finishProgress(data);
				},
			},
		);
	}
	advanceProgress(data) {
		this.updateProgressBar(Math.round((data.progress * 100) / data.items));

		if (data.error && data.field_id) {
			const file = this.fileByFieldId(data.field_id);
			file._renderError(data.error);
			file.fileField.removeClass("creating");
		} else if (!data.error && data.field_id) this.removeFiles(data.field_id);
	}
	async finishProgress(data) {
		if (data.created) this.reset(data.content_ids.map((i) => i.field_id));
		else this.removeFiles(data.content_ids.map((i) => i.field_id));

		if (data.created) {
			try {
				const text = await I18n.t("controllers.success.bulk_created", {
					count: data.content_ids?.length || 0,
				});
				CalloutHelpers.show(text, "success");
			} catch (e) {
				console.error(e);
			}
		}

		if (
			this.contentUploaderField
				.closest(".reveal.new-content-reveal")
				.hasClass("in-object-browser") &&
			this.contentUploaderField.length
		) {
			this.contentUploaderField
				.closest("form.validation-form")
				.trigger("dc:form:setContentIds", {
					contentIds: data.content_ids.map((i) => i.id),
				});

			if (data.created) this.reveal.foundation("close");
		} else if (data.redirect_path) {
			setTimeout(() => {
				window.location.href = data.redirect_path;
			}, 3000);
		}

		if (!data.created && data.error) {
			this.resetProgress(data.error);
		}
	}
	resetProgress(error) {
		CalloutHelpers.show(error, "alert");
		this.updateProgressBar(0);
		this.updateCreateButton(error);
	}
	fileByFieldId(id) {
		return this.files.find((f) => f.id === id);
	}
	removeFiles(fieldIds) {
		let idArray = fieldIds;
		if (!Array.isArray(idArray)) idArray = [idArray];
		if (idArray.length === 0) return;

		for (const f of this.files.filter((f) => idArray.includes(f.id)))
			f.fileField.remove();

		this.files = this.files.filter((f) => !idArray.includes(f.id));
	}
	createAssets(event) {
		event.preventDefault();
		this.saving = true;

		if (this.contentUploader && !this.createButton.prop("disabled"))
			DataCycle.disableElement(this.createButton);
		if (!this.files.length) return;

		const formData = new FormData();
		if (this.globalFieldValues)
			for (const data of this.globalFieldValues)
				formData.append(data.name, data.value);

		formData.append("overlay_id", this.overlayId);

		if (!formData.has("template") && this.templateName)
			formData.append("template", this.templateName);

		this.files.forEach((file, i) => {
			file.fileField.addClass("creating");

			const attributeValues = cloneDeep(file.attributeFieldValues) || [];
			attributeValues.push({
				name: `thing[datahash][${this.assetKey}]`,
				value: file.assetId(),
			});
			attributeValues.push({
				name: "thing[uploader_field_id]",
				value: file.id,
			});
			attributeValues.forEach((a) => {
				a.name = `${a.name.slice(0, 5)}[${i}]${a.name.slice(5)}`;
			});

			if (attributeValues)
				for (const data of attributeValues)
					formData.append(data.name, data.value);
		});

		$(window).off("beforeunload", this.eventHandlers.pageLeave);

		DataCycle.httpRequest(
			"/things/bulk_create",
			{
				method: "POST",
				body: formData,
			},
			0,
		).catch((e) => {
			if (e.status >= 400) console.error(e.statusText);
		});
	}
	async reset(ids = null) {
		if (ids) {
			this.removeFiles(ids);

			if (this.files.length) {
				const error = await I18n.translate(
					"frontend.upload.error_saving_content",
				);
				for (const f of this.files) f._renderError(error);
			}
		} else {
			this.uploadForm.find(".file-for-upload").remove();
			this.files = [];
		}

		this.saving = false;
		this.updateProgressBar(0);
		this.updateCreateButton();
	}
	updateProgressBar(progress) {
		const p = progress || 0;

		this.createButton.find(".progress-value").text(p > 0 ? `${p}%` : "");
		this.createButton
			.find(".progress-bar > .progress-filled")
			.css("width", `${p}%`);
	}
	enableButtons() {
		this.uploadForm.find(".upload-file").attr("disabled", false);
		this.ajaxRequests = [];
	}
	checkRequests() {
		$.when.apply(undefined, this.ajaxRequests).then(
			() => this.enableButtons(),
			() => this.enableButtons(),
		);
	}
	async validateFiles(fileList = undefined) {
		if (this.saving) return;
		if (!fileList?.length) return;

		for (const file of fileList) {
			await this.checkFileAndQueue(file);
		}
	}
	async checkFileAndQueue(file, fileOptions = {}) {
		if (this.files.find((f) => f.file.name === file.name)) return;

		const assetFile = new AssetFile(
			this,
			Object.assign({ file: file }, fileOptions),
		);
		await assetFile.renderFile();

		this.files.push(assetFile);
		this.updateCreateButton(
			await I18n.translate("frontend.upload.metadata_warning.many"),
		);
	}
	async updateCreateButton(error = null) {
		let e = error;

		if (
			this.files.length &&
			!this.files.filter((f) => !(f.attributeFieldsValidated && f.uploaded))
				.length
		) {
			DataCycle.enableElement(this.createButton);
		} else {
			DataCycle.disableElement(this.createButton);
			if (!e) e = await I18n.translate("frontend.upload.missing_metadata");
		}

		if (e)
			this.createButton.attr(
				"data-dc-tooltip",
				`${await I18n.translate("frontend.upload.error")}: ${e}`,
			);
		else this.createButton.removeAttr("data-dc-tooltip");
	}
}

export default AssetUploader;

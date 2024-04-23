import QuillHelpers from "./../helpers/quill_helpers";
import ConfirmationModal from "./../components/confirmation_modal";
import UuidHelper from "./../helpers/uuid_helper";
import ObserverHelpers from "../helpers/observer_helpers";
import CalloutHelpers from "../helpers/callout_helpers";
import ObjectUtilities from "../helpers/object_utilities";

class NewContentDialog {
	constructor(form) {
		this.form = form;
		this.form.classList.add("dcjs-new-content-dialog");
		this.$form = $(this.form);
		this.nextButton = this.$form.find(".next");
		this.prevButton = this.$form.find(".prev");
		this.resetButton = this.$form.find(".button.reset");
		this.crumbs = this.$form.find(".form-crumbs");
		this.contentUploader = this.$form.data("content-uploader");
		this.$formWrapper = this.$form.closest(".new-content-form");
		this.id = this.$formWrapper.attr("id");
		this.locale = this.$form.find(':input[name="locale"]').val() || "de";
		this.reveal = this.$form.closest(".reveal.new-content-reveal");
		this.primaryAttributeKey = this.$form.data("primary-attribute-key");
		this.templateTranslationPlural = this.$form.data("template-translation");
		this.referencedAssetField;
		this.nextAssetButton;
		this.prevAssetButton;
		this.translatedFieldInitObserver = new MutationObserver(
			this.initTranslatableField.bind(this),
		);
		this.changeObserver = new MutationObserver(
			this._checkForChangedFormData.bind(this),
		);
		this.formFieldVisibilityObserver = new IntersectionObserver(
			this.checkForVisibleElements.bind(this),
		);

		this.init();
		this.initEventHandlers();
		this.updateForm();
	}
	init() {
		if (this.contentUploader) {
			this.setReferencedAssetField();
		}
	}
	initEventHandlers() {
		if (this.$form.find("fieldset.active").length === 0)
			this.$form.find("fieldset").first().addClass("active");
		this.nextButton.on("click", this.next.bind(this));
		this.prevButton.on("click", this.prev.bind(this));
		this.$form.on("click", ".form-crumb-link", this.goTo.bind(this));
		this.$form.on("reset", this.resetForm.bind(this));
		this.$form.on(
			"change",
			':input[name="locale"]',
			this.updateLocales.bind(this),
		);
		this.$form.on("dc:multistep:goto", this.goTo.bind(this));
		this.$form.on("keypress", (event) => {
			if (
				event.which === 13 &&
				this.$form.find("fieldset.active:not(:last-of-type)").length
			) {
				event.preventDefault();
				this.next(event);
			}
		});
		this.$form.on(
			"click",
			".copy-attribute-to-all",
			this.copySingleToAllReferenceFields.bind(this),
		);
		this.$form
			.find(".translatable-attribute.active")
			.trigger("dc:remote:render");

		if (this.referencedAssetField) {
			this.updateNavigationButtons();
			this.addCopyAttributeButtons(this.$form);

			this.reveal.on("open.zf.reveal", (event) => {
				this.$form.trigger("dc:form:enable");
				this.updateNavigationButtons(event);
			});

			this.referencedAssetField.on(
				"dc:form:uploadedFilesChanged",
				this.updateNavigationButtons.bind(this),
			);
			this.referencedAssetField.on(
				"dc:form:importAttributeValues",
				this.importAttributeValues.bind(this),
			);
			this.$form.on(
				"dc:form:submitWithoutRedirect",
				this.copyToReferenceField.bind(this),
			);
			this.$form
				.find(".set-all-attributes")
				.on("click", this.copyToAllReferenceFields.bind(this));
			this.translatedFieldInitObserver.observe(
				this.$form.get(0),
				ObserverHelpers.changedClassWithSubtreeConfig,
			);

			if (this.$formWrapper[0].classList.contains("remote-rendered"))
				this.triggerSyncWithContentUploader();
			else
				this.changeObserver.observe(
					this.$formWrapper[0],
					ObserverHelpers.changedClassConfig,
				);
		}
	}
	_checkForChangedFormData(mutations) {
		for (const mutation of mutations) {
			if (mutation.type !== "attributes") continue;

			if (
				mutation.target.classList.contains("remote-rendered") &&
				(!mutation.oldValue || mutation.oldValue.includes("remote-rendering"))
			)
				this.triggerSyncWithContentUploader();
		}
	}
	initTranslatableField(mutations) {
		for (const mutation of mutations) {
			if (
				mutation.target.classList.contains("dc-import-data") &&
				!mutation.target.classList.contains("triggered-sync-with-uploader")
			) {
				mutation.target.classList.add("triggered-sync-with-uploader");
				const formElement = mutation.target.closest(".form-element");

				this.addCopyAttributeButtons(formElement);
				this.triggerSyncWithContentUploader(formElement);
			}
		}
	}
	checkForVisibleElements(entries) {
		for (const entry of entries) {
			const button = entry.target.previousElementSibling;

			if (!button?.classList.contains("copy-attribute-to-all")) continue;
			const isHidden = button.classList.contains("hidden");

			if (entry.isIntersecting && isHidden) button.classList.remove("hidden");
			else if (!entry.isIntersecting && !isHidden)
				button.classList.add("hidden");
		}
	}
	copyToReferenceField(event, config = {}) {
		event.preventDefault();

		QuillHelpers.updateEditors(this.$form);
		const formData = this.$form.serializeArray();

		if (config?.allFiles) this.reveal.foundation("close");
		else this.nextAssetForm(event);

		this.processFormData(formData, null, config?.allFiles, config?.copyPrimary);
	}
	async copyToAllReferenceFields(event) {
		const target = event.currentTarget;

		if (this.primaryAttributeKey) {
			new ConfirmationModal({
				text: await I18n.translate("frontend.upload.confirm_all_to_all_html", {
					label: target.dataset.primaryAttributeLabel,
					template: this.templateTranslationPlural,
				}),
				confirmationText: await I18n.translate("common.yes"),
				cancelText: await I18n.translate("common.no"),
				confirmationClass: "warning",
				cancelable: true,
				confirmationCallback: () =>
					this.$form.trigger("submit", { allFiles: true, copyPrimary: true }),
				cancelCallback: () => this.$form.trigger("submit", { allFiles: true }),
			});
		} else {
			this.$form.trigger("submit", { allFiles: true });
		}
	}
	async copySingleToAllReferenceFields(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		const $target = $(event.currentTarget);
		const formElement = $target.next(".form-element");
		const formElementKey = formElement.data("key");

		if (formElementKey.includes(`[${this.primaryAttributeKey}]`)) {
			new ConfirmationModal({
				text: await I18n.translate(
					"frontend.upload.confirm_single_to_all_html",
					{
						label: formElement.data("label"),
						template: this.templateTranslationPlural,
					},
				),
				confirmationText: await I18n.translate("common.yes"),
				cancelText: await I18n.translate("common.no"),
				confirmationClass: "warning",
				cancelable: true,
				confirmationCallback: () =>
					this.processSingleFormData(formElementKey, $target),
			});
		} else {
			this.processSingleFormData(formElementKey, $target);
		}
	}
	processSingleFormData(formElementKey, target) {
		target.addClass("disabled");

		QuillHelpers.updateEditors(this.$form);
		let formData = this.$form.serializeArray();
		formData = formData.filter(
			(f) => f.name.includes(formElementKey) || !f.name.includes("thing"),
		);

		this.processFormData(formData, target, true, true);
	}
	processFormData(
		formData,
		target = null,
		allFiles = false,
		copyPrimary = false,
	) {
		const requests = [];

		formData.forEach((v, i) => {
			if (v && UuidHelper.isUuid(v.value)) {
				const promise = DataCycle.httpRequest(`/api/v4/universal/${v.value}`, {
					method: "POST",
					body: { fields: "name,skos:prefLabel" },
				});

				promise.then((data) => {
					v.text =
						data?.["@graph"]?.[0] &&
						(data["@graph"][0]["skos:prefLabel"] || data["@graph"][0].name);
				});

				requests.push(promise);
			}
		});

		Promise.all(requests).then(
			(_data) =>
				this.setUploaderFormFields(formData, target, allFiles, copyPrimary),
			(_error) =>
				this.setUploaderFormFields(formData, target, allFiles, copyPrimary),
		);
	}
	setUploaderFormFields(
		formData,
		target = null,
		allFiles = false,
		copyPrimary = false,
	) {
		this.referencedAssetField.trigger("dc:upload:setFormFields", {
			formData: formData,
			allFiles: allFiles,
			primaryAttributeKey: copyPrimary ? null : this.primaryAttributeKey,
		});

		if (target) {
			target.removeClass("disabled");
			this.showNotice(target, "Attribut wurde übernommen!");
		}
	}
	showNotice(target, text) {
		const notice = $(`<span class="copy-attribute-notice">${text}</span>`);
		$(notice).appendTo(target);
		setTimeout(() => {
			notice.fadeOut("fast", () => {
				notice.remove();
			});
		}, 1000);
	}
	addCopyAttributeButtons(container) {
		const formFields = $(container)
			.find("> fieldset > .form-element, > .form-element")
			.addBack(".form-element")
			.filter(
				(_i, item) =>
					!(
						$(item).prev(".copy-attribute-to-all").length ||
						$(item)
							.parents(".form-element")
							.last()
							.prev(".copy-attribute-to-all").length
					),
			);

		const buttonHtml = `<button class="copy-attribute-to-all button-prime small" title="dieses Attribut für alle ${this.templateTranslationPlural} übernehmen"><span class="copy-icon fa-stack"><i class="fa fa-clone"></i><i class="fa fa-arrow-right fa-stack-1x"></i></span><i class="fa loading-icon fa-spinner fa-fw fa-spin"></i></button>`;

		for (const el of formFields.get()) {
			el.insertAdjacentHTML("beforebegin", buttonHtml);
			this.formFieldVisibilityObserver.observe(el);
		}

		if (this.primaryAttributeKey?.length)
			formFields
				.filter(`[data-key*="[${this.primaryAttributeKey}]"]`)
				.prev(".copy-attribute-to-all")
				.addClass("primary-attribute-button");
	}
	triggerSyncWithContentUploader(target = null) {
		let key;
		const locale = this.$form
			.find("> .available-attribute-locales .list-items > li.active a")
			.data("locale");

		if (target) key = target.dataset.key;

		this.referencedAssetField.trigger("dc:upload:syncWithForm", {
			key: key,
			locale: target ? locale : null,
		});
	}
	importAttributeValues(event, data = null) {
		event.preventDefault();

		if (!data?.attributes) return;
		if (!data?.locale) this.$form.get(0).reset();

		const groupedAttributes = this.groupAttributeValues(
			data.attributes,
			data.locale,
		);

		for (const key in groupedAttributes) {
			this.$form
				.find(`[data-key="${key}"]`)
				.find(DataCycle.config.EditorSelectors.join(", "))
				.triggerHandler("dc:import:data", {
					value:
						typeof groupedAttributes[key] === "string"
							? groupedAttributes[key].trim()
							: groupedAttributes[key],
					locale: data.locale || "de",
					force: true,
				});
		}
	}
	groupAttributeValues(values, locale = null) {
		const groupedValues = {};

		if (!values?.length) return groupedValues;

		for (const v of values) {
			if (
				locale &&
				!(v.name.includes("translations") && v.name.includes(locale))
			)
				return;

			const key = v.name.normalizeKey();

			if (groupedValues[key] || UuidHelper.isUuid(v.value)) {
				if (!Array.isArray(groupedValues[key]))
					groupedValues[key] = [groupedValues[key]].filter(Boolean);

				groupedValues[key].push(v.value);
			} else groupedValues[key] = v.value;
		}

		return groupedValues;
	}
	setReferencedAssetField() {
		const id = this.$form
			.closest(".reveal.new-content-reveal")
			.find(".file-for-upload")
			.data("id");
		const referenceField = $(
			`.content-upload-form > .file-for-upload[data-id="${id}"]`,
		);
		if (referenceField.length) this.referencedAssetField = referenceField;
	}
	createNextAssetButton() {
		this.nextAssetButton = $(
			'<a href="#" class="next-asset-button button-prime"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>',
		).insertAfter(this.reveal);
		this.nextAssetButton.on("click", this.nextAssetForm.bind(this));
	}
	createPrevAssetButton() {
		this.prevAssetButton = $(
			'<a href="#" class="prev-asset-button button-prime"><i class="fa fa-arrow-left" aria-hidden="true"></i></a>',
		).insertBefore(this.reveal);
		this.prevAssetButton.on("click", this.prevAssetForm.bind(this));
	}
	updateNavigationButtons(event) {
		if (event) event.preventDefault();

		if (this.referencedAssetField.siblings(".file-for-upload").length) {
			if (!this.nextAssetButton) this.createNextAssetButton();
			if (!this.prevAssetButton) this.createPrevAssetButton();

			this.$form.addClass("show-copy-attribute-to-all");
		} else {
			this.$form.removeClass("show-copy-attribute-to-all");
		}

		if (this.nextAssetButton && this.prevAssetButton) {
			if (!this.referencedAssetField.next(".file-for-upload.finished").length)
				this.nextAssetButton.hide();
			else this.nextAssetButton.show();

			if (!this.referencedAssetField.prev(".file-for-upload.finished").length)
				this.prevAssetButton.hide();
			else this.prevAssetButton.show();
		}
	}
	nextAssetForm(event) {
		event.preventDefault();
		this.reveal.foundation("close");
		const nextAsset = this.referencedAssetField.next(
			".file-for-upload.finished",
		);

		if (nextAsset?.length)
			$(
				`.reveal.new-content-reveal#${nextAsset
					.find(".edit-upload-button")
					.data("open")}`,
			).foundation("open");
	}
	prevAssetForm(event) {
		event.preventDefault();
		this.reveal.foundation("close");
		const prevAsset = this.referencedAssetField.prev(
			".file-for-upload.finished",
		);

		if (prevAsset?.length)
			$(
				`.reveal.new-content-reveal#${prevAsset
					.find(".edit-upload-button")
					.data("open")}`,
			).foundation("open");
	}
	updateForm() {
		this.updateCrumbs();
		this.updateWarningLevel();

		const activeFieldset = this.$form.find("fieldset.active");

		if (
			!(
				activeFieldset.hasClass("iframe") ||
				activeFieldset.hasClass("no-search-warning")
			) ||
			activeFieldset.hasClass("template")
		)
			this.$form.find(".search-warning").show();
		else this.$form.find(".search-warning").hide();

		if (
			activeFieldset.hasClass("template") ||
			activeFieldset.hasClass("no-search-warning")
		) {
			this.enableForm();
		} else if (this.$form.hasClass("disabled")) {
			this.disableForm();
		}
	}
	next(event) {
		event.preventDefault();
		const activeFieldset = this.$form.find("fieldset.active");
		if (this.$form.hasClass("validation-form")) {
			activeFieldset.trigger("dc:form:validate", {
				successCallback: () => {
					this.goTo(
						undefined,
						this.$form
							.find("fieldset")
							.index(
								this.$form.find("fieldset.active").nextAll("fieldset").first(),
							),
					);
				},
			});
		} else {
			this.goTo(
				undefined,
				this.$form
					.find("fieldset")
					.index(
						this.$form.find("fieldset.active").nextAll("fieldset").first(),
					),
			);
		}
	}
	prev(event) {
		event.preventDefault();
		this.goTo(
			undefined,
			this.$form
				.find("fieldset")
				.index(this.$form.find("fieldset.active").prevAll("fieldset").first()),
		);
	}
	goTo(event, data) {
		if (event) event.preventDefault();

		const $fromSet = this.$form.find("fieldset.active");
		const fromIndex = this.$form.find("fieldset").index($fromSet);
		const toIndex =
			data !== undefined ? data : event && $(event.target).data("index");
		const $toSet = this.$form.find(`fieldset:eq(${toIndex})`);

		if (
			$fromSet.hasClass("template") &&
			fromIndex !== toIndex &&
			this.$form.data("template") !==
				this.$form.find(':input[name="template"]').val()
		)
			this.renderContentForm();

		$fromSet.removeClass("active");
		$toSet.addClass("active").trigger("dc:remote:render");

		if ($toSet.hasClass("template") || $toSet.hasClass("iframe"))
			this.$form.closest(".reveal:not(.full)").foundation("_updatePosition");

		this.updateForm();
	}
	updateWarningLevel() {
		if (this.$form.find("fieldset.active").hasClass("template"))
			this.$form
				.find("> .search-warning")
				.removeClass("alert")
				.addClass("warning");
		else
			this.$form
				.find("> .search-warning")
				.removeClass("warning")
				.addClass("alert");
	}
	updateCrumbs() {
		this.crumbs.html(
			this.$form
				.find("fieldset.active")
				.prevAll("fieldset")
				.get()
				.reverse()
				.map((elem, i) => {
					return `<a class="form-crumb-link" data-index="${i}">${$(elem)
						.find("legend")
						.html()}</a>`;
				})
				.concat([this.$form.find("fieldset.active legend").html()])
				.join(' <i class="fa fa-angle-right" aria-hidden="true"></i> '),
		);
	}
	removeOldFormFields() {
		if (this.form.querySelector("fieldset:not(.template)"))
			for (const fieldset of this.form.querySelectorAll(
				"fieldset:not(.template)",
			))
				fieldset.remove();

		if (
			this.form.querySelector(".available-attribute-locales, .form-thumbnail")
		)
			for (const element of this.form.querySelectorAll(
				".available-attribute-locales, .form-thumbnail",
			))
				element.remove();
	}
	addLoadingSpinner() {
		this.form
			.querySelector(".buttons")
			?.insertAdjacentHTML(
				"beforebegin",
				'<fieldset class="content-fields active"><div class="form-loading"><i class="fa fa-spinner fa-spin fa-fw"></i></div></fieldset>',
			);
	}
	disableForm() {
		DataCycle.disableElement(this.form);
		this.form.classList.add("disabled");
	}
	enableForm() {
		DataCycle.enableElement(this.form);
		this.form.classList.remove("disabled");
	}
	renderContentForm() {
		this.hideSearchWarning();
		this.removeOldFormFields();
		this.addLoadingSpinner();
		this.disableForm();

		const template = this.$form.find(':input[name="template"]').val();
		const params = this.$form.data();
		params.template = template;
		params.key = this.id;

		const promise = DataCycle.httpRequest("/things/new", {
			body: ObjectUtilities.pick(params, [
				"key",
				"template",
				"locale",
				"searchParam",
				"searchRequired",
				"scope",
				"options.force_render",
				"options.prefix",
				"parent.id",
				"parent.class",
				"content.id",
				"content.class",
			]),
		})
			.then(this.renderNewFormHtml.bind(this, template))
			.catch(this.renderLoadError.bind(this));

		return promise;
	}
	hideSearchWarning() {
		this.form
			.querySelector(".search-warning")
			?.style.setProperty("display", "none");
	}
	showSearchWarning() {
		this.form.querySelector(".search-warning")?.style.removeProperty("display");
	}
	renderNewFormHtml(template, data) {
		const contentFields = this.form.querySelector("fieldset.content-fields");
		if (!contentFields) return this.renderLoadError();

		contentFields.insertAdjacentHTML("afterend", data?.html);
		this.form
			.querySelector("fieldset.content-fields ~ fieldset")
			?.classList.add("active");
		contentFields.remove();

		this.form.dataset.template = template;

		if (data?.enable) {
			this.enableForm();
			this.hideSearchWarning();
		} else {
			this.disableForm();
			this.showSearchWarning();
		}

		this.updateForm();
	}
	renderLoadError() {
		this.enableForm();

		I18n.t("frontend.load_error").then((text) =>
			CalloutHelpers.show(text, "alert"),
		);
	}
	resetForm(_) {
		this.$form.find(":input").blur();
		this.enableForm();
		this.$form.find(".button.show-duplicate-search-result").remove();
		this.$form.find(".single_error").remove();
		this.$form.find(".single_warning").remove();
		this.$form.removeData("template");
		this.goTo(
			undefined,
			this.$form.find("fieldset").index(this.$form.find("fieldset").first()),
		);
	}
	updateLocales(event) {
		this.locale = $(event.target).val();
		this.updateLocalesRecursive();
	}
	updateLocalesRecursive(container = this.$form) {
		$(container)
			.find(".object-browser")
			.each((i, elem) => {
				if ($(elem).data("locale") !== this.locale)
					$(elem).data("locale", this.locale).trigger("dc:locale:changed");
			});
		$(container)
			.find(".remote-render")
			.each((i, elem) => {
				if ($(elem).data("remote-options").locale !== undefined)
					$(elem).data("remote-options").locale = this.locale;
			});
		$(container)
			.find(".form-crumbs .locale, form.multi-step fieldset legend .locale")
			.each((i, elem) => {
				if ($(elem).text() !== this.locale) $(elem).text(`(${this.locale})`);
			});
		$(container)
			.find(':input[name="locale"]')
			.each((i, elem) => {
				if ($(elem).val() !== this.locale) $(elem).val(this.locale);
			});
		$(container)
			.find("form.multi-step")
			.each((i, elem) => {
				if ($(elem).data("locale") !== this.locale)
					$(elem).data("locale", this.locale);
			});
		$(container)
			.find(".button.show-objectbrowser, .new-content-button")
			.each((i, elem) => {
				this.updateLocalesRecursive(
					$(`#${$(elem).data("open") || $(elem).data("toggle")}`),
				);
			});
	}
}

export default NewContentDialog;

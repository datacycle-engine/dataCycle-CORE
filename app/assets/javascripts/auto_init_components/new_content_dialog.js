import ConfirmationModal from "../components/confirmation_modal";
import BusyButtons from "../helpers/busy_buttons";
import CalloutHelpers from "../helpers/callout_helpers";
import {
	getFormDataAsObject,
	parseDataAttribute,
} from "../helpers/dom_element_helpers";
import ObjectUtilities from "../helpers/object_utilities";
import ObserverHelpers from "../helpers/observer_helpers";
import PixieHelpers from "../helpers/pixie_helpers";
import QuillHelpers from "../helpers/quill_helpers";
import UuidHelper from "../helpers/uuid_helper";

class NewContentDialog {
	static selector = "form.new-content-multi-step-form";
	static className = "new-content-dialog";
	// what PixieHelpers.renderMessage marks the callout with, so re-applying replaces it
	static pixieMessageClass = "pixie-to-all-files-message";

	constructor(form) {
		this.form = form;
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
		this.systemLocales = this.$form.data("system-locales");
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
			this.$form.on(
				"dc:upload:applyPixieToAllFiles",
				this.applyPixieToAllFiles.bind(this),
			);
			this.referencedAssetField.on(
				"dc:upload:storeFormValues",
				this.storeFormValues.bind(this),
			);
			this.referencedAssetField.on(
				"dc:form:renderPixieMessage",
				this.renderPixieMessage.bind(this),
			);
			this.referencedAssetField.on(
				"dc:form:clearPixieMessage",
				this.clearPixieMessage.bind(this),
			);
			// a pixie applied from another file's form ran before this one was rendered, so what it
			// found for this file is waiting on the file rather than in the dom
			this.referencedAssetField.triggerHandler("dc:form:requestPixieMessages");
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
				// this editor did not exist when the form asked for what a pixie had said about
				// this file, so a message targeting this translation had nowhere to go and was
				// dropped; asking again renders the ones whose editor is now there
				this.referencedAssetField?.triggerHandler(
					"dc:form:requestPixieMessages",
				);
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
				confirmationHeaderText: await I18n.translate(
					"frontend.upload.confirm_all_to_all_header",
					{ template: this.templateTranslationPlural },
				),
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
	/**
	 * .disabled is this button's own busy spinner; the pixies and the other copy buttons are frozen
	 * the way they freeze it, so nothing writes into the form while it is being copied.
	 *
	 * The release belongs to this copy and is held here rather than on the instance.
	 * +setUploaderFormFields+ is where several independent flows end -- a form submit copying to
	 * every file, this form being stored before a pixie is applied -- so releasing there let
	 * whichever finished first hand the buttons back while this copy was still in flight, and left
	 * this copy's own release with nothing to free: the buttons it had frozen stayed frozen.
	 */
	processSingleFormData(formElementKey, target) {
		target.addClass("disabled");
		const releaseButtons = BusyButtons.hold(null, {
			container: this.form,
			except: [target?.[0]],
		});

		QuillHelpers.updateEditors(this.$form);
		let formData = this.$form.serializeArray();
		formData = formData.filter(
			(f) => f.name.includes(formElementKey) || !f.name.includes("thing"),
		);

		return this.processFormData(formData, target, true, true).finally(
			releaseButtons,
		);
	}
	processFormData(
		formData,
		target = null,
		allFiles = false,
		copyPrimary = false,
	) {
		const requests = [];

		formData.forEach((v, _i) => {
			if (v && UuidHelper.isUuid(v.value)) {
				const promise = DataCycle.httpRequest(`/api/v4/universal/${v.value}`, {
					method: "POST",
					body: {
						fields: "name,skos:prefLabel",
						language: this.systemLocales.join(","),
					},
				});

				promise.then((data) => {
					let value = ObjectUtilities.get(data, "@graph.0.skos:prefLabel");
					if (!value) value = ObjectUtilities.get(data, "@graph.0.name");

					if (Array.isArray(value)) {
						value = value
							.sort((a, b) => {
								return (
									this.systemLocales.indexOf(a["@language"]) -
									this.systemLocales.indexOf(b["@language"])
								);
							})
							.find((v) => v["@value"])["@value"];
					}

					v.text = value;
				});

				requests.push(promise);
			}
		});

		return Promise.all(requests).then(
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

		// An editor marks itself data-no-copy-to-all when several editors share its attribute name:
		// Zielgruppen and Veranstaltungskategorien are two of the annotationPixie's editors of
		// universal_classifications. Copying one of them would carry the other along -- a copy is
		// filtered out of the serialized form by the shared data-key and stored under it, with no
		// name to tell the two apart -- so they get no copy button. The pixie's own "apply to all
		// files" button stays and asks per image instead of copying.
		const copyable = formFields.not("[data-no-copy-to-all]");

		for (const el of copyable.get()) {
			el.insertAdjacentHTML("beforebegin", buttonHtml);
			this.formFieldVisibilityObserver.observe(el);
		}

		if (this.primaryAttributeKey?.length)
			copyable
				.filter(`[data-key*="[${this.primaryAttributeKey}]"]`)
				.prev(".copy-attribute-to-all")
				.addClass("primary-attribute-button");

		this.addPixieToAllButtons(formFields);
	}

	/**
	 * An attribute a pixie can fill gets a second button next to that pixie's wand: its suggestion
	 * is per image, so copying this file's value to the others is not what is wanted there -- every
	 * file is asked for its own. It belongs with the wand rather than in the gutter of copy buttons,
	 * and carries the copy button's icon because applying to every file is what it does.
	 */
	async addPixieToAllButtons(formFields) {
		const buttons = formFields
			.get()
			.map((item) => item.querySelector(".pixie-generate-button"))
			.filter(Boolean)
			.map((generateButton) => this.pixieToAllButton(generateButton))
			.filter(Boolean);
		if (!buttons.length) return;

		const tooltip = await I18n.translate("frontend.upload.apply_pixie_to_all", {
			template: this.templateTranslationPlural,
		});

		for (const button of buttons) button.dataset.dcTooltip = tooltip;
	}

	/**
	 * Puts one "apply to all files" button next to a pixie's wand.
	 *
	 * Buttons are added per container, and the same container comes back here whenever one of its
	 * translated editors finishes rendering, so a wand that already has its button is skipped. The
	 * check and the insertion happen in one synchronous step: the tooltip its caller awaits would
	 * otherwise let a second pass find the wand still bare and add a second button.
	 *
	 * @param generateButton [HTMLElement] the wand this button belongs to
	 * @return [HTMLElement|null] the inserted button, or null if this wand already had one
	 */
	pixieToAllButton(generateButton) {
		if (
			generateButton.nextElementSibling?.classList.contains(
				"pixie-to-all-files",
			)
		)
			return null;

		const button = document.createElement("button");

		button.type = "button";
		button.className = "pixie-generate-button pixie-to-all-files";
		button.innerHTML = `<span class="copy-icon fa-stack"><i class="fa fa-clone"></i><i class="fa fa-arrow-right fa-stack-1x"></i></span>`;
		// what the pixie needs to ask for one image, minus the image itself -- including the
		// data-pixie each wand partial declares, which is what PixieToAllFiles looks its table up by
		Object.assign(button.dataset, generateButton.dataset);

		generateButton.insertAdjacentElement("afterend", button);

		return button;
	}

	/**
	 * Shows what a pixie found for this file next to the attribute it was applied to -- the same
	 * callout the wand renders for the file it filled, so a run over every file reads the same
	 * wherever the user looks.
	 *
	 * The concept scheme is part of the target because several of the annotationPixie's editors
	 * share one data-key: Zielgruppen and Veranstaltungskategorien are both universal_classifications,
	 * and a message for one of them belongs under that one alone.
	 *
	 * @param data [Object] {target: {key, conceptSchemeId}, message, type}
	 */
	renderPixieMessage(event, data = null) {
		event.preventDefault();

		if (!data?.message) return;

		const formElement = this.pixieFormElement(data.target);
		if (!formElement) return;

		PixieHelpers.renderMessage(
			formElement,
			NewContentDialog.pixieMessageClass,
			data.message,
			data.type || "info",
		);
	}

	/**
	 * Removes the callout of one attribute, for a message that no longer holds.
	 */
	clearPixieMessage(event, data = null) {
		event.preventDefault();

		const formElement = this.pixieFormElement(data?.target);

		if (formElement)
			PixieHelpers.clearMessage(
				formElement,
				NewContentDialog.pixieMessageClass,
			);
	}

	/**
	 * The editor a pixie message belongs to, or null while it is not rendered -- a translated
	 * attribute's other locales are rendered on demand, which is what #initTranslatableField
	 * replays the remembered messages for.
	 */
	pixieFormElement(target) {
		if (!target?.key) return null;

		const scheme = target.conceptSchemeId;

		return (
			this.$form
				.find(`.form-element[data-key="${target.key}"]`)
				.filter(
					(_index, element) =>
						!scheme || element.dataset.conceptSchemeId === scheme,
				)
				.get(0) || null
		);
	}

	/**
	 * Stores what this form currently holds on its file, the way navigating away from it does. A
	 * file's fields are only written when its form is left, so anything edited in a form that is
	 * still open exists in the dom alone -- and is lost as soon as that form is re-rendered from
	 * those fields.
	 *
	 * @return [Promise] resolved once the values have reached the file
	 */
	storeFormValues(event) {
		event.preventDefault();

		QuillHelpers.updateEditors(this.$form);

		return this.processFormData(this.$form.serializeArray());
	}
	/**
	 * A pixie's "apply to all files" button sits inside this form, which is the only element it can
	 * reach from there -- the file this form belongs to is what holds the other files, and the
	 * uploader's own events are bound on that file's field.
	 */
	applyPixieToAllFiles(event, data = undefined) {
		event.preventDefault();

		return this.referencedAssetField.triggerHandler(
			"dc:upload:applyPixieToAllFiles",
			data,
		);
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
			const value =
				typeof groupedAttributes[key] === "string"
					? groupedAttributes[key].trim()
					: groupedAttributes[key];

			// Every editor of that attribute, because triggerHandler fires on the first matched
			// element only: the annotationPixie renders one editor per concept scheme into the
			// shared universal_classifications, so its second tree would never be filled. An editor
			// keeps the ids of its own tree and drops the rest -- a simple select has no option for
			// them, and an async one looks them up scoped by its tree_label.
			for (const editor of this.$form
				.find(`[data-key="${key}"]`)
				.find(DataCycle.config.EditorSelectors.join(", "))
				.get())
				$(editor).triggerHandler("dc:import:data", {
					value,
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

		const activeFieldset = this.$form.find("fieldset.active");

		if (activeFieldset.hasClass("template")) {
			this.enableForm();
		} else if (this.$form.hasClass("disabled")) {
			this.disableForm();
		}
	}
	goToNext() {
		this.goTo(
			undefined,
			this.$form
				.find("fieldset")
				.index(
					this.$form
						.find("fieldset.active")
						.nextAll("fieldset:not(.disabled)")
						.first(),
				),
		);
	}
	next(event) {
		event.preventDefault();

		const activeFieldset = this.$form.find("fieldset.active");
		if (this.$form.hasClass("validation-form")) {
			activeFieldset.trigger("dc:form:validate", {
				successCallback: () => this.goToNext(),
			});
		} else this.goToNext();
	}
	prev(event) {
		event.preventDefault();

		this.goTo(
			undefined,
			this.$form
				.find("fieldset")
				.index(
					this.$form
						.find("fieldset.active")
						.prevAll("fieldset:not(.disabled)")
						.first(),
				),
		);
	}
	goTo(event, data) {
		if (event) event.preventDefault();

		const currentTarget = event ? event.currentTarget : null;
		const $fromSet = this.$form.find("fieldset.active");
		const fromIndex = this.$form.find("fieldset").index($fromSet);
		let toIndex = data;
		if (data === undefined && currentTarget)
			toIndex = parseDataAttribute(currentTarget.dataset.index);
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
		this.reloadOnGoto($toSet.get(0));

		if ($toSet.hasClass("template"))
			this.$form.closest(".reveal:not(.full)").foundation("_updatePosition");

		this.updateForm();
	}
	reloadOnGoto(target) {
		const reloadOnGoto = target.querySelectorAll(
			'[data-reload-on-goto="true"]',
		);
		if (reloadOnGoto.length === 0) return;

		const formData = getFormDataAsObject(this.form);

		for (const elem of reloadOnGoto) {
			const remoteOptions = parseDataAttribute(elem.dataset.remoteOptions);
			elem.dataset.remoteOptions = JSON.stringify(
				Object.assign({}, remoteOptions, { datahash: formData }),
			);

			elem.classList.add("remote-reload");
			$(elem).trigger("dc:remote:reload");
		}
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
		} else {
			this.disableForm();
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

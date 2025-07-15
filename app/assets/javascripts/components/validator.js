import isEmpty from "lodash/isEmpty";
import isEqual from "lodash/isEqual";
import collectionReject from "lodash/reject";
import unionWith from "lodash/unionWith";
import uniqWith from "lodash/uniqWith";
import DomElementHelpers from "../helpers/dom_element_helpers";
import QuillHelpers from "./../helpers/quill_helpers";
import ConfirmationModal from "./confirmation_modal";

class Validator {
	constructor(formElement) {
		this.form = formElement;
		this.$form = $(this.form);
		this.duplicateSearch = !!DomElementHelpers.parseDataAttribute(
			this.form.dataset.duplicateSearch,
		);
		this.primaryAttributeKey = this.form.dataset.primaryAttributeKey;
		this.$editHeader = this.$form
			.siblings(".edit-header")
			.add(this.$form.find(".edit-header"))
			.first();
		this.duplicateId = this.form.dataset.duplicateId;
		this.thingId = this.form.querySelector('input[name="uuid"]')?.value;
		this.$submitButton = this.$editHeader.find(".submit-edit-form").first();
		this.$saveButton = this.$editHeader.find(".save-content-button").first();
		this.$languageMenu = this.$editHeader.find("#locales-menu").first();
		this.$agbsCheck = this.$editHeader.find(".form-element.agbs").first();
		this.$contentUploader = this.$form.data("content-uploader");
		this.bulkEdit = this.$form.hasClass("bulk-edit-form");
		this.contentTemplate = this.$form
			.find('input[type="hidden"]#content_template')
			.val();
		this.initialFormData = [];
		this.submitFormData = [];
		this.requests = [];
		this.queryCount = 0;
		this.valid = true;
		this.eventHandlers = {
			beforeunload: this.pageLeaveHandler.bind(this),
		};
		this.changeObserver = new MutationObserver(
			this._checkForChangedFormData.bind(this),
		);
		this.changeObserverConfig = {
			subtree: true,
			attributes: true,
			attributeFilter: ["class"],
			characterData: false,
			childList: false,
			attributeOldValue: true,
			characterDataOldValue: false,
		};
		this.updateQueue = [];

		this.addEventHandlers();
	}
	addEventHandlers() {
		this.$form.on(
			"change dc:form:validatefield",
			".validation-container",
			this.validateSingle.bind(this),
		);
		this.$form.on("dc:form:validate", "*", this.validateForm.bind(this));
		this.$form.on(
			"remove-submit-button-errors",
			".validation-container",
			(event) => this.removeSubmitButtonErrors($(event.currentTarget)),
		);
		this.$submitButton.on("click", this.clickSubmitButton.bind(this));
		this.$saveButton.on("click", this.clickSaveButton.bind(this));
		this.$form.on("submit dc:form:validateForm", this.validateForm.bind(this));
		if (this.$form.hasClass("edit-content-form")) {
			this.pageLeaveWarning();
		}
		this.$form.on("click", ".close-error", this.closeError.bind(this));
		this.$form.on("click", ".close-warning", this.closeWarning.bind(this));
		this.$agbsCheck.on("click", ".close-error", this.closeError.bind(this));
		this.$agbsCheck.on("change", this.validateSingle.bind(this));
		this.$form.on("dc:form:disable", this.disable.bind(this));
		this.$form.on("dc:form:enable", this.enable.bind(this));

		this.changeObserver.observe(this.$form[0], this.changeObserverConfig);
	}
	clickSubmitButton(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		this.$form.trigger("submit", {
			saveAndClose: true,
			mergeConfirm: this.$submitButton.hasClass("merge-with-duplicate"),
		});
	}
	clickSaveButton(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		this.$form.trigger("submit");
	}
	closeError(event) {
		event.preventDefault();

		$(event.target).closest(".single_error").remove();
	}
	closeWarning(event) {
		event.preventDefault();

		$(event.target).closest(".single_warning").remove();
	}
	validateSingle(event, data) {
		if (data && data.type === "reset") return;

		this.requests = [this.validateItem(event.currentTarget)];
		this.resolveRequests(false, data);
	}
	sortedFormData(formData = undefined) {
		return collectionReject(
			uniqWith(
				formData || Array.from(DomElementHelpers.getFormData(this.$form[0])),
				isEqual,
			).sort(),
			(v) => v[0] && ["authenticity_token", "locale"].includes(v[0]),
		);
	}
	updateSubmitFormData() {
		QuillHelpers.updateEditors(this.$form);
		this.submitFormData = this.sortedFormData();
	}
	formDataChanged() {
		return (
			this.initialFormData.length > 0 &&
			!isEqual(this.initialFormData, this.submitFormData)
		);
	}
	pageLeaveHandler(event) {
		this.updateSubmitFormData();

		if (this.formDataChanged()) {
			event.preventDefault();
			event.returnValue = "";
			return event.returnValue;
		}
	}
	pageLeaveWarning() {
		QuillHelpers.updateEditors(this.$form);
		this.initialFormData = this.sortedFormData();

		$(window).on("beforeunload", this.eventHandlers.beforeunload);

		if (this.$languageMenu.length) {
			this.$languageMenu.on("click", ".list-items > li > a", async (event) => {
				this.updateSubmitFormData();
				if (this.formDataChanged()) {
					event.preventDefault();

					new ConfirmationModal({
						text: await I18n.translate(
							"frontend.validate.save_and_change_language",
						),
						confirmationClass: "success",
						cancelable: true,
						confirmationCallback: () => {
							this.$form.append(
								`<input type="hidden" name="new_locale" value="${$(
									event.target,
								).data("locale")}">`,
							);
							this.$form.trigger("submit");
						},
					});
				}
			});
		}
	}
	_checkForChangedFormData(mutations) {
		for (const mutation of mutations) {
			if (
				mutation.type === "attributes" &&
				mutation.target.classList.contains("remote-rendered") &&
				(!mutation.oldValue || mutation.oldValue.includes("remote-rendering"))
			) {
				if (!this.updateQueue.length)
					requestAnimationFrame(this.updateInitialFormData.bind(this));

				this.updateQueue.push(mutation.target);
			}
		}
	}
	updateInitialFormData() {
		this.initialFormData = collectionReject(
			unionWith(
				this.initialFormData,
				Array.from(DomElementHelpers.getFormData(this.updateQueue)),
				isEqual,
			).sort(),
			(v) => v[0] && ["authenticity_token"].includes(v[0]),
		);

		this.updateQueue.length = 0;
	}
	async validateAgbs(validationContainer) {
		const error = {
			valid: true,
			errors: {},
			warnings: {},
		};
		const agbs = $(validationContainer).find(':checkbox[name="accept_agbs"]');
		if (agbs.length && !agbs.prop("checked")) {
			const errorMessage = await I18n.translate("frontend.validate.agbs");
			$(validationContainer)
				.append(
					await this.renderErrorMessage(
						{ errors: { agbs: [errorMessage] } },
						validationContainer,
					),
				)
				.addClass("has-error");
			error.valid = false;
			error.errors.agbs = [errorMessage];
			error.element = $(validationContainer)[0];
		} else {
			this.removeSubmitButtonErrors(validationContainer);
		}
		return Promise.resolve(error);
	}
	async validateDuplicateItem() {
		const url = `/things/${this.thingId}/validate_duplicate/${this.duplicateId}`;
		const validation = (await DataCycle.httpRequest(url)) || { valid: true };
		validation.element = this.form;
		if (validation.warnings && Object.keys(validation.warnings).length) {
			validation.label = await I18n.translate("duplicate.merge_content");

			this.$submitButton.addClass("warning");
		}

		return Promise.resolve(validation);
	}
	disable() {
		DataCycle.disableElement(this.$submitButton);
		DataCycle.disableElement(this.$saveButton);
		DataCycle.disableElement(this.$form);
	}
	enable() {
		if (this.queryCount === 0 && !this.$form.hasClass("disabled")) {
			DataCycle.enableElement(this.$submitButton);
			DataCycle.enableElement(this.$saveButton);
			DataCycle.enableElement(this.$form);
			this.$form.find("input#duplicate_id").remove();
		}
	}
	tooltipError(key, type = "error") {
		return $(
			`<span class="tooltip-${type}" data-attribute-key="${key}"></span>`,
		);
	}
	singleError(key, type = "error") {
		return $(
			`<span class="single_${type}" data-attribute-key="${key}"><i class="fa fa-times close-${type}" aria-hidden="true"></i></span></span>`,
		);
	}
	async renderErrorMessage(data, element, type = "error", itemClass = "alert") {
		const $itemLabel = $(element).find("label");
		const labelFor = $itemLabel.attr("for");
		const labelText = $(element).data("label");
		const completeKey = $(element).data("key");
		const $activeTooltipHtml = $(
			`<div>${this.$submitButton.attr("data-dc-tooltip")}</div>`,
		);
		const $tooltipError = this.tooltipError(completeKey, type);
		const $singleError = this.singleError(completeKey, type);

		for (let [key, message] of Object.entries(data[`${type}s`] || {})) {
			if (
				!(
					completeKey?.match(new RegExp(key, "i")) ||
					labelFor?.match(new RegExp(key, "i"))
				)
			)
				continue;

			if (Array.isArray(message)) message = message.join("<br>");

			$tooltipError.append(
				`<b>${
					labelText || (await I18n.translate(`frontend.validate.${type}`))
				}</b><br>${message}<br>`,
			);
			$singleError.append(
				`<b>${
					labelText || (await I18n.translate(`frontend.validate.${type}`))
				}</b> ${message}<br>`,
			);
		}

		if (!$singleError.text().length) return $();

		if (this.$form.hasClass("edit-content-form")) {
			this.$submitButton.addClass(itemClass);

			$activeTooltipHtml
				.find(`.tooltip-${type}[data-attribute-key="${completeKey}"]`)
				.remove();
			$activeTooltipHtml.append($tooltipError);
			this.$submitButton.attr("data-dc-tooltip", $activeTooltipHtml.html());
		}

		return $singleError;
	}
	locale() {
		return (
			this.$form.find(':input[name="locale"]').val() ||
			this.$form.find(':input[name="thing[locale]"]').val()
		);
	}
	removeSubmitButtonErrors(item, type = "error", itemClass = "alert") {
		const $activeTooltipHtml = $(
			`<div>${this.$submitButton.attr("data-dc-tooltip")}</div>`,
		);

		if (item) {
			const translationLocale = this.attributeLocale(item);
			$activeTooltipHtml
				.find(`[data-attribute-key="${$(item).data("key")}"]`)
				.remove();
			if (!$activeTooltipHtml.find(`.tooltip-${type}`).length)
				this.$submitButton.removeClass(itemClass);

			if (
				translationLocale &&
				!$activeTooltipHtml.find(
					`.tooltip-${type}[data-attribute-key*="[translations][${translationLocale}]"]`,
				).length
			)
				this.$form.trigger("dc:form:removeValidationError", {
					locale: translationLocale,
					type: type,
				});
		} else {
			this.$form.trigger("dc:form:removeValidationError", { type: type });
			this.$submitButton.removeClass(itemClass);
			$activeTooltipHtml.find(`.tooltip-${type}`).remove();
		}

		this.$submitButton.attr("data-dc-tooltip", $activeTooltipHtml.html());
	}
	resetField(validationContainer) {
		$(validationContainer).children(".single_error").remove();
		$(validationContainer).removeClass("has-error");
		$(validationContainer).children(".single_warning").remove();
		$(validationContainer).removeClass("has-warning");

		this.removeSubmitButtonErrors(validationContainer, "error", "alert");
		this.removeSubmitButtonErrors(validationContainer, "warning", "warning");
	}
	attributeLocale(validationContainer) {
		const key = $(validationContainer).data("key");

		if (!key) return;

		return (
			key.includes("[translations]") &&
			key.match(/\[translations\]\[([-a-zA-Z]+)\]/)[1]
		);
	}
	formFieldChanged(fieldData, translationLocale, submitFormDataUpToDate) {
		if (
			!translationLocale ||
			translationLocale === this.locale() ||
			this.bulkEdit
		)
			return true;

		const newFieldData = this.sortedFormData(fieldData || []);
		const key = newFieldData[0]?.[0];
		let oldFieldData = [];
		if (key)
			oldFieldData = this.initialFormData.filter((v) => v[0].includes(key));

		if (!submitFormDataUpToDate) this.updateSubmitFormData();

		return (
			!isEqual(oldFieldData, newFieldData) ||
			this.submitFormData
				.filter((v) => v[0].includes(`[${translationLocale}]`))
				.some((v) => !isEmpty(v[1]))
		);
	}
	addParentEmbeddedTemplates(formData, element) {
		const parentEmbeddeds = DomElementHelpers.findAncestors(element, (elem) =>
			elem.classList.contains("content-object-item"),
		);

		for (const parent of parentEmbeddeds) {
			const embeddedTemplate = parent.querySelector(".embedded-template");
			if (embeddedTemplate)
				formData.set(embeddedTemplate.name, embeddedTemplate.value);
		}
	}
	async validateItem(element, submitFormDataUpToDate = false) {
		this.resetField(element);

		if ($(element).hasClass("agbs")) return this.validateAgbs(element);

		const formData = DomElementHelpers.getFormData(element);

		if (!Array.from(formData).length)
			return Promise.resolve({ valid: true, element: element });

		const tLocale = this.attributeLocale(element);

		if (
			!this.formFieldChanged(
				Array.from(formData),
				tLocale,
				submitFormDataUpToDate,
			)
		)
			return Promise.resolve({ valid: true, element: element });

		const locale = tLocale || this.locale();
		const table = this.$form.find(':input[name="table"]').val() || "things";
		const url = `/${table}${this.thingId ? `/${this.thingId}` : ""}/validate`;
		const template = this.$form.find(':input[name="template"]').val();

		if (template) formData.set("template", template);
		if (locale) formData.set("locale", locale);
		if (this.contentTemplate)
			formData.set("content_template", this.contentTemplate);

		this.addParentEmbeddedTemplates(formData, element);

		const dSearch = this.duplicateSearchAllowed(formData);

		if (dSearch) formData.set("duplicate_search", this.primaryAttributeKey);

		const result = await DataCycle.httpRequest(url, {
			method: "POST",
			body: formData,
		});

		return this.transformValidationResult(result, element, locale, dSearch);
	}
	async transformValidationResult(result, element, locale, dSearch) {
		let data = result;
		if (!data) data = { valid: true };
		data.element = element;

		if (!data.valid && data.errors && Object.keys(data.errors).length)
			await this.showMessage(data, element, locale);

		if (dSearch) this.cleanDuplicateSearch();

		if (data.warnings && Object.keys(data.warnings).length) {
			if (dSearch && data.duplicate_search)
				await this.renderDuplicateSearchWarning(data);

			await this.showMessage(data, element, locale, "warning", "warning");
		}

		return data;
	}
	duplicateSearchAllowed(formData) {
		if (!this.duplicateSearch || !this.primaryAttributeKey) return false;

		return Array.from(formData.keys()).some(
			(v) => v.attributeNameFromKey() === this.primaryAttributeKey,
		);
	}
	cleanDuplicateSearch() {
		const submitButton = this.form.querySelector('[type="submit"]');

		submitButton?.removeAttribute("data-confirm");
		submitButton?.removeAttribute("data-dup-confirm");

		this.form.querySelector("a.button.show-duplicate-search-result")?.remove();
	}
	addSearchParamValue(searchParams, key, value) {
		if (Array.isArray(value)) {
			for (const v of value) searchParams.push([`${key}[]`, v]);
		} else searchParams.push([key, value]);
	}
	searchParamsFromFilterParams(filterParams) {
		const searchParams = [];

		if (filterParams) {
			for (const params of filterParams) {
				const identifier = params.identifier;

				for (const [key, value] of Object.entries(params)) {
					if (key === "identifier") continue;

					this.addSearchParamValue(
						searchParams,
						`f[${identifier}][${key}]`,
						value,
					);
				}
			}
		}

		return searchParams;
	}
	async renderDuplicateSearchWarning(data) {
		const searchParams = this.searchParamsFromFilterParams(
			data.duplicate_search?.filter_params,
		);

		const buttonHtml = `<a class="button show-duplicate-search-result hollow warning" target="_blank" data-search-params='${JSON.stringify(
			searchParams,
		)}'><i class="fa fa-clone" aria-hidden="true"></i>${await I18n.t("duplicate_search.show")}</a>`;

		const prev = this.form.querySelector(":scope > div.buttons > button.prev");
		if (prev) prev.insertAdjacentHTML("afterend", buttonHtml);
		else
			this.form
				.querySelector(":scope > div.buttons")
				?.insertAdjacentHTML("afterbegin", buttonHtml);

		this.form
			.querySelector("a.show-duplicate-search-result")
			.addEventListener(
				"click",
				this.clickShowDuplicateSearchResult.bind(this),
			);
	}
	clickShowDuplicateSearchResult(event) {
		event.preventDefault();
		event.stopPropagation();

		const formData = DomElementHelpers.parseDataAttribute(
			event.currentTarget.dataset.searchParams,
		);
		DomElementHelpers.submitFormData("/", "POST", formData, "_blank");
	}
	async showMessage(data, element, locale, type = "error", bClass = "alert") {
		this.$form.trigger("dc:form:validationError", {
			locale: locale,
			type: type,
		});
		$(element)
			.append(await this.renderErrorMessage(data, element, type, bClass))
			.addClass(`has-${type}`);
	}
	validateForm(event, data) {
		if (event.detail?.dcFormSubmitted) return;
		event.preventDefault();
		event.stopImmediatePropagation();
		this.updateSubmitFormData();
		this.removeSubmitButtonErrors();
		this.disable();
		this.requests = [];

		if (data?.mergeConfirm) this.requests.push(this.validateDuplicateItem());

		$(event.target)
			.find(".validation-container:not(.disabled)")
			.add(this.$agbsCheck)
			.each((_i, elem) => {
				this.requests.push(this.validateItem(elem, true));
			});

		this.resolveRequests($(event.target).is(this.$form), data);
	}
	async confirmWarnings(confirmations) {
		const messages = [];
		for (const warning of confirmations.warnings) {
			const label = warning.label || warning.element.dataset.label;
			const tooltip = Object.values(warning.warnings).join(", ");
			messages.push(`<b data-dc-tooltip='${tooltip}'>${label}</b>`);
		}

		return new ConfirmationModal({
			text: await I18n.translate("frontend.validate.ignore_warnings", {
				data: messages,
			}),
			confirmationClass: "warning",
			cancelable: true,
			confirmationCallback: () => {
				confirmations.warnings = undefined;
				this.submitForm(confirmations);
			},
			cancelCallback: () => this.enable(),
		});
	}
	async confirmFinalize(confirmations, checked) {
		let text;
		if (checked) text = await I18n.translate("frontend.validate.final_save");
		else {
			const finalizeText = this.$form.find('label[for="finalize"]').text();
			text = await I18n.translate("frontend.validate.final_save_warning", {
				text: finalizeText,
			});
		}

		return new ConfirmationModal({
			text: text,
			confirmationClass: checked ? "success" : "warning",
			cancelable: true,
			confirmationCallback: () => {
				confirmations.finalize = false;
				this.submitForm(confirmations);
			},
			cancelCallback: () => this.enable(),
		});
	}
	async confirmCustomCofirmation(confirmations, text) {
		return new ConfirmationModal({
			text: text,
			confirmationClass: "alert",
			cancelable: true,
			confirmationCallback: () => {
				confirmations.confirm = false;
				this.submitForm(confirmations);
			},
			cancelCallback: () => this.enable(),
		});
	}
	async submitForm(
		confirmations = {
			finalize: true,
			confirm: true,
			warnings: undefined,
			mergeConfirm: false,
			saveAndClose: false,
		},
	) {
		if (confirmations.warnings) return this.confirmWarnings(confirmations);

		if (confirmations.finalize) {
			const checkbox = this.$form.find(':input[name="finalize"]')[0];
			if (checkbox)
				return this.confirmFinalize(confirmations, checkbox.checked);
		}

		if (confirmations.confirm) {
			const confirmationText = this.$submitButton.data("confirm");
			if (confirmationText)
				return this.confirmCustomCofirmation(confirmations, confirmationText);
		}

		this.triggerFormSubmit(confirmations);
	}
	triggerFormSubmit(confirmations = {}) {
		if (
			this.$form.closest(".reveal").hasClass("in-object-browser") ||
			this.$contentUploader
		) {
			return this.$form.trigger("dc:form:submitWithoutRedirect", confirmations);
		}

		$(window).off("beforeunload", this.eventHandlers.beforeunload);
		if (confirmations?.saveAndClose)
			this.$form.append(
				'<input type="hidden" name="save_and_close" value="1">',
			);

		if (confirmations?.mergeConfirm)
			this.$form.append(
				`<input id="duplicate_id" type="hidden" name="duplicate_id" value="${this.$form.data(
					"duplicate-id",
				)}">`,
			);

		if (this.$form.data("remote"))
			Rails.fire(this.$form[0], "submit", { dcFormSubmitted: true });
		else this.$form[0].submit();
	}
	resolveRequests(submit = false, eventData = {}) {
		let submitForm = submit;
		let data = eventData;

		if (Object.hasOwn(data, "submit")) submitForm = data.submit;

		this.queryCount++;
		const requests = this.requests.slice();
		this.requests = [];

		Promise.all(requests).then(
			(values) => {
				this.queryCount--;
				this.valid = values.filter(Boolean).every((v) => v.valid);
				const error = values.filter(Boolean).find((v) => !v.valid)?.element;

				if (this.valid && submitForm) {
					this.queryCount = 0;
					data = Object.assign({}, data || {}, {
						finalize: true,
						confirm: true,
					});

					const warnings = values
						.filter(Boolean)
						.filter((v) => (v.warnings ? Object.keys(v.warnings).length : 0));
					if (warnings.length) Object.assign(data, { warnings: warnings });

					this.submitForm(data);
				} else if (!this.valid && submitForm) {
					if (this.$form.hasClass("edit-content-form") && error) {
						error.scrollIntoView({ behavior: "smooth", block: "center" });
					}
				}
				if (!(this.valid && submitForm)) this.enable();
				if (
					this.valid &&
					data !== undefined &&
					data.successCallback !== undefined
				) {
					data.successCallback();
				}
				if (
					!this.valid &&
					data !== undefined &&
					data.errorCallback !== undefined
				) {
					data.errorCallback();
				}
				// scroll to step in multi-step form
				if (
					!this.valid &&
					this.$form.hasClass("multi-step") &&
					DomElementHelpers.isHidden(error)
				) {
					this.$form.trigger(
						"dc:multistep:goto",
						this.$form.find("fieldset").index(error.closest("fieldset")),
					);
				}
			},
			async (error) => {
				this.queryCount--;

				const buttonText = `<span id="button_server_error" class="tooltip-error"><strong>${await I18n.translate(
					"frontend.validate.error",
				)}</strong><br>${error.statusText}<br></span>`;
				this.enable();
				this.$submitButton.addClass("alert");
				$(`#${this.$submitButton.data("toggle")}`).append(buttonText);
			},
		);
	}
}

export default Validator;

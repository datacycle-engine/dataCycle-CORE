import CalloutHelpers from "./../helpers/callout_helpers";
import DomElementHelpers from "../helpers/dom_element_helpers";
import ConfirmationModal from "./confirmation_modal";
import isEqual from "lodash/isEqual";
import uniqWith from "lodash/uniqWith";

class SplitView {
	constructor(container = document) {
		this.container = container;
		this.leftContainer = this.container.closest(
			".split-content.detail-content",
		);
		this.rightContainer = this.container
			.closest(".flex-box")
			.querySelector(".split-content.edit-content");
		this.embedLocale = this.leftContainer.dataset.embedLocale;
		this.leftLocaleSwitcher = this.leftContainer.getElementsByClassName(
			"attribute-locale-switcher",
		)[0];
		this.leftAvailableLocales = DomElementHelpers.parseDataAttribute(
			this.leftContainer.dataset.availableLocales,
		);
		this.enableTranslateButtons = DomElementHelpers.parseDataAttribute(
			this.leftContainer.dataset.enableTranslateButtons,
		);
		this.copyAllButton;
		this.translateAllButton;
		this.leftId = this.leftContainer.dataset.id;
		this.translatableTypes = ["string", "text_editor"];
		this.allButtonParentSelector =
			'[data-editor="included-object"], .split-content.detail-content, .attribute-group.viewer.has-title > .attribute-group-item';
		this.copyableTypes = [
			"object_browser",
			"embedded_object",
			"string",
			"text_editor",
			"classification",
			"date_picker",
			"geographic",
			"boolean",
			"number",
			"duration",
			"url",
		];
		this.buttonMappings = {
			translate: {
				icon: "fa-language",
				class: "dc-translatable-field",
			},
			copy: {
				icon: "fa-arrow-right",
				class: "dc-copyable-field",
			},
		};
		this.addButtonRequests = [];

		this.setup();
	}
	setup() {
		this.observeForNewFields();
		this.setupButtons(this.container);
	}
	leftLocale() {
		const selectedLocaleItem = this.leftLocaleSwitcher?.querySelector(
			".list-items .active .available-attribute-locale",
		);

		return (
			selectedLocaleItem?.dataset.locale || this.leftContainer.dataset.locale
		);
	}
	transformKeyToTargetLocale(key, locale) {
		if (!key) return;

		return key.replace(
			/\[translations\]\[[^\]]*\]/,
			`[translations][${locale}]`,
		);
	}
	rightLocale() {
		return this.container.closest("form").querySelector('input[name="locale"]')
			.value;
	}
	addSubcriberNoticeHandler() {
		const notice = this.container
			.closest(".split-content")
			.querySelector(".close-subscribe-notice");

		if (notice)
			notice.addEventListener("click", this.dismissSubscribeNotice.bind(this));
	}
	addSingleClickHandler() {
		DataCycle.htmlObserver.addCallbacks.push([
			"a.copy, a.translate",
			(e) => {
				e.addEventListener("click", this.handleButtonClick.bind(this));
			},
		]);
	}
	addAllClickHandler() {
		DataCycle.htmlObserver.addCallbacks.push([
			"a.copy-all, a.translate-all",
			this.addAllClickEventHandler.bind(this),
		]);
	}
	addAllClickEventHandler(e) {
		e.addEventListener("click", this.triggerAllButtons.bind(this));
		const parent = e.closest(this.allButtonParentSelector);

		if (
			parent.classList.contains("split-content") &&
			e.classList.contains("copy-all")
		)
			this.copyAllButton = e;
		if (
			parent.classList.contains("split-content") &&
			e.classList.contains("translate-all")
		)
			this.translateAllButton = e;
	}
	observeForNewFields() {
		DataCycle.htmlObserver.addCallbacks.push([
			"[data-editor]:not(.dc-copyable-field)",
			this.checkNewShowButtons.bind(this),
		]);
		DataCycle.htmlObserver.addCallbacks.push([
			".form-element[data-key]",
			this.checkNewEditButtons.bind(this),
		]);

		this.addSingleClickHandler();
		this.addAllClickHandler();
		this.addSubcriberNoticeHandler();
	}
	checkNewShowButtons(element) {
		if (element.closest(".detail-type.embedded:not(:scope)")) return;

		this.setupButtons(element);
	}
	checkNewEditButtons(element) {
		if (element.closest(".form-element.embedded:not(:scope)")) return;

		this.addButtonsForEditFields(element);
	}
	setupButtons(container) {
		const availableEditors = this.availableEditors(
			container,
			this.copyableTypes,
		);

		for (let i = 0; i < availableEditors.length; ++i) {
			this.addButtons(availableEditors[i]);
		}

		const availableLinkedEditors = this.availableEditors(container, [
			"object_browser",
		]);
		for (let i = 0; i < availableLinkedEditors.length; ++i) {
			this.addButtons(availableLinkedEditors[i], true);
		}
	}
	addButtonsForEditFields(element) {
		const targetKey = this.transformKeyToTargetLocale(
			element.dataset.key,
			this.leftLocale(),
		);
		const viewFields = this.findFieldsByKey(targetKey, this.leftContainer);

		for (let i = 0; i < viewFields.length; ++i) {
			this.setupButtons(viewFields[i]);
		}
	}
	findFieldsByKey(
		key,
		container,
		visibleOnly = true,
		rejectCopyableFields = true,
	) {
		if (!key?.length) return [];

		let selectorString = `[data-key="${key}"]:not([data-editor]:not([data-editor="included-object"]) [data-key="${key}"])`;
		if (rejectCopyableFields) selectorString += ":not(.dc-copyable-field)";

		const fields = Array.from(container.querySelectorAll(selectorString));

		if (visibleOnly)
			return fields.filter(DomElementHelpers.isVisible.bind(this));
		else return fields;
	}
	findRemoteRenderFieldByKey(key, container) {
		return container.querySelector(
			`.translatable-attribute.remote-render[data-remote-render-params*="${key}"]`,
		);
	}
	dismissSubscribeNotice(_event) {
		document.cookie = "subscribe_notice_dismissed=true;SameSite=Lax";
	}
	availableEditors(container, selectors = []) {
		const newSelectorString = selectors
			.map(
				(x) =>
					`:scope div[data-editor=${x}]:not(div[data-editor]:not([data-editor="included-object"]) div[data-editor])`,
			)
			.join(", ");

		const results = [...container.querySelectorAll(newSelectorString)];

		if (
			container.dataset.editor &&
			selectors.includes(container.dataset.editor)
		)
			results.push(container);

		return results;
	}
	addButtons(element, single = false) {
		const targetKey = this.transformKeyToTargetLocale(
			element.dataset.key,
			this.rightLocale(),
		);
		const editField = this.findFieldsByKey(targetKey, this.rightContainer)[0];

		if (
			!editField ||
			editField.matches(':disabled, .disabled, [data-readonly="true"]')
		)
			return;

		this.addElementClasses(element);

		if (single && !element.classList.contains("copy-single")) {
			const singleElements = element.getElementsByClassName("copy-single");
			for (let i = 0; i < singleElements.length; i++) {
				this.renderButton(singleElements[i], single);
			}
		} else this.renderButton(element, single);
	}
	async addAllButton(element, type) {
		let container = element.closest(this.allButtonParentSelector);

		if (container.classList.contains(`show-${type}-all-button`)) return;

		if (!container.querySelector(":scope > .buttons"))
			container.insertAdjacentHTML("afterbegin", '<div class="buttons"></div>');
		const buttonsContainer = container.querySelector(":scope > .buttons");

		container.classList.add(`show-${type}-all-button`);

		await buttonsContainer.insertAdjacentHTML(
			"afterbegin",
			`<a class="button-prime small ${type}-all" data-disable-with="<i class=\'fa fa-spinner fa-fw fa-spin\'></i>" data-dc-tooltip="${await I18n.translate(
				`frontend.split_view.${type}_all`,
			)}"><i class="fa ${
				this.buttonMappings[type].icon
			}" aria-hidden="true"></i></a>`,
		);
	}
	async addElementClasses(element) {
		if (this.isTranslatable(element)) {
			await this.addAllButton(element, "translate");
			element.classList.add(this.buttonMappings["translate"].class);
		}

		await this.addAllButton(element, "copy");
		element.classList.add(this.buttonMappings["copy"].class);
	}
	isTranslatable(element) {
		return (
			this.enableTranslateButtons &&
			(this.translatableTypes.includes(element.dataset.editor) ||
				(element.dataset.editor === "embedded_object" &&
					element.dataset.translatable))
		);
	}
	async renderButton(element, single) {
		let buttonContainer = element.querySelector(":scope > .buttons");

		if (!buttonContainer)
			buttonContainer = element.querySelector(
				":scope > .content-link > .buttons",
			);
		if (!buttonContainer) {
			element.insertAdjacentHTML("beforeend", '<div class="buttons"></div');
			buttonContainer = element.querySelector(":scope > .buttons");
		}

		if (this.isTranslatable(element))
			await this.addSpecificButton(buttonContainer, single, "translate");

		await this.addSpecificButton(buttonContainer, single, "copy");
	}
	async addSpecificButton(buttonContainer, single, type) {
		buttonContainer.insertAdjacentHTML(
			"beforeend",
			`<a class="button-prime small ${type} ${
				single ? `${type}-single-button` : ""
			}" data-disable-with="<i class=\'fa fa-spinner fa-fw fa-spin\'></i>" data-dc-tooltip="${await I18n.translate(
				`frontend.split_view.${type}`,
			)}"><i class="fa ${
				this.buttonMappings[type].icon
			} aria-hidden="true"></i></a>`,
		);
	}
	loadValue(keys) {
		return DataCycle.httpRequest(`/things/${this.leftId}/attribute_value`, {
			method: "POST",
			body: {
				locale: this.leftLocale(),
				keys: keys,
			},
		});
	}
	async handleButtonClick(event) {
		event.preventDefault();

		const button = event.currentTarget;

		DataCycle.disableElement(button);

		const container = button.closest("[data-editor]");
		const linkedOrEmbedded = button.closest(
			".embedded[data-id], li.item[data-id]",
		);
		const key = container.dataset.key;
		let value;

		if (linkedOrEmbedded) {
			if (linkedOrEmbedded)
				value = DomElementHelpers.parseDataAttribute(
					linkedOrEmbedded.dataset.id,
				);
		} else {
			const response = await this.loadValue([key]);
			if (response?.hasOwnProperty(key)) value = response[key];
		}

		if (!value && value !== false) return DataCycle.enableElement(button);

		const targetKey = this.transformKeyToTargetLocale(key, this.rightLocale());
		let promise;

		if (button.classList.contains("translate"))
			promise = this.translateText(
				container.dataset.editor,
				value,
				targetKey,
				key,
			);
		else promise = this.copyContents(value, targetKey, false, true, key);

		await promise.catch((_e) => {
			DataCycle.enableElement(button);
		});

		DataCycle.enableElement(button);
	}
	async triggerAllButtons(event) {
		event.preventDefault();

		const target = event.currentTarget;

		const parent = target.closest(this.allButtonParentSelector);

		await this.loadAllVisibleAttributes();

		if (
			target.classList.contains("copy-all") &&
			DomElementHelpers.parseDataAttribute(parent.dataset.copyAllTranslations)
		)
			await this.showCopyAllConditionOverlay(target, parent);
		else await this.triggerSingleButtons(target, parent);
	}
	async loadAllVisibleAttributes() {
		for (const item of Array.from(
			this.rightContainer.querySelectorAll(".remote-render"),
		).filter((elem) => DomElementHelpers.isVisible(elem))) {
			await $(item).triggerHandler("dc:remote:forceRenderTranslations");
		}

		for (const item of Array.from(
			this.leftContainer.querySelectorAll(".remote-render"),
		).filter((elem) => DomElementHelpers.isVisible(elem))) {
			await $(item).triggerHandler("dc:remote:forceRenderTranslations");
		}
	}
	async showCopyAllConditionOverlay(target, parent) {
		new ConfirmationModal({
			text: await I18n.translate(
				"frontend.split_view.copy_all_translations.overlay_text",
			),
			confirmationText: await I18n.translate(
				"frontend.split_view.copy_all_translations.confirmation_text",
			),
			cancelText: await I18n.translate(
				"frontend.split_view.copy_all_translations.cancel_text",
			),
			confirmationClass: "success",
			preventCancelOnAbort: true,
			cancelable: true,
			confirmationCallback: () => {
				this.copyAllTranslations();
			},
			cancelCallback: () => {
				this.triggerSingleButtons(target, parent);
			},
		});
	}
	async copyAllTranslations() {
		DataCycle.disableElement(this.copyAllButton);

		const availableEditors = this.availableEditors(
			this.leftContainer,
			this.copyableTypes,
		);
		const keys = this.keysForTranslationsFromEditors(availableEditors);

		if (!keys.length) return;

		const values = await this.loadValue(keys);

		for (let i = 0; i < keys.length; ++i) {
			if (!values[keys[i]]) continue;

			const renderRemoteField = this.findRemoteRenderFieldByKey(
				keys[i],
				this.rightContainer,
			);
			const sourceRemoteField = this.findRemoteRenderFieldByKey(
				keys[i],
				this.leftContainer,
			);

			if (renderRemoteField)
				await $(renderRemoteField).triggerHandler(
					"dc:remote:forceRenderTranslations",
				);
			if (sourceRemoteField)
				await $(sourceRemoteField).triggerHandler(
					"dc:remote:forceRenderTranslations",
				);

			this.copyContents(values[keys[i]], keys[i], false, false, keys[i]);
		}

		DataCycle.enableElement(this.copyAllButton);
	}
	keysForTranslationsFromEditors(availableEditors) {
		const keys = [];

		for (let i = 0; i < availableEditors.length; ++i) {
			const item = availableEditors[i];
			const key = item.dataset.key;

			if (!item.classList.contains("dc-copyable-field")) continue;

			if (key.includes("[translations]")) {
				for (let j = 0; j < this.leftAvailableLocales.length; ++j) {
					keys.push(
						this.transformKeyToTargetLocale(key, this.leftAvailableLocales[j]),
					);
				}
			} else keys.push(key);
		}

		return uniqWith(keys, isEqual);
	}
	async triggerSingleButtons(target, parent) {
		let items;
		let buttonToDisable;
		const triggeredRequests = [];

		if (target.classList.contains("translate-all")) {
			buttonToDisable = this.translateAllButton;
			items = [
				...parent.querySelectorAll(
					":scope .dc-translatable-field > .buttons > a.translate",
				),
				...parent.querySelectorAll(
					":scope .dc-copyable-field:not(.dc-translatable-field) > .buttons > a.copy:not(.copy-single-button)",
				),
			];
		} else {
			buttonToDisable = this.copyAllButton;
			items = parent.querySelectorAll(
				":scope .dc-copyable-field > .buttons > a.copy:not(.copy-single-button)",
			);
		}

		DataCycle.disableElement(buttonToDisable);

		for (const item of items) {
			if (DomElementHelpers.isHidden(item)) continue;

			triggeredRequests.push(item.dispatchEvent(new Event("click")));
		}

		await Promise.all(triggeredRequests);

		DataCycle.enableElement(buttonToDisable);
	}
	async copyContents(
		value,
		key,
		translate = false,
		visibleOnly = true,
		sourceKey = null,
	) {
		const submitButton = document.querySelector(
			".edit-header .submit-edit-form",
		);

		if (submitButton?.disabled) return;

		const target = this.findFieldsByKey(
			key,
			this.rightContainer,
			visibleOnly,
		)[0];
		const sourceElement = this.findFieldsByKey(
			sourceKey,
			this.leftContainer,
			false,
			false,
		)[0];
		let sourceId;

		if (sourceElement) {
			sourceId = DomElementHelpers.randomId("focus-field");
			sourceElement.dataset.focusId = sourceId;
		}

		await $(target)
			.find(DataCycle.config.EditorSelectors.join(", "))
			.triggerHandler("dc:import:data", {
				value: typeof value === "string" ? value.trim() : value,
				locale: this.embedLocale ? this.leftLocale() : "",
				translate: translate,
				sourceId: sourceId,
			});
	}
	async translateText(editor, value, key, sourceKey) {
		if (this.translatableTypes.includes(editor)) {
			let formData = {
				text: typeof value === "string" ? value.trim() : value,
				source_locale: this.leftLocale(),
				target_locale: this.rightLocale(),
			};

			const translatedValue = await DataCycle.httpRequest(
				"/things/translate_text",
				{
					method: "POST",
					body: formData,
				},
			).catch(async (error) => {
				const sourceElement = this.findFieldsByKey(
					sourceKey,
					this.leftContainer,
					false,
					false,
				)[0];
				let errorMessage = await I18n.translate(
					"frontend.split_view.translate_error",
					{
						label: sourceElement.dataset.label,
					},
				);
				if (error?.responseJSON?.error)
					errorMessage += `<br><i>${error.responseJSON.error}</i>`;
				CalloutHelpers.show(errorMessage, "alert");
			});

			await this.copyContents(
				translatedValue.text,
				key,
				false,
				true,
				sourceKey,
			);
		} else {
			await this.copyContents(value, key, true, true, sourceKey);
		}
	}
}

export default SplitView;

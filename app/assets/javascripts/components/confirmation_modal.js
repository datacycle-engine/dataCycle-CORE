import domElementHelpers from "../helpers/dom_element_helpers";

class ConfirmationModal {
	constructor(config = {}) {
		this.confirmationCallback = config.confirmationCallback;
		this.cancelCallback = config.cancelCallback;
		this.preventCancelOnAbort = config.preventCancelOnAbort;
		this.confirmationClass = config.confirmationClass || "";
		this.cancelable = config.cancelable;
		this.text = config.text || "";
		this.confirmationHeaderText = config.confirmationHeaderText || "";
		this.confirmationText = config.confirmationText || "";
		this.cancelText = config.cancelText || "";
		this.confirmationIndex = 1;
		this.overlay;
		this.closed = false;
		this.section;
		this.domParser = new DOMParser();

		this.show();
	}
	async show() {
		const sectionId = domElementHelpers.randomId();
		const sectionHtml = await this.renderSectionHtml(sectionId);

		window.requestAnimationFrame(() => {
			const modal = document.querySelector(".confirmation-modal");

			if (modal) {
				this.overlay = modal;
				this.overlay.insertAdjacentHTML("beforeend", sectionHtml);
				this.section = document.getElementById(sectionId);

				this.confirmationIndex = this.overlay.getElementsByClassName(
					"confirmation-section",
				).length;

				const confirmationCount = this.overlay.querySelector(
					".confirmation-info .confirmation-count",
				);

				if (confirmationCount)
					confirmationCount.textContent = this.confirmationIndex;
				else
					this.overlay.insertAdjacentHTML(
						"beforeend",
						`<div class="confirmation-info"><span class="confirmation-index">1</span> / <span class="confirmation-count">${this.confirmationIndex}</span></div>`,
					);
			} else {
				document.body.insertAdjacentHTML("beforeend", this.renderWrapperHtml());
				this.overlay = document.querySelector(".confirmation-modal");
				this.overlay.insertAdjacentHTML("beforeend", sectionHtml);
				this.section = document.getElementById(sectionId);
			}

			this.addEvents();
		});
	}
	renderWrapperHtml() {
		return '<div class="reveal confirmation-modal" data-multiple-opened="true" data-reveal data-initial-state="open"><button class="close-button" data-close aria-label="Close modal" type="button"><span aria-hidden="true">&times;</span></button></div>';
	}
	revealHeader() {
		if (!this.confirmationHeaderText) return "";

		return `<div class="reveal-header">${this.confirmationHeaderText}</div>`;
	}
	async cancelButton() {
		if (!this.cancelable) return "";

		let cancelText =
			this.cancelText || (await I18n.translate("actions.cancel"));
		const cancelTextDom = this.domParser.parseFromString(
			cancelText,
			"text/html",
		);
		if (!cancelTextDom.querySelector(".fa"))
			cancelText = `<i class="fa fa-times"></i>${cancelText}`;

		return `<a class="confirmation-cancel button hollow" aria-label="Cancel">${cancelText}</a>`;
	}
	async confirmationButton() {
		let confirmationText = `<a class="confirmation-confirm button ${this.confirmationClass}" aria-label="Confirm">${this.confirmationText || (await I18n.translate("frontend.ok"))}`;
		const confirmTextDom = this.domParser.parseFromString(
			confirmationText,
			"text/html",
		);
		if (!confirmTextDom.querySelector(".fa"))
			confirmationText = `${confirmationText}<i class="fa fa-check"></i></a>`;

		return confirmationText;
	}
	async renderSectionHtml(sectionId) {
		const revealHeader = this.revealHeader();
		const cancelButton = await this.cancelButton();
		const confirmationButton = await this.confirmationButton();

		return `<section id="${sectionId}" class="confirmation-section">${revealHeader}<div class="confirmation-text reveal-body">${this.text}</div><div class="reveal-footer confirmation-buttons">${cancelButton}${confirmationButton}</div></section>`;
	}
	updateConfirmationIndex(_event) {
		this.overlay.querySelector(".confirmation-index").textContent =
			this.confirmationIndex;
	}
	addEvents() {
		const confirmButton = this.section.querySelector(".confirmation-confirm");
		if (confirmButton)
			confirmButton.addEventListener("click", this.confirm.bind(this));

		const cancelButton = this.section.querySelector(".confirmation-cancel");
		if (cancelButton)
			cancelButton.addEventListener("click", this.cancel.bind(this));

		$(this.overlay).on("closed.zf.reveal", (_event) => {
			if (!(this.closed || this.preventCancelOnAbort)) {
				this.close("cancelCallback", true, true);
			}
		});

		$(this.section).on(
			"dc:confirmation_count:update",
			this.updateConfirmationIndex.bind(this),
		);
		$(this.section).on(
			{
				mouseenter: this.focusSpecificFields.bind(this),
				mouseleave: this.focusSpecificFields.bind(this),
			},
			".focus-specific-field",
		);
	}
	cancel(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		this.close("cancelCallback");
	}
	confirm(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		this.close("confirmationCallback");
	}
	close(method_name, closeAll = false, force = false) {
		if (
			(domElementHelpers.isVisible(this.overlay) || force) &&
			(closeAll ||
				this.overlay.querySelectorAll(":scope > section.confirmation-section")
					.length === 1)
		) {
			this.closed = true;
			if (typeof $(this.overlay).foundation === "function")
				$(this.overlay).foundation("close");
			this.overlay.parentElement.remove();
		} else if (domElementHelpers.isVisible(this.overlay) || force) {
			this.section.remove();
			$(this.overlay.querySelector("section.confirmation-section")).trigger(
				"dc:confirmation_count:update",
			);
		}

		if (typeof this[method_name] === "function") {
			this[method_name]();
		}
	}
	focusSpecificFields(event) {
		const fieldId = event.currentTarget.dataset.fieldId;
		if (!fieldId) return;

		const elements = document.querySelectorAll(`[data-focus-id="${fieldId}"]`);
		const elementMethod =
			event.type === "mouseenter"
				? this._showSpecificField
				: this._hideSpecificField;
		const overlayRect = this.overlay.getBoundingClientRect();
		const fieldOffset = overlayRect.top + overlayRect.height + 20;

		for (let i = 0; i < elements.length; ++i) {
			elementMethod.call(
				this,
				elements[i],
				fieldOffset,
				elements.length > 1,
				i,
			);
		}
	}
	_showAncestors(ancestors) {
		for (let i = 0; i < ancestors.length; ++i) {
			const field = ancestors[i];
			if (domElementHelpers.isVisible(field)) continue;

			if (field.style.display)
				field.dataset.oldDisplayValue = field.style.display;
			field.classList.add("dc-focus-show-ancestor");
			field.style.display = "block";
		}
	}
	_hideAncestors(ancestors) {
		for (let i = 0; i < ancestors.length; ++i) {
			const field = ancestors[i];
			if (
				!(
					domElementHelpers.isVisible(field) &&
					field.classList.contains("dc-focus-show-ancestor")
				)
			)
				continue;

			field.classList.remove("dc-focus-show-ancestor");
			if (field.dataset.oldDisplayValue)
				field.style.display = field.dataset.oldDisplayValue;
			else if (field.style.display) field.style.removeProperty("display");
		}
	}
	_showSpecificField(field, fieldOffset, multiple = true, order = 0) {
		if (field.style.top) field.dataset.oldTopValue = field.style.top;
		if (field.style.opacity)
			field.dataset.oldOpacityValue = field.style.opacity;
		if (field.style.left) field.dataset.oldLeftValue = field.style.left;

		field.style.opacity = 0;

		window.requestAnimationFrame(() => {
			const ancestors = domElementHelpers.findAncestors(
				field,
				domElementHelpers.isHidden,
			);
			this._showAncestors(ancestors.reverse());

			field.classList.add("dc-focus-field");
			field.style.top = `${fieldOffset}px`;
			const fieldRect = field.getBoundingClientRect();
			this.addPlaceholder(field, fieldRect.height);

			if (!multiple) field.style.left = `calc(50% - ${fieldRect.width}px / 2)`;
			else field.style.left = order === 0 ? "1.5rem" : "calc(50% + 1.5rem)";
		});

		window.requestAnimationFrame(() => {
			field.style.opacity = 1;
		});
	}
	_hideSpecificField(field, _fieldOffset, _multiple = true, _order = 0) {
		if (!field.classList.contains("dc-focus-field")) return;

		field.style.opacity = 0;

		setTimeout(() => {
			const ancestors = domElementHelpers.findAncestors(field, (e) =>
				e.classList.contains("dc-focus-show-ancestor"),
			);
			this._hideAncestors(ancestors);
			field.style.removeProperty("opacity");
			field.style.removeProperty("top");
			field.style.removeProperty("left");
			field.classList.remove("dc-focus-field");
			this.removePlaceholder(field);

			if (field.style.oldTopValue) field.style.top = field.dataset.oldTopValue;
			if (field.style.oldOpacityValue)
				field.style.opacity = field.dataset.oldOpacityValue;
			if (field.style.oldLeftValue)
				field.style.left = field.dataset.oldLeftValue;
		}, 100);
	}
	addPlaceholder(field, height) {
		const previous = field.previousElementSibling;
		if (previous?.classList?.contains("dc-focus-field-placeholder")) return;

		const style = window.getComputedStyle(field);

		field.insertAdjacentHTML(
			"beforebegin",
			`<div class="dc-focus-field-placeholder" style="height: ${height}px; margin: ${style.margin};"></div>`,
		);
	}
	removePlaceholder(field) {
		const placeholder = field.previousElementSibling;
		if (placeholder?.classList?.contains("dc-focus-field-placeholder"))
			placeholder.remove();

		if (
			field.previousElementSibling?.classList?.contains(
				"dc-focus-field-placeholder",
			)
		)
			this.removePlaceholder(field);
	}
}

export default ConfirmationModal;

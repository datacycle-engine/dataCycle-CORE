import ObserverHelpers from "../helpers/observer_helpers";

class OverlayTypeCheckbox {
	constructor(element) {
		this.element = element;
		this.element.classList.add("dcjs-overlay-type-checkbox");
		this.inputs = Array.from(
			this.element.querySelectorAll('input[type="checkbox"]'),
		);
		this.formElement = this.getFormElement(this.element);
		this.overlayElements = {};

		this.setup();
	}
	setup() {
		if (!this.formElement) return console.warn("no form-element found!");

		for (const input of this.inputs) this.initInput(input);
	}
	initInput(input) {
		const field = document.querySelector(
			`.form-element[data-key="${input.dataset.overlayAttributeKey}"]`,
		);

		if (field) {
			this.overlayElements[input.value] = field;
			this.initInputEvents(input);
			return;
		}

		const translatableAttribute = document.querySelector(
			`.translatable-attribute.remote-render[data-remote-render-params*="${input.dataset.overlayAttributeKey}"], .translatable-attribute.remote-rendering[data-remote-render-params*="${input.dataset.overlayAttributeKey}"]`,
		);

		if (translatableAttribute)
			this.observeForRemoteRenderedField(translatableAttribute, input);
	}
	observeForRemoteRenderedField(field, input) {
		const changeObserver = new MutationObserver(
			this.checkForChangedClass.bind(this, input),
		);

		changeObserver.observe(field, ObserverHelpers.changedClassConfig);
	}
	checkForChangedClass(input, mutations, observer) {
		if (
			mutations.some(
				(m) =>
					m.type === "attributes" &&
					m.target.classList.contains("remote-rendered") &&
					(!m.oldValue || m.oldValue.includes("remote-rendering")),
			)
		) {
			observer.disconnect();
			this.initInput(input);
		}
	}
	initInputEvents(input) {
		input.disabled = false;
		input.checked =
			this.overlayElements[input.value].classList.contains(
				"dc-overlay-visible",
			);
		input.addEventListener("click", this.deselectSiblings.bind(this));
		input.addEventListener("change", this.changeActiveElement.bind(this));
	}
	getFormElement(element) {
		if (!element) return;

		if (element.classList.contains("form-element")) return element;

		return this.getFormElement(element.nextElementSibling);
	}
	deselectSibling(input) {
		if (!input.checked) return;

		input.checked = false;
		const changeEvent = new Event("change");
		input.dispatchEvent(changeEvent);
	}
	deselectSiblings(event) {
		const element = event.currentTarget;

		for (const input of this.inputs.filter((i) => i.id !== element.id))
			this.deselectSibling(input);
	}
	changeActiveElement(event) {
		const item = event.currentTarget;

		if (!item.checked) this.resetField(this.overlayElements[item.value]);

		this.overlayElements[item.value].classList.toggle(
			"dc-overlay-visible",
			item.checked,
		);
	}
	overlayElement(key) {
		return document.querySelector(`.form-element[data-ley="${key}"]`);
	}
	resetField(formField) {
		const target = formField.querySelector(
			DataCycle.config.EditorSelectors.map((v) => `:scope ${v}`).join(", "),
		);

		const resetEvent = new CustomEvent("clear");
		if (target) target.dispatchEvent(resetEvent);
	}
}

export default OverlayTypeCheckbox;

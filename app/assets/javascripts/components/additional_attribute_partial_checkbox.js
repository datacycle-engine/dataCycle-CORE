import DomElementHelpers from "../helpers/dom_element_helpers";
import ObserverHelpers from "../helpers/observer_helpers";

class AdditionalAttributePartialCheckbox {
	constructor(element) {
		this.element = element;
		this.element.classList.add("dcjs-additional-attribute-partial-checkbox");
		this.context = this.element.dataset.context;
		this.updateOnChange = DomElementHelpers.parseDataAttribute(
			this.element.dataset.updateOnChange,
		);
		this.inputs = Array.from(
			this.element.querySelectorAll('input[type="checkbox"]'),
		);
		this.formElement = this.element.closest(".form-element");
		this.formElements = {};

		this.setup();
	}
	setup() {
		if (!this.formElement) return console.warn("no form-element found!");

		for (const input of this.inputs) this.initInput(input);

		if (this.updateOnChange) this.initUpdateOnChange();
	}
	initUpdateOnChange() {
		$(this.formElement).on("change", this.checkForValuePresence.bind(this));
	}
	checkForValuePresence(_event) {
		const formData = DomElementHelpers.getFormData(this.formElement);

		if (
			Array.from(formData).some(
				(data) => !data[0]?.startsWith(this.context) && data[1]?.length,
			)
		)
			this.enableDefaultInput();
		else this.disableAllInputs();
	}
	initInput(input) {
		const field =
			document.querySelector(
				`.form-element[data-key="${input.dataset.forAttributeKey}"]`,
			) ||
			document.querySelector(
				`.translatable-attribute.remote-render[data-remote-render-params*="${input.dataset.forAttributeKey}"], .translatable-attribute.remote-rendering[data-remote-render-params*="${input.dataset.forAttributeKey}"]`,
			);

		if (field?.classList?.contains("translatable-attribute")) {
			this.observeForRemoteRenderedField(field, input);
		} else if (field) {
			this.formElements[input.value] = field;
			this.initInputEvents(input);
			this.updateActiveState(field);
		} else {
			this.initInputEvents(input, false);
		}
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
	suppressEventPropagation(event) {
		event.preventDefault();
		event.stopImmediatePropagation();
	}
	initInputEvents(input, hasFormElement = true) {
		input.disabled = false;
		input.addEventListener("click", this.deselectSiblings.bind(this));

		if (hasFormElement) {
			input.checked = this.formElements[input.value].classList.contains(
				`dc-${this.context}-visible`,
			);
			input.addEventListener("change", this.updateActiveElement.bind(this));
		}
		// only allow this.updateActiveElement, before suppressing the event propagation
		input.addEventListener("change", this.suppressEventPropagation.bind(this));
	}
	getFormElement(element) {
		if (!element) return;
		if (element.classList.contains("form-element")) return element;

		return this.getFormElement(element.nextElementSibling);
	}
	changeInputState(element, state) {
		element.checked = state;
		const changeEvent = new Event("change");
		this.setFormElementClass(element.value, state);
		element.dispatchEvent(changeEvent);
	}
	setFormElementClass(type, state) {
		this.formElement.classList.toggle(
			`dcjs-additional-attribute-partial-${type}`,
			state,
		);
	}
	deselectSibling(input) {
		if (!input.checked) return;

		this.changeInputState(input, false);
	}
	deselectSiblings(event) {
		const element = event.currentTarget;
		this.setFormElementClass(element.value, element.checked);

		for (const input of this.inputs.filter((i) => i.id !== element.id))
			this.deselectSibling(input);
	}
	updateActiveState(formField, scrollTo = false) {
		if (formField.classList.contains(`dc-${this.context}-visible`)) {
			this.enableFormField(formField);
			if (scrollTo)
				formField.scrollIntoView({ behavior: "smooth", block: "nearest" });
		} else {
			this.disableFormField(formField);
		}
	}
	updateActiveElement(event) {
		const item = event.currentTarget;
		const formField = this.formElements[item.value];

		formField.classList.toggle(`dc-${this.context}-visible`, item.checked);

		this.updateActiveState(formField, true);
	}
	enableFormField(formField) {
		formField
			.querySelector(".additional-attribute-partial-disabled-dummy")
			?.remove();
		DomElementHelpers.enableElement(formField);
	}
	disableFormField(formField) {
		DomElementHelpers.disableElement(formField);
		let key = formField.dataset.key;
		if (DomElementHelpers.isListFormElement(formField)) key += "[]";
		formField.insertAdjacentHTML(
			"beforeend",
			`<input type="hidden" class="additional-attribute-partial-disabled-dummy" name="${key}" value="">`,
		);
	}
	enableDefaultInput() {
		if (this.inputs.filter((e) => e.checked).length === 0) {
			this.changeInputState(this.inputs[0], true);
		}
	}
	disableAllInputs() {
		for (const elem of this.inputs.filter((e) => e.checked))
			this.changeInputState(elem, false);
	}
}

export default AdditionalAttributePartialCheckbox;

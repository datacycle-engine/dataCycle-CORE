import DomElementHelpers from "../helpers/dom_element_helpers";

class DisableUnlessValue {
	constructor(element) {
		this.element = element;
		this.element.classList.add("dcjs-disable-unless-value");
		this.disabled = false;
		this.dependentOnAttributes = DomElementHelpers.parseDataAttribute(
			this.element.dataset.disableUnlessValue,
		);
		this.dependentOn = document.querySelectorAll(
			Object.keys(this.dependentOnAttributes)
				.map((v) => `.form-element[data-key$="[${v}]"]`)
				.join(", "),
		);

		this.setup();
	}
	setup() {
		this.addEventListeners();
		this.checkStatus();
	}
	addEventListeners() {
		for (const elem of this.dependentOn) {
			$(elem).on("change", this.checkStatus.bind(this));
		}
	}
	checkStatus() {
		const prevState = this.disabled;
		this.disabled = this.getStatus();

		if (prevState === this.disabled) return;

		this.updateStatus();
	}
	updateStatus() {
		if (this.disabled) this.disable();
		else this.enable();

		$(this.element).trigger("change");
	}
	disable() {
		const firstKey = Array.from(
			DomElementHelpers.getFormData(this.element).keys(),
		)[0];
		DomElementHelpers.disableElement(this.element);
		this.element.insertAdjacentHTML(
			"afterbegin",
			`<input type="hidden" name="${firstKey}" class="disable-and-clear-dummy">`,
		);
	}
	enable() {
		DomElementHelpers.enableElement(this.element);
		this.element
			.querySelector('input[type="hidden"].disable-and-clear-dummy')
			?.remove();
	}
	hasValue(element, expectedValue) {
		if (element.classList.contains("radio_button"))
			return this.hashCheckboxValue(element, expectedValue);
		else return false;
	}
	hashCheckboxValue(element, expectedValue) {
		const selected = element.querySelector('input[type="radio"]:checked');

		if (!selected) return false;

		if (typeof expectedValue === "string" && expectedValue.isUuid())
			return selected.value === expectedValue;
		else if (typeof expectedValue === "string")
			return selected.nextElementSibling.textContent.trim() === expectedValue;
		else return false;
	}
	getStatus() {
		let disabled = true;

		for (const element of this.dependentOn) {
			const key = element.dataset.key.attributeNameFromKey();

			if (this.hasValue(element, this.dependentOnAttributes[key]))
				disabled = false;
		}

		return disabled;
	}
}

export default DisableUnlessValue;

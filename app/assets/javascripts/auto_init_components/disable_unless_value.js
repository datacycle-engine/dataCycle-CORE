import DomElementHelpers from "../helpers/dom_element_helpers";

class DisableUnlessValue {
	static selector = "[data-disable-unless-value]";
	static className = "disable-unless-value";

	constructor(element) {
		this.element = element;
		this.disabled = false;
		this.dependentOnAttributes = DomElementHelpers.parseDataAttribute(
			this.element.dataset.disableUnlessValue,
		);
		this.insertClearDummy = this.element.dataset.insertClearDummy !== "false";
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
		this.disabled = this.isDisabled();

		if (prevState === this.disabled) return;

		this.updateStatus();
	}
	updateStatus() {
		if (this.disabled) this.disable();
		else this.enable();

		$(this.element).trigger("change", { type: "disable-unless-value" });
	}
	disable() {
		DomElementHelpers.disableElement(this.element);

		if (!this.insertClearDummy) return;

		const firstKey = Array.from(
			DomElementHelpers.getFormData(this.element).keys(),
		)[0];
		this.element.insertAdjacentHTML(
			"afterbegin",
			`<input type="hidden" name="${firstKey}" class="disable-and-clear-dummy">`,
		);
	}
	enable() {
		DomElementHelpers.enableElement(this.element);

		if (!this.insertClearDummy) return;

		this.element
			.querySelector('input[type="hidden"].disable-and-clear-dummy')
			?.remove();
	}
	hasValue(element, expectedValue) {
		if (element.classList.contains("radio_button"))
			return this.hasCheckboxValue(element, expectedValue);
		else return false;
	}
	hasCheckboxValue(element, expectedValue) {
		const selected = element.querySelector('input[type="radio"]:checked');

		if (!selected) return false;

		if (Array.isArray(expectedValue)) {
			return expectedValue.some((val) =>
				this.compareCheckboxValue(selected, val),
			);
		} else return this.compareCheckboxValue(selected, expectedValue);
	}
	compareCheckboxValue(selected, expectedValue) {
		if (typeof expectedValue === "string" && expectedValue.isUuid())
			return selected.value === expectedValue;
		else if (typeof expectedValue === "string")
			return selected.nextElementSibling.textContent.trim() === expectedValue;
		else return false;
	}
	isDisabled() {
		// all conditions have to be met
		return !Array.from(this.dependentOn).every((element) => {
			const key = element.dataset.key.attributeNameFromKey();

			return this.hasValue(element, this.dependentOnAttributes[key]);
		});
	}
}

export default DisableUnlessValue;

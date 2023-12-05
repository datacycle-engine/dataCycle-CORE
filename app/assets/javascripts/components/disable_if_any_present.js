import DomElementHelpers from "../helpers/dom_element_helpers";

class DisableIfAnyPresent {
	constructor(element) {
		this.element = element;
		this.element.classList.add("dcjs-disable-if-any-present");
		this.disabled = false;
		this.dependentOnAttributes = DomElementHelpers.parseDataAttribute(
			this.element.dataset.disableIfAnyPresent,
		);
		this.dependentOn = document.querySelectorAll(
			this.dependentOnAttributes
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
	getStatus() {
		const value = Array.from(DomElementHelpers.getFormData(this.dependentOn));

		return value.some((v) => v[1]);
	}
}

export default DisableIfAnyPresent;

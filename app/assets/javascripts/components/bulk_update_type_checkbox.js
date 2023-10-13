import DomElementHelpers from "../helpers/dom_element_helpers";

class BulkUpdateTypeCheckbox {
	constructor(element) {
		this.element = element;
		this.element.classList.add("dcjs-bulk-update-type-checkbox");
		this.inputs = Array.from(
			this.element.querySelectorAll('input[type="checkbox"]'),
		);
		this.formElement = this.getFormElement(this.element);
		this.formFieldVisibilityObserver = new IntersectionObserver(
			this.checkForVisibleElements.bind(this),
		);

		this.setup();
	}
	setup() {
		if (!this.formElement) return console.warn("no form-element found!");

		this.formFieldVisibilityObserver.observe(this.formElement);

		for (const input of this.inputs) {
			input.addEventListener("click", this.deselectSiblings.bind(this));
			input.addEventListener("change", this.changeActiveClass.bind(this));
		}

		$(this.formElement).on("change", this.checkBulkUpdateType.bind(this));
	}
	getFormElement(element) {
		if (!element) return;

		if (element.classList.contains("form-element")) return element;

		return this.getFormElement(element.nextElementSibling);
	}
	checkBulkUpdateType(_event) {
		const formData = DomElementHelpers.getFormData(this.formElement);

		if (Array.from(formData).some((data) => data[1]?.length))
			this.enableDefaultType();
		else this.disableAllTypes();
	}
	enableDefaultType() {
		if (this.inputs.filter((e) => e.checked).length === 0) {
			const newElem = this.element.querySelector(
				'input[type="checkbox"][value="override"]',
			);

			if (newElem) this.changeInputState(newElem, true);
		}
	}
	disableAllTypes() {
		for (const elem of this.inputs.filter((e) => e.checked))
			this.changeInputState(elem, false);
	}
	changeInputState(element, state) {
		element.checked = state;
		const changeEvent = new Event("change");
		element.dispatchEvent(changeEvent);
	}
	deselectSiblings(event) {
		const element = event.currentTarget;

		for (const input of this.inputs.filter((i) => i.id !== element.id))
			this.changeInputState(input, false);
	}
	changeActiveClass(event) {
		this.formElement.classList.remove(
			"bulk-edit-add",
			"bulk-edit-remove",
			"bulk-edit-override",
		);

		if (event.currentTarget.checked) {
			this.formElement.classList.add(`bulk-edit-${event.currentTarget.value}`);
		}
	}
	checkForVisibleElements(entries) {
		for (const entry of entries) {
			const isHidden = this.element.classList.contains("hidden");

			if (entry.isIntersecting && isHidden)
				this.element.classList.remove("hidden");
			else if (!entry.isIntersecting && !isHidden)
				this.element.classList.add("hidden");
		}
	}
}

export default BulkUpdateTypeCheckbox;

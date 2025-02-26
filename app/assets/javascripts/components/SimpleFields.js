import domElementHelpers from "../helpers/dom_element_helpers";

class SimpleFields {
	constructor() {
		this.container = document;

		this.setup();
	}
	setup() {
		this.watchForNewField(
			"string",
			'.form-element.string:not(.text_editor) > input[type="text"]',
		);
		this.watchForNewField(
			"number",
			'.form-element.number > input[type="number"]',
		);
		this.watchForNewField(
			"checkbox",
			'.form-element.boolean input[type="checkbox"]',
		);
	}
	watchForNewField(type, selector) {
		DataCycle.registerAddCallback(selector, "dc-import-data", (e) => {
			$(e).on("dc:import:data", this[`${type}EventHandler`].bind(this));

			e.addEventListener("clear", this[`${type}ClearHandler`].bind(this));
		});
	}
	stringEventHandler(event, data) {
		const target = event.currentTarget;

		if ($(target).val().length === 0 || data?.force) {
			$(target).val(data.value).trigger("input");
		} else {
			domElementHelpers.renderImportConfirmationModal(
				target,
				data.sourceId,
				() => {
					$(target).val(data.value).trigger("input");
				},
			);
		}
	}
	stringClearHandler(event) {
		const element = event.currentTarget;

		element.value = "";
		const inputEvent = new Event("input");
		element.dispatchEvent(inputEvent);
	}
	async numberEventHandler(event, data) {
		const target = event.currentTarget;

		if ($(target).val().length === 0 || data?.force) {
			$(target).val(data.value).trigger("input");
		} else {
			domElementHelpers.renderImportConfirmationModal(
				target,
				data.sourceId,
				() => {
					$(target).val(data.value).trigger("input");
				},
			);
		}
	}
	numberClearHandler(event) {
		return stringClearHandler(event);
	}
	async checkboxEventHandler(event, data) {
		const target = event.currentTarget;

		if (data?.force) {
			$(target).prop("checked", data.value.toString() === target.value);
		} else {
			domElementHelpers.renderImportConfirmationModal(
				target,
				data.sourceId,
				() => {
					$(target).prop("checked", data.value.toString() === target.value);
				},
			);
		}
	}
	checkboxClearHandler(event) {
		const element = event.currentTarget;

		element.checked = false;
	}
}

export default SimpleFields;

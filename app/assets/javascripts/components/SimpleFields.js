import domElementHelpers from "../helpers/dom_element_helpers";

class SimpleFields {
	constructor() {
		this.container = document;

		this.setup();
	}
	setup() {
		this.watchForNewField(
			"string",
			'.form-element.string:not(.text_editor) > input[type="text"]:not(.dc-import-data)',
		);
		this.watchForNewField(
			"number",
			'.form-element.number > input[type="number"]:not(.dc-import-data)',
		);
		this.watchForNewField(
			"checkbox",
			'.form-element.boolean input[type="checkbox"]:not(.dc-import-data)',
		);
	}
	watchForNewField(type, selector) {
		DataCycle.initNewElements(selector, (e) =>
			$(e)
				.on("dc:import:data", this[`${type}EventHandler`].bind(this))
				.addClass("dc-import-data"),
		);
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
}

export default SimpleFields;

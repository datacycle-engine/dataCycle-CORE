import domElementHelpers from "../helpers/dom_element_helpers";

class CheckBoxSelector {
	constructor(element) {
		this.$element = $(element);
		this.$inputFields = this.$element.find("> li > :checkbox");
	}
	init() {
		this.initEventHandlers();
	}
	initEventHandlers() {
		this.$element
			.closest(".form-element")
			.on("dc:field:setToNull", this.setToNull.bind(this));
		this.$element
			.on("dc:import:data", this.import.bind(this))
			.addClass("dc-import-data");
	}
	setToNull(_event) {
		this.$inputFields.each((_, item) => {
			$(item).prop("checked", false);
			if (item.previousElementSibling?.matches('input[type="hidden"]'))
				item.previousElementSibling.remove();
		});
		this.$element.closest(".form-element").children(":hidden").remove();
	}
	async import(event, data) {
		if (!data.value || !data.value.length) return;

		const target = event.currentTarget;

		if (data.force) this.setAllValues(data.value);
		else {
			domElementHelpers.renderImportConfirmationModal(
				target,
				data.sourceId,
				() => {
					this.setAllValues(data.value);
				},
			);
		}
	}
	setAllValues(value) {
		this.$inputFields.each((_, item) => {
			this.setInputValue(item, value);
		});
	}
	setInputValue(item, value) {
		$(item).prop("checked", value?.includes($(item).val()));
	}
}

export default CheckBoxSelector;

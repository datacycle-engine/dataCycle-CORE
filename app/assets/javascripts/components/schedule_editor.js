import DomElementHelpers from "../helpers/dom_element_helpers";

class ScheduleEditor {
	constructor(editor) {
		this.editor = editor;
		this.rrulesEl = this.editor.querySelector(":scope .rrules");
		this.ruleTypeSelector = this.rrulesEl.querySelector(
			":scope select.rrule-type-selector",
		);
		this.$editor = $(this.editor);
		this.$editor.addClass("dcjs-schedule-editor");
		this.minInput = this.$editor.find(
			'.daterange .form-element.start input.flatpickr-input[type="hidden"]',
		);
		this.maxInput = this.$editor.find(
			'.rrules .form-element.until input.flatpickr-input[type="hidden"]',
		);
		this.ruleTypes = [
			"single_occurrence",
			"daily",
			"weekly",
			"monthly",
			"yearly",
		];

		this.init();
	}
	init() {
		this.updateVisibleRrules();
		this.$editor
			.find(".rrule-type-selector")
			.on("change", this.updateVisibleRrules.bind(this));
		this.$editor
			.find('.fullday input[type="checkbox"]')
			.on("change", this.updateDateTimeEditors.bind(this));
		this.minInput.on("change", this.updateUntilEditor.bind(this));
		this.minInput.on("change", this.updateSpecialDateEditors.bind(this));
		this.maxInput.on("change", this.updateSpecialDateEditors.bind(this));
	}
	updateVisibleRrules(_event) {
		const selectedOption =
			this.ruleTypeSelector.querySelector("option:checked");
		const activeRuleType = selectedOption.dataset.type;
		const rulesToDisable = this.ruleTypes.filter((r) => r !== activeRuleType);
		const toDisable = rulesToDisable
			.map((rt) =>
				DomElementHelpers.inputFieldSelectors
					.map((f) => `:scope .${rt} ${f}`)
					.join(", "),
			)
			.join(", ");
		const toEnable = DomElementHelpers.inputFieldSelectors
			.map((f) => `:scope .${selectedOption.dataset.type} ${f}`)
			.join(", ");

		for (const item of this.rrulesEl.querySelectorAll(toDisable)) {
			item.disabled = true;
		}
		for (const item of this.rrulesEl.querySelectorAll(toEnable)) {
			item.disabled = false;
		}

		this.rrulesEl.classList.remove(...rulesToDisable);
		this.rrulesEl.classList.add(activeRuleType);
	}

	updateDateTimeEditors(event) {
		event.preventDefault();

		this.$editor
			.find(
				'.form-element.start .flatpickr-input[type="text"], .form-element.end .flatpickr-input[type="text"]',
			)
			.trigger("dc:flatpickr:reInit", {
				enableTime: !$(event.currentTarget).prop("checked"),
			});
	}
	updateUntilEditor(event) {
		this.maxInput
			.get(0)
			._flatpickr.set("minDate", $(event.currentTarget).val());
	}
	updateSpecialDateEditors(event) {
		event.preventDefault();

		const mode = $(event.currentTarget)
			.closest(".form-element")
			.hasClass("start")
			? "minDate"
			: "maxDate";

		this.$editor
			.find(
				'.special-dates .rdate .flatpickr-input[type="hidden"], .special-dates .exdate .flatpickr-input[type="hidden"]',
			)
			.each((_i, item) => {
				item._flatpickr.set(mode, $(event.currentTarget).val());
			});
	}
}

export default ScheduleEditor;

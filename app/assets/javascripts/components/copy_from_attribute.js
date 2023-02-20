class CopyFromAttribute {
	constructor(element) {
		this.$element = $(element);
		this.copyButton = this.$element.find("a.copy-from-attribute-button");
		this.clearButton = this.$element.find("a.copy-from-attribute-clear-button");
		this.clearable = this.copyButton.data("clearFromAttribute");
		this.copyFrom = this.copyButton.data("copyFrom");
		this.$formElement = this.$element.closest(".form-element");
		this.label = this.$formElement.data("label");
		this.$target = this.$formElement
			.siblings(`[data-key*="${this.copyFrom}"]`)
			.first();
		this.locale =
			this.$formElement.closest("form").find(':hidden[name="locale"]').val() ||
			"";

		this.init();
	}
	init() {
		this.$element[0].classList.add("dcjs-copy-from-attribute");

		if (!this.hasCopyableValue()) {
			this.$element.hide();
			return;
		}

		this.copyButton.on("click", this.copyValueFromAttribute.bind(this));
		this.clearButton.on("click", this.clearValueFromAttribute.bind(this));
	}
	hasCopyableValue() {
		const value = this.getTargetValue();

		return Array.isArray(value) ? value.length : value;
	}
	copyValueFromAttribute(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		if (!this.$target.length) return;

		this.$formElement
			.find(DataCycle.config.EditorSelectors.join(", "))
			.trigger("dc:import:data", {
				value: this.getTargetValue(),
				locale: this.locale,
			});

		if (this.clearable) {
			this.$target.trigger("dc:field:reset");
			this.$element.fadeOut();
		}
	}
	clearValueFromAttribute(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		if (!this.$target.length) return;

		this.$target.trigger("dc:field:reset");
		this.$element.fadeOut();
	}
	getTargetValue() {
		let value = this.$target.find(":input").serializeArray();

		if (
			value.length &&
			this.$target.find(":input").first().prop("name").endsWith("[]")
		)
			value = value.map((v) => v.value);
		else if (value.length) value = value[0].value;

		if (typeof value === "string") value = value.trim();

		return value.filter(Boolean);
	}
}

export default CopyFromAttribute;

class EmbeddedTitle {
	constructor(element) {
		this.$element = $(element);
		this.$sourceField = this.$element.find(":input, .detail-content").first();
		this.$targetField = this.$element
			.closest(".content-object-item, .detail-type.embedded")
			.find("> .accordion-title > .title > .embedded-title");

		this.init();
	}
	init() {
		this.updateEmbeddedTitle();

		this.$element.on(
			"change dc:embedded:changeTitle",
			this.updateEmbeddedTitle.bind(this),
		);
	}
	getSourceValue() {
		if (!this.$sourceField.length) return;

		let value;
		const tempDivElement = document.createElement("div");

		if (this.$sourceField.hasClass("detail-content"))
			value = this.$sourceField.text();
		else value = this.$sourceField.val();

		tempDivElement.innerHTML = value;

		return (tempDivElement.textContent || "").trim();
	}
	updateEmbeddedTitle(_event) {
		if (!this.$targetField.length) return;

		const value = this.getSourceValue();

		this.$targetField.text(value);
		this.$targetField.attr("title", value);

		if (value?.length) this.$targetField.addClass("visible");
		else this.$targetField.removeClass("visible");
	}
}

export default EmbeddedTitle;

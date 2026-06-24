export default class DcPlaceholder {
	static selector = ".detail-content [data-dc-placeholder]";
	static className = "dcjs-placeholder";
	constructor(element) {
		this.element = element;

		this.init();
	}
	async init() {
		const value = this.element.dataset.dcPlaceholder;
		if (!value) return;

		const label = await I18n.translate(
			"frontend.text_editor.placeholder_label",
		);

		this.element.setAttribute("data-dc-tooltip", `${label}: ${value}`);
	}
}

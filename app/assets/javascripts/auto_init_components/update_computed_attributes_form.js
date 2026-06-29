export default class UpdateComputedAttributesForm {
	static selector = ".update-computed-attributes-form";
	static className = "dcjs-update-computed-attributes-form";
	constructor(element) {
		this.element = element;
		this.reveal = this.element.closest(".reveal");

		this.init();
	}
	init() {
		this.element.addEventListener(
			"turbo:submit-end",
			this.submitHandler.bind(this),
		);
	}
	submitHandler(event) {
		if (!event.detail?.success || !this.reveal) return;

		$(this.reveal).foundation("close");
	}
}

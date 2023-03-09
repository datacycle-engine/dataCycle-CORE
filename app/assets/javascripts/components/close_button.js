import DomElementHelpers from "../helpers/dom_element_helpers";

class CloseButton {
	constructor(item) {
		this.item = item;
		this.item.classList.add("dcjs-close-button");
		this.parent = this.item.closest("[data-closable]");

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.closeParent.bind(this));
	}
	closeParent(event) {
		event.preventDefault();

		DomElementHelpers.fadeAndRemove(this.parent);
	}
}

export default CloseButton;

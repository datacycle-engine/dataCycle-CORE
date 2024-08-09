import DomElementHelpers from "../helpers/dom_element_helpers";

class CloseButton {
	constructor(item) {
		this.item = item;
		this.parent = this.item.closest("[data-closable]");

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.closeParent.bind(this));
	}
	closeParent(event) {
		event.preventDefault();

		DomElementHelpers.fadeOut(this.parent)
			.then(() => this.parent.remove())
			.catch(() => {});
	}
}

export default CloseButton;

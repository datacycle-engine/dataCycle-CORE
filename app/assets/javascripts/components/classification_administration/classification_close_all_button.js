class ClassificationCloseAllButton {
	constructor(item) {
		this.item = item;
		this.item.classList.add("dcjs-classification-close-all-button");

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.closeAllChildren.bind(this));
	}
	closeAllChildren(event) {
		event.preventDefault();
		event.stopPropagation();

		this.closeDirectChildren(
			this.item
				.closest("li")
				.querySelector(":scope > span.inner-item > a.name"),
		);
	}
	closeDirectChildren(element) {
		requestAnimationFrame(() => {
			if (element.classList.contains("open")) element.click();

			for (const child of element
				.closest("li")
				.querySelectorAll(
					":scope > ul.children .name.dcjs-classification-name-button",
				))
				this.closeDirectChildren(child);
		});
	}
}

export default ClassificationCloseAllButton;

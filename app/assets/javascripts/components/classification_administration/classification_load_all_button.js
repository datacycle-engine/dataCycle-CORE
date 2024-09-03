import ObserverHelpers from "../../helpers/observer_helpers";

class ClassificationLoadAllButton {
	constructor(item) {
		this.item = item;

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.loadAllChildren.bind(this));
	}
	loadAllChildren(event) {
		event.preventDefault();
		event.stopPropagation();

		this.loadDirectChildren(
			this.item
				.closest("li")
				.querySelector(":scope > span.inner-item > a.name"),
		);
	}
	loadDirectChildren(element) {
		const liElement = element.closest("li");

		if (liElement.closest(`li[data-id="${liElement.dataset.id}"]:not(:scope)`))
			return;

		if (element.classList.contains("loaded")) {
			const childContainer = liElement.querySelector(":scope > ul.children");

			if (childContainer.querySelector(":scope > li:not(.new-button)")) {
				this.openElement(element);
				this.showChildrenRecursive(element);
			}
		} else {
			const classObserver = new MutationObserver(
				this.waitForLoadCallback.bind(this),
			);
			classObserver.observe(element, ObserverHelpers.changedClassConfig);

			this.openElement(element);
		}
	}
	openElement(element) {
		if (
			element.classList.contains("dcjs-classification-name-button") &&
			!element.classList.contains("open")
		)
			requestAnimationFrame(() => element.click());
	}
	waitForLoadCallback(mutations, observer) {
		for (const mutation of mutations) {
			if (mutation.type !== "attributes") continue;

			if (
				mutation.target.classList.contains("dcjs-classification-name-button") &&
				!mutation.oldValue?.includes("dcjs-classification-name-button")
			) {
				this.openElement(mutation.target);
				this.hideChildrenIfEmpty(mutation.target);
			}

			if (
				mutation.target.classList.contains("loaded") &&
				!mutation.oldValue?.includes("loaded")
			) {
				observer.disconnect();
				this.showChildrenRecursive(mutation.target);
				this.hideChildrenIfEmpty(mutation.target);
			}
		}
	}
	hideChildrenIfEmpty(element) {
		if (!element.classList.contains("open")) return;

		const children = element
			.closest("li")
			.querySelector(":scope > ul.children");

		if (!children.querySelectorAll(":scope > li:not(.new-button)").length)
			requestAnimationFrame(() => element.click());
	}
	showChildrenRecursive(element) {
		for (const child of element
			.closest("li")
			.querySelectorAll(":scope > ul.children > li > span.inner-item > .name"))
			this.loadDirectChildren(child);
	}
}

export default ClassificationLoadAllButton;

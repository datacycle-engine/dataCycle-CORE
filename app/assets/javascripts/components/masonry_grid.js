import ObserverHelpers from "../helpers/observer_helpers";
import DomElementHelpers from "../helpers/dom_element_helpers";

class MasonryGrid {
	constructor(selector) {
		selector.dcMasonryGrid = true;
		this.grid = selector;
		this.rowHeight = parseInt(
			window.getComputedStyle(this.grid).getPropertyValue("grid-auto-rows"),
		);
		this.config = {
			attributes: true,
			childList: true,
			subtree: true,
		};
		this.observer = new MutationObserver(this.callbackFunction.bind(this));
		this.addedItemsObserver = new MutationObserver(
			this._checkForAddedNodes.bind(this),
		);
		this.resizeQueue = [];

		if (this.checkSupport()) this.setup();
		else this.renderNotSupportedError();
	}
	setup() {
		this.removeLoadingAnimation();
		this.initializeItems();

		addEventListener("load", this.scrollToThingAndResize.bind(this));
		addEventListener("resize", this.resizeAllMasonryItems.bind(this));

		this.addedItemsObserver.observe(this.grid, ObserverHelpers.newItemsConfig);
	}
	scrollToThingAndResize(event) {
		this.resizeAllMasonryItems(event);

		const thing = document.getElementById(history.state?.thingId);
		if (thing) requestAnimationFrame(() => thing.scrollIntoView());
	}
	removeLoadingAnimation() {
		if (this.grid.querySelector(":scope > .grid-loading"))
			for (const loader of this.grid.querySelectorAll(":scope > .grid-loading"))
				loader.remove();
	}
	initializeItems() {
		if (this.grid.querySelector(":scope > .grid-item"))
			for (const item of this.grid.querySelectorAll(":scope > .grid-item"))
				this.initializeItem(item);
	}
	checkSupport() {
		const el = document.createElement("div");
		return typeof el.style.grid === "string";
	}
	renderNotSupportedError() {
		document.body.insertAdjacentHTML(
			"beforeend",
			'<div class="html-feature-missing"><h2>Verwenden Sie bitte einen aktuellen Browser um diese Anwendung korrekt darstellen zu können!</h2></div>',
		);
	}
	_checkForAddedNodes(mutations) {
		for (const mutation of mutations) {
			if (mutation.type !== "childList") continue;

			for (const addedNode of mutation.addedNodes) {
				if (addedNode.nodeType !== Node.ELEMENT_NODE) continue;

				ObserverHelpers.checkForConditionRecursive(
					addedNode,
					".grid-item",
					this.initializeItem.bind(this),
				);
			}
		}
	}
	initializeItem(item) {
		item.style.display = "block";
		this.addToResizeQueue(item);
		this.observer.observe(item, this.config);
	}
	callbackFunction(mutationsList, _observer) {
		for (const mutation of mutationsList) {
			if (mutation.target.nodeType !== Node.ELEMENT_NODE) continue;

			const item = mutation.target.closest(".grid-item");

			if (
				item &&
				!mutation.target.closest(".watch-lists") &&
				!mutation.target.closest(".watch-lists-link") &&
				this.heightChanged(item)
			) {
				this.addToResizeQueue(item);
			}
		}
	}
	boundingHeight(item) {
		return item.querySelector(".content-link") === null
			? item.getBoundingClientRect().height
			: item.querySelector(".content-link").getBoundingClientRect().height;
	}
	resizeMasonryItems() {
		for (const item of this.resizeQueue) {
			const newHeight = this.boundingHeight(item);
			const rowSpan = Math.ceil(newHeight / this.rowHeight) + 1;
			item.dataset.originalHeight = newHeight;
			item.style.gridRow = `span ${rowSpan}`;
		}

		this.resizeQueue.length = 0;
	}
	addToResizeQueue(item) {
		if (!this.resizeQueue.length)
			requestAnimationFrame(this.resizeMasonryItems.bind(this));

		this.resizeQueue.push(item);
	}
	resizeAllMasonryItems(_event) {
		for (const item of this.grid.querySelectorAll(":scope > .grid-item"))
			this.addToResizeQueue(item);
	}
	heightChanged(item) {
		return (
			DomElementHelpers.parseDataAttribute(item.dataset.originalHeight) !==
			this.boundingHeight(item)
		);
	}
}

export default MasonryGrid;

import { parseDataAttribute } from "../helpers/dom_element_helpers";
import {
	checkForConditionRecursive,
	newDirectItemsConfig,
} from "../helpers/observer_helpers";

export default class MasonryGrid {
	static selector = ".grid";
	static className = "grid";

	constructor(selector) {
		this.grid = selector;
		this.rowHeight = Number.parseInt(
			window.getComputedStyle(this.grid).getPropertyValue("grid-auto-rows"),
		);
		this.observer = new MutationObserver(this.itemChildrenCallback.bind(this));
		this.resizeObserver = new ResizeObserver(
			this.childrenSizeChanged.bind(this),
		);
		this.addedItemsObserver = new MutationObserver(
			this.#checkForAddedNodes.bind(this),
		);
		this.resizeQueue = [];

		if (this.checkSupport()) this.setup();
		else this.renderNotSupportedError();
	}
	setup() {
		this.removeLoadingAnimation();
		this.initializeItems();

		if (document.readyState === "complete") this.scrollToThingAndResize();
		else addEventListener("load", this.scrollToThingAndResize.bind(this));
		addEventListener("resize", this.resizeAllMasonryItems.bind(this));

		this.addedItemsObserver.observe(this.grid, newDirectItemsConfig);
	}
	scrollToThingAndResize(_) {
		this.resizeAllMasonryItems();

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
	#checkForAddedNodes(mutations) {
		for (const mutation of mutations) {
			if (mutation.type !== "childList") continue;

			for (const addedNode of mutation.addedNodes) {
				if (addedNode.nodeType !== Node.ELEMENT_NODE) continue;

				checkForConditionRecursive(
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
		this.observeItemSize(item);
	}
	observeItemSize(item) {
		this.observer.observe(item, newDirectItemsConfig);

		for (const child of item.children) {
			this.resizeObserver.observe(child);
		}
	}
	childrenSizeChanged(entries) {
		for (const entry of entries) {
			const gridItem = entry.target.closest(".grid-item");
			if (
				gridItem.scrollHeight !==
				parseDataAttribute(gridItem.dataset?.originalHeight)
			) {
				this.addToResizeQueue(gridItem);
			}
		}
	}
	itemChildrenCallback(mutationsList) {
		for (const mutation of mutationsList) {
			if (mutation.target.nodeType !== Node.ELEMENT_NODE) continue;

			for (const addedNode of mutation.addedNodes)
				this.resizeObserver.observe(addedNode);
			for (const removedNode of mutation.removedNodes)
				this.resizeObserver.unobserve(removedNode);
		}
	}
	resizeMasonryItems() {
		for (const item of this.resizeQueue) {
			const originalHeight = parseDataAttribute(item.dataset.originalHeight);
			const newHeight = item.scrollHeight;
			if (newHeight === originalHeight) continue;

			const rowSpan = Math.ceil(newHeight / this.rowHeight) + 1;
			item.dataset.originalHeight = newHeight;
			item.style.gridRow = `span ${rowSpan}`;
		}

		this.resizeQueue.length = 0;
	}
	addToResizeQueue(item) {
		if (!this.resizeQueue.length)
			requestAnimationFrame(this.resizeMasonryItems.bind(this));
		if (!this.resizeQueue.includes(item)) this.resizeQueue.push(item);
	}
	resizeAllMasonryItems(_event = null) {
		for (const item of this.grid.querySelectorAll(":scope > .grid-item"))
			this.addToResizeQueue(item);
	}
}

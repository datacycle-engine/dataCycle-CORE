import DomElementHelpers from "../helpers/dom_element_helpers";
import throttle from "lodash/throttle";

class DcStickyBar {
	constructor() {
		this.throttledUpdateAllStickyZIndizes = throttle(
			this.updateAllStickyZIndizes.bind(this),
			1000,
		);

		this.setup();
	}
	static stickyHtmlClasses = ["dc-sticky-bar", "ql-toolbar"];
	static joinedStickyHtmlClasses() {
		return this.stickyHtmlClasses.map((c) => `.${c}`).join(", ");
	}
	setup() {
		DataCycle.initNewElements(
			`${this.constructor.stickyHtmlClasses
				.map((c) => `.${c}:not(.dcjs-sticky-bar)`)
				.join(", ")}`,
			this.initNewStickyBar.bind(this),
		);
	}
	initNewStickyBar(element) {
		element.classList.add("dcjs-sticky-bar");
		this.constructor.setStickyOffset(element);

		this.throttledUpdateAllStickyZIndizes();
	}
	static setStickyOffset(element) {
		const { offset } = this.calculateStickyOffset(element.parentElement);

		element.style.setProperty("--dc-sticky-bar-offset", `${offset}px`);
	}
	updateAllStickyZIndizes() {
		const allElements = Array.from(
			document.querySelectorAll(this.constructor.joinedStickyHtmlClasses()),
		).reverse();
		let index = parseInt(window.getComputedStyle(allElements[0]).zIndex);

		for (const elem of allElements) {
			elem.style.zIndex = index;
			++index;
		}
	}
	static calculateStickyOffset(elem, previousElement = undefined, offset = 0) {
		if (!(elem && elem instanceof Element))
			return {
				scrollableParent: window,
				offset: offset,
				scrollElement: document.body,
			};
		if (DomElementHelpers.isScrollable(elem))
			return {
				scrollableParent: elem,
				offset: offset,
				scrollElement: previousElement,
			};

		let activeElem = elem;
		while (activeElem.previousElementSibling) {
			activeElem = activeElem.previousElementSibling;

			if (this.stickyHtmlClasses.some((c) => activeElem.classList.contains(c)))
				offset += activeElem.getBoundingClientRect().height;
		}

		if (this.stickyHtmlClasses.some((c) => elem.classList.contains(c)))
			offset += elem.getBoundingClientRect().height;

		return this.calculateStickyOffset(elem.parentElement, elem, offset);
	}
	static scrollIntoViewWithStickyOffset(element) {
		const { scrollableParent, offset, scrollElement } =
			this.calculateStickyOffset(element);

		scrollableParent.scrollTo({
			behavior: "smooth",
			top:
				element.getBoundingClientRect().top -
				(offset + 10) -
				scrollElement.getBoundingClientRect().top,
		});
	}
}

export default DcStickyBar;

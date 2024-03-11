class AccordionToggleChildren {
	constructor(item) {
		this.item = item;
		this.item.classList.add("dcjs-accordion-toggle-children");
		this.containerSelector =
			"[data-accordion], .form-element.embedded_object, .inner-container";

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.toggleChildren.bind(this));
	}
	toggleChildren(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		const currentTarget = event.currentTarget;
		const container = currentTarget.closest(
			`${this.containerSelector}, .accordion-item`,
		);
		let direction;
		if (/-close-/.test(currentTarget.className)) direction = "up";
		else if (/-open-/.test(currentTarget.className)) direction = "down";
		else return;

		this.toggleAccordionItems(container, direction);
	}
	toggleAccordionItems(container, direction) {
		const accordions = [];

		if (container.hasAttribute("data-accordion")) accordions.push(container);
		if (container.querySelector("[data-accordion]"))
			accordions.push(...container.querySelectorAll("[data-accordion]"));
		if (container.classList.contains("accordion-item")) {
			this.toggleChild(
				container.closest(this.containerSelector),
				direction,
				container.querySelector(":scope > .accordion-content"),
			);
		}

		for (const accordion of accordions) {
			this.toggleChild(accordion, direction);
		}
	}
	toggleChild(accordion, direction, child = null) {
		const $accordion = $(accordion);
		if (typeof $accordion.foundation !== "function") return;

		const $children = child
			? $(child)
			: $accordion.find("> .accordion-item > .accordion-content");

		$accordion.foundation(direction, $children);
	}
}

export default AccordionToggleChildren;

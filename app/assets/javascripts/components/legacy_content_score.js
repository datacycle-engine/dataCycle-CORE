import DomElementHelpers from "../helpers/dom_element_helpers";

class LegacyContentScore {
	constructor(element) {
		this.element = element;
		this.element.classList.add("dcjs-content-score-class");

		this.setContentScoreClass();
	}
	async setContentScoreClass() {
		this.element.classList.add("dcjs-content-score-class");
		const embeddedParent = this.element.closest(".detail-type.embedded");
		const value = parseInt(
			DomElementHelpers.parseDataAttribute(this.element.dataset.value),
		);
		const icon = this.element.querySelector(
			".type-number-content_score, .type-string-content_score",
		);

		if (!(value && icon)) return;

		const min = parseInt(
			embeddedParent
				? embeddedParent.querySelector(".detail-type.min_value").dataset.value
				: DomElementHelpers.parseDataAttribute(this.element.dataset.min) || 0,
		);
		const max = parseInt(
			embeddedParent
				? embeddedParent.querySelector(".detail-type.max_value").dataset.value
				: DomElementHelpers.parseDataAttribute(this.element.dataset.max) || 100,
		);
		const rangePart = Math.floor((max - min) / 3);
		const label = this.element.querySelector(".attribute-label-text");
		let title = `min: ${min}, max: ${max}`;

		if (embeddedParent) {
			await $(
				embeddedParent.querySelector(
					'.translatable-attribute-container[data-attribute-key="name"] > .translatable-attribute.remote-render.active',
				),
			).triggerHandler("dc:remote:forceRenderTranslations");

			const dynamicLabel = embeddedParent.querySelector(
				'.translatable-attribute-container[data-attribute-key="name"] > .translatable-attribute.active .detail-type',
			);

			if (dynamicLabel?.dataset.value) {
				label.textContent = dynamicLabel.dataset.value;
				label.title = dynamicLabel.dataset.value;
			}
		}

		if (label) {
			title = `${label.title}\n\n${title}`;
			label.removeAttribute("title");
		}

		this.element.title = title;

		if (value > rangePart && value <= rangePart * 2)
			icon.classList.add("medium-score");
		else if (value > rangePart * 2) icon.classList.add("high-score");
	}
}

export default LegacyContentScore;

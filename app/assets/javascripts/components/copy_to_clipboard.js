import {
	computePosition,
	autoPlacement,
	offset,
	shift,
} from "@floating-ui/dom";
import { inputFieldSelectors } from "../helpers/dom_element_helpers";

class CopyToClipboard {
	constructor(item) {
		this.item = item;

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.copyValueToClipboard.bind(this));
	}
	copyValueToClipboard(event) {
		event.preventDefault();
		event.stopPropagation();

		let currentTarget = event.currentTarget;
		if (currentTarget.classList.contains("admin-clipboard"))
			currentTarget = currentTarget
				.closest("section.tabs-panel")
				.querySelector("pre code");

		let text;
		if ("json" in currentTarget.dataset && currentTarget.dataset.json)
			text = currentTarget.dataset.json;
		else if ("value" in currentTarget.dataset && currentTarget.dataset.value)
			text = currentTarget.dataset.value;
		else if ("value" in currentTarget && currentTarget.value)
			text = currentTarget.value;
		else text = currentTarget.textContent;

		if (!text) return console.warn("nothing to copy");

		navigator.clipboard
			.writeText(text)
			.then(() => this.showTooltip())
			.catch((error) => console.error(error));
	}
	async showTooltip() {
		const tooltip = document.createElement("span");
		tooltip.classList.add("clipboard-notice");
		tooltip.textContent = await I18n.translate("actions.copied_to_clipboard");
		document.body.appendChild(tooltip);

		computePosition(this.item, tooltip, {
			middleware: [
				offset(6),
				autoPlacement({
					padding: 5,
				}),
				shift({ padding: 5 }),
			],
		}).then(({ x, y }) => {
			Object.assign(tooltip.style, {
				left: `${x}px`,
				top: `${y}px`,
			});

			setTimeout(() => {
				const $tooltip = $(tooltip);

				$tooltip.fadeOut("fast", () => {
					$tooltip.remove();
				});
			}, 1000);
		});
	}
}

export default CopyToClipboard;

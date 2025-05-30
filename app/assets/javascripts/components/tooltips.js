import {
	computePosition,
	autoUpdate,
	arrow,
	offset,
	hide,
	flip,
	shift,
} from "@floating-ui/dom";
import { nanoid } from "nanoid";

class Tooltips {
	constructor() {
		this.tooltip = document.getElementById("dc-tooltip");
		this.referenceElement;
		this.cleanups = {};
		this.dataChangedObserver = new MutationObserver(
			this.updateTooltipContent.bind(this),
		);

		this.init();
	}
	init() {
		if (!this.tooltip) this.createTooltip();

		this.initNewTooltips();
	}
	createTooltip() {
		const tooltip = document.createElement("div");
		tooltip.id = "dc-tooltip";

		const arrow = document.createElement("div");
		arrow.id = "dc-tooltip-arrow";
		tooltip.appendChild(arrow);

		const tooltipContent = document.createElement("div");
		tooltipContent.id = "dc-tooltip-content";
		tooltip.appendChild(tooltipContent);

		document.body.appendChild(tooltip);

		this.tooltipArrow = arrow;
		this.tooltipContent = tooltipContent;
		this.tooltip = tooltip;
	}
	initNewTooltips() {
		DataCycle.registerAddCallback(
			"[data-dc-tooltip]",
			"tooltip",
			this.addEventsForTooltip.bind(this),
		);
	}
	addEventsForTooltip(element) {
		element.dataset.dcTooltipId = nanoid();
		element.addEventListener("mouseenter", this.showTooltipDelayed.bind(this));
		element.addEventListener("mouseleave", this.hideTooltip.bind(this));
	}
	addAutoUpdate() {
		return autoUpdate(
			this.referenceElement,
			this.tooltip,
			this.updatePosition.bind(this),
		);
	}
	showTooltipDelayed(event) {
		if (!event.target.dataset.dcTooltip) return;

		this.referenceElement = event.target;

		setTimeout(this.showTooltip.bind(this, event.target), 300);
	}
	async showTooltip(target) {
		if (
			this.referenceElement?.dataset.dcTooltipId !==
				target.dataset.dcTooltipId ||
			this.cleanups[target.dataset.dcTooltipId]
		)
			return;

		this.updateTooltipContent();
		this.watchTooltipContent();

		this.tooltip.style.display = "block";
		this.cleanups[this.referenceElement.dataset.dcTooltipId] =
			this.addAutoUpdate();
		await this.updatePosition();
	}
	hideTooltip(_event) {
		Object.assign(this.tooltip.style, {
			left: "",
			top: "",
			display: "",
		});

		Object.assign(this.tooltipArrow.style, {
			left: "",
			top: "",
			right: "",
			bottom: "",
		});

		this.cleanupTooltipAttributes();
		this.cleanupTooltips();
		this.referenceElement = undefined;

		this.stopWatchingTooltipContent();
	}
	cleanupTooltips() {
		for (const cleanup of Object.values(this.cleanups)) cleanup();

		this.cleanups = {};
	}
	watchTooltipContent() {
		this.dataChangedObserver.disconnect();
		this.dataChangedObserver.observe(this.referenceElement, {
			attributes: true,
			attributeFilter: ["data-dc-tooltip"],
		});
	}
	stopWatchingTooltipContent() {
		this.dataChangedObserver.disconnect();
	}
	updateTooltipContent() {
		this.tooltipContent.innerHTML = this.referenceElement.dataset.dcTooltip
			? this.referenceElement.dataset.dcTooltip.trim()
			: "";

		if (this.referenceElement.dataset.dcTooltipClass)
			this.tooltip.classList.add(
				this.referenceElement.dataset.dcTooltipClass.trim(),
			);
	}
	cleanupTooltipAttributes() {
		if (this.referenceElement?.dataset.dcTooltipClass)
			this.tooltip.classList.remove(
				this.referenceElement.dataset.dcTooltipClass.trim(),
			);
	}
	async updatePosition() {
		const position = await computePosition(
			this.referenceElement,
			this.tooltip,
			{
				placement: this.referenceElement.dataset.dcTooltipPlacement || "top",
				strategy: "fixed",
				middleware: [
					offset(6),
					flip({ padding: 5 }),
					shift({ padding: 5 }),
					arrow({
						element: this.tooltipArrow,
					}),
					hide({ strategy: "referenceHidden" }),
				],
			},
		);

		this.positionTooltip(position);
	}
	positionTooltip({ x, y, placement, middlewareData }) {
		Object.assign(this.tooltip.style, {
			left: `${x}px`,
			top: `${y}px`,
		});

		const { x: arrowX, y: arrowY } = middlewareData.arrow;
		const { referenceHidden } = middlewareData.hide;

		if (referenceHidden) return this.hideTooltip();

		const staticSide = {
			top: "bottom",
			right: "left",
			bottom: "top",
			left: "right",
		}[placement.split("-")[0]];

		Object.assign(this.tooltipArrow.style, {
			left: arrowX != null ? `${arrowX}px` : "",
			top: arrowY != null ? `${arrowY}px` : "",
			right: "",
			bottom: "",
			[staticSide]: "-4px",
		});
	}
}

export default Tooltips;

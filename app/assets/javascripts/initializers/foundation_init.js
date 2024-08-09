import domElementHelpers from "../helpers/dom_element_helpers";
import AccordionToggleChildren from "../components/accordion/accordion_toggle_children";
import OffCanvasClickHandler from "../components/offcanvas/offcanvas_click_handler";

import { Foundation } from "foundation-sites/js/foundation.core";
import { Reveal } from "foundation-sites/js/foundation.reveal";
import { Dropdown } from "foundation-sites/js/foundation.dropdown";
import { Accordion } from "foundation-sites/js/foundation.accordion";
import { Slider } from "foundation-sites/js/foundation.slider";
import { OffCanvas } from "foundation-sites/js/foundation.offcanvas";
import { Tabs } from "foundation-sites/js/foundation.tabs";
import CloseButton from "../components/close_button";

function removeFoundationOverlays(element, type) {
	let overlay = document.getElementById(element.dataset[type]);

	if (!overlay || document.querySelector(`[data-${type}="${overlay.id}"]`))
		return;
	if (overlay.parentElement.classList.contains("reveal-overlay"))
		overlay = overlay.parentElement;

	overlay.remove();
}

function initReveal(element) {
	if (
		element.classList.contains("media-preview") &&
		element.closest(".object-browser-overlay")
	)
		return;

	if (
		element.hasAttribute("data-delayed-init") &&
		element.dataset.initialState !== "open"
	) {
		setTimeout(() => {
			const link = document.querySelector(`[data-open="${element.id}"]`);

			link.addEventListener(
				"click",
				(e) => {
					e.preventDefault();
					e.stopPropagation();

					new Foundation.Reveal($(element));
					$(element).foundation("open");
				},
				{ once: true },
			);
		});
	} else {
		new Foundation.Reveal($(element));
		if (element.dataset.initialState === "open") $(element).foundation("open");
	}
}

function monitorSizeChanges(element) {
	const resizeObserver = new ResizeObserver((_) => {
		if (domElementHelpers.isVisible(element))
			$(element).foundation("_updatePosition");
	});

	resizeObserver.observe(element);
}

export default function () {
	Foundation.addToJquery($);

	Foundation.plugin(Accordion, "Accordion");
	Foundation.plugin(Dropdown, "Dropdown");
	Foundation.plugin(OffCanvas, "OffCanvas");
	Foundation.plugin(Reveal, "Reveal");
	Foundation.plugin(Slider, "Slider");
	Foundation.plugin(Tabs, "Tabs");

	Foundation.Reveal.defaults.closeOnClick = false;
	Foundation.Reveal.defaults.multipleOpened = true;
	Foundation.Dropdown.defaults.position = "bottom";
	Foundation.Dropdown.defaults.alignment = "left";
	Foundation.Dropdown.defaults.hover = true;
	Foundation.Dropdown.defaults.hoverPane = true;

	DataCycle.registerRemoveCallback("[data-open]", (e) =>
		removeFoundationOverlays(e, "open"),
	);

	DataCycle.registerRemoveCallback("[data-toggle]", (e) =>
		removeFoundationOverlays(e, "toggle"),
	);

	// Close Button
	DataCycle.registerAddCallback(
		"[data-close]",
		"fd-close-button",
		(e) => new CloseButton(e),
	);

	// Foundation Slider
	DataCycle.registerAddCallback(".slider", "fd-slider", (e) => {
		new Foundation.Slider($(e));
	});

	// Foundation Accordion
	DataCycle.registerAddCallback("[data-accordion]", "fd-accordion", (e) => {
		new Foundation.Accordion($(e));
	});

	DataCycle.registerAddCallback(
		"[data-accordion].dcjs-fd-accordion .accordion-item",
		"fd-accordion-item",
		(e) => {
			Foundation.reInit($(e.closest("[data-accordion]")));
		},
	);

	// Foundation Dropdown
	DataCycle.registerAddCallback("[data-dropdown]", "fd-dropdown", (e) => {
		new Foundation.Dropdown($(e));
	});

	// Foundation OffCanvas
	DataCycle.registerAddCallback("[data-off-canvas]", "fd-offcanvas", (e) => {
		new Foundation.OffCanvas($(e));
	});
	DataCycle.registerAddCallback(
		"#settings-off-canvas",
		"offcanvas-click-handler",
		(e) => {
			new OffCanvasClickHandler(e);
		},
	);

	// Foundation Reveal
	DataCycle.registerAddCallback("[data-reveal]", "foundation-reveal", (e) =>
		initReveal(e),
	);

	// Foundation Reveal Position Updater
	DataCycle.registerAddCallback(
		'.reveal:not(.full)[data-v-offset="auto"], .reveal:not(.full):not([data-v-offset])',
		"fd-reveal-updater",
		(e) => monitorSizeChanges(e),
	);

	// Foundation Tabs
	DataCycle.registerAddCallback("[data-tabs]", "fd-tabs", (e) => {
		new Foundation.Tabs($(e));
	});

	$(document).on("open.zf.reveal", ".reveal", (event) => {
		event.stopPropagation();

		const $target = $(event.currentTarget);

		$(".reveal:visible, .reveal-overlay:visible").css("z-index", "");
		$target.add($target.parent(".reveal-overlay")).css("z-index", 1007);
	});

	$(document).on("closed.zf.reveal", ".reveal", (event) => {
		event.stopPropagation();

		const previousReveal = $(".reveal:visible").last();

		previousReveal
			.add(previousReveal.parent(".reveal-overlay"))
			.css("z-index", 1007);
	});

	$(document).on("closed.zf.reveal", ".reveal", (event) => {
		event.stopPropagation();

		const $target = $(event.currentTarget);

		if ($target.find("video").length) $target.find("video").get(0).pause();
	});

	$(document).on("remove", "*", (event) => {
		event.stopPropagation();
	});

	$(document).on("click", "div.accordion-title", (event) => {
		if ($(event.target).closest("a").length) return;

		event.preventDefault();
		event.stopImmediatePropagation();

		$(event.currentTarget)
			.closest("[data-accordion]")
			.foundation(
				"toggle",
				$(event.currentTarget)
					.closest(".accordion-title")
					.siblings(".accordion-content"),
			);
	});

	DataCycle.registerAddCallback(
		".accordion-close-all, .accordion-close-children, .accordion-open-all, .accordion-open-children",
		"accordion-toggle-children",
		(e) => new AccordionToggleChildren(e),
	);
}

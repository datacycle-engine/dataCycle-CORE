import domElementHelpers from "../helpers/dom_element_helpers";
import AccordionToggleChildren from "../components/accordion/accordion_toggle_children";

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

	element.classList.add("dcjs-foundation-reveal");

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
	element.classList.add("dcjs-fd-reveal-updater");

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

	DataCycle.htmlObserver.removeCallbacks.push([
		"[data-open]",
		(e) => removeFoundationOverlays(e, "open"),
	]);
	DataCycle.htmlObserver.removeCallbacks.push([
		"[data-toggle]",
		(e) => removeFoundationOverlays(e, "toggle"),
	]);

	// Close Button
	DataCycle.initNewElements(
		"[data-close]:not(.dcjs-fd-close-button)",
		(e) => new CloseButton(e),
	);

	// Foundation Slider
	DataCycle.initNewElements(".slider:not(.dcjs-fd-slider)", (e) => {
		e.classList.add("dcjs-fd-slider");
		new Foundation.Slider($(e));
	});

	// Foundation Accordion
	DataCycle.initNewElements("[data-accordion]:not(.dcjs-fd-accordion)", (e) => {
		new Foundation.Accordion($(e));
		e.classList.add("dcjs-fd-accordion");
	});
	DataCycle.initNewElements(
		"[data-accordion].dcjs-fd-accordion .accordion-item:not(.dcjs-fd-accordion-item)",
		(e) => {
			e.classList.add("dcjs-fd-accordion-item");
			Foundation.reInit($(e.closest("[data-accordion]")));
		},
	);

	// Foundation Dropdown
	DataCycle.initNewElements("[data-dropdown]:not(.dcjs-fd-dropdown)", (e) => {
		e.classList.add("dcjs-fd-dropdown");
		new Foundation.Dropdown($(e));
	});

	// Foundation OffCanvas
	DataCycle.initNewElements(
		"[data-off-canvas]:not(.dcjs-fd-offcanvas)",
		(e) => {
			e.classList.add("dcjs-fd-offcanvas");
			new Foundation.OffCanvas($(e));
		},
	);

	// Foundation Reveal
	DataCycle.initNewElements("[data-reveal]:not(.dcjs-foundation-reveal)", (e) =>
		initReveal(e),
	);

	// Foundation Reveal Position Updater
	DataCycle.initNewElements(
		'.reveal:not(.full)[data-v-offset="auto"]:not(.dcjs-fd-reveal-updater), .reveal:not(.full):not([data-v-offset]):not(.dcjs-fd-reveal-updater)',
		(e) => monitorSizeChanges(e),
	);

	// Foundation Tabs
	DataCycle.initNewElements("[data-tabs]:not(.dcjs-fd-tabs)", (e) => {
		e.classList.add("dcjs-fd-tabs");
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

	DataCycle.initNewElements(
		".accordion-close-all:not(.dcjs-accordion-toggle-children), .accordion-close-children:not(.dcjs-accordion-toggle-children), .accordion-open-all:not(.dcjs-accordion-toggle-children), .accordion-open-children:not(.dcjs-accordion-toggle-children)",
		(e) => new AccordionToggleChildren(e),
	);
}

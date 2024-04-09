import ObserverHelpers from "../helpers/observer_helpers";
import DomElementHelpers from "../helpers/dom_element_helpers";

function resizeDropdown(element) {
	const elementRect = element.getBoundingClientRect();
	const headerHeight = document
		.querySelector("header")
		.getBoundingClientRect().height;
	const $linkedItem = $(`[data-toggle="${$(element).prop("id")}"]`);

	if (!element.dataset.alignment) {
		element.classList.toggle(
			"has-alignment-right",
			$linkedItem.offset().left >
				window.innerWidth -
					($linkedItem.offset().left + $linkedItem.outerWidth()),
		);
		element.classList.toggle(
			"has-alignment-left",
			$linkedItem.offset().left <=
				window.innerWidth -
					($linkedItem.offset().left + $linkedItem.outerWidth()),
		);
	} else if (
		element.dataset.alignment === "left" &&
		elementRect.right > window.innerWidth
	) {
		element.classList.add("has-alignment-right");
		element.classList.remove("has-alignment-left");
	}

	const pseudoWidth = Number.parseInt(
		window.getComputedStyle(element, ":before").width,
	);
	let resetOffset = Math.abs($(element).position().left) - pseudoWidth / 2;

	if ($linkedItem.length)
		resetOffset = Math.min(
			resetOffset + $linkedItem[0].offsetWidth / 2,
			element.offsetWidth - pseudoWidth - 3,
		);

	element.style.setProperty("--dropdown-arrow-left-offset", `${resetOffset}px`);

	if (!$linkedItem.length) return;

	if (
		($linkedItem.offset().top -
			Math.max($(document).scrollTop(), headerHeight) >=
			window.innerWidth -
				($linkedItem.offset().top +
					$linkedItem.outerHeight() -
					$(document).scrollTop()) &&
			element.dataset.position !== "bottom") ||
		element.dataset.position === "top"
	) {
		$(element).addClass("top");
		if ($(element).find(".list-items").length) {
			$(element).find(".list-items").first().css("max-height", "");
			if (
				$(document).scrollTop() < $("header").outerHeight() + 5 &&
				$linkedItem.offset().top -
					$(document).scrollTop() -
					$(element).outerHeight() <=
					$("header").outerHeight()
			) {
				$(element)
					.find(".list-items")
					.first()
					.css(
						"max-height",
						$(element).find(".list-items").first().outerHeight() -
							40 +
							($linkedItem.offset().top -
								$(document).scrollTop() -
								$(element).outerHeight() -
								($("header").outerHeight() - $(document).scrollTop())),
					);
			} else if (
				$linkedItem.offset().top -
					$(document).scrollTop() -
					$(element).outerHeight() <=
				20
			) {
				$(element)
					.find(".list-items")
					.first()
					.css(
						"max-height",
						$(element).find(".list-items").first().outerHeight() -
							30 +
							($linkedItem.offset().top -
								$(document).scrollTop() -
								$(element).outerHeight()),
					);
			}
		}
	} else {
		$(element).removeClass("top");
		if ($(element).find(".list-items").length) {
			$(element).find(".list-items").first().css("max-height", "");
			if (
				$(window).height() -
					($linkedItem.offset().top +
						$linkedItem.outerHeight() -
						$(document).scrollTop() +
						$(element).outerHeight()) <=
				20
			) {
				$(element)
					.find(".list-items")
					.first()
					.css(
						"max-height",
						$(element).find(".list-items").first().outerHeight() +
							($(window).height() -
								20 -
								($linkedItem.offset().top +
									$linkedItem.outerHeight() -
									$(document).scrollTop() +
									$(element).outerHeight())),
					);
			}
		}
	}
}

function checkForChangedFormData(mutations, element) {
	for (const mutation of mutations) {
		if (mutation.type !== "attributes") continue;

		if (
			mutation.target.classList.contains("remote-rendered") &&
			(!mutation.oldValue || mutation.oldValue.includes("remote-rendering"))
		)
			resizeDropdown(element);

		if (
			mutation.target.classList.contains("is-open") &&
			!mutation.oldValue?.includes("is-open")
		)
			focusFirstInputField(mutation.target);
	}
}

function focusFirstInputField(element) {
	for (const input of element.querySelectorAll('input[type="text"]')) {
		if (DomElementHelpers.isVisible(input)) {
			input.focus();
			input.select();
			break;
		}
	}
}

function monitorNewContents(element) {
	element.classList.add("dcjs-monitor-new-contents");
	const changeObserver = new MutationObserver((m) =>
		checkForChangedFormData(m, element),
	);
	changeObserver.observe(
		element,
		ObserverHelpers.changedClassWithSubtreeConfig,
	);
}

export default function () {
	DataCycle.initNewElements(
		".dropdown-pane:not(.dcjs-monitor-new-contents)",
		(e) => monitorNewContents(e),
	);

	$(document).on(
		"show.zf.dropdown dc:dropdown:resize",
		".dropdown-pane",
		(event) => {
			resizeDropdown(event.currentTarget);
		},
	);
}

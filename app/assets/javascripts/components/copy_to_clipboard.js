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
	/**
	 * The admin panel's COPY button carries no value of its own - it copies the tab's
	 * <code class="formatted-json" data-json="...">, which each tab now delivers through a
	 * lazily loaded turbo frame instead of the <pre class="remote-render"> it used to fill,
	 * so "pre code" no longer matches. The element is also absent until the frame resolves
	 * and stays absent for a tab whose payload is empty, hence the null check.
	 */
	copyValueToClipboard(event) {
		event.preventDefault();
		// Both suppressions stay unconditional, together. The listener is bound to the
		// trigger itself (see setup), so stopPropagation only ever blocked handlers on
		// ancestors — never Swagger UI's own copy handler, which sits on the same element
		// and fires either way. Making it conditional therefore bought nothing and let a
		// trigger that resolves no text bubble to ancestor handlers it never reached before.
		event.stopPropagation();

		let currentTarget = event.currentTarget;
		if (currentTarget.classList.contains("admin-clipboard"))
			currentTarget = currentTarget
				.closest("section.tabs-panel")
				?.querySelector("code.formatted-json");

		if (!currentTarget) return console.warn("nothing to copy");

		let text;
		if ("json" in currentTarget.dataset && currentTarget.dataset.json)
			text = currentTarget.dataset.json;
		else if ("value" in currentTarget.dataset && currentTarget.dataset.value)
			text = currentTarget.dataset.value;
		else if ("value" in currentTarget && currentTarget.value)
			text = currentTarget.value;
		else text = currentTarget.textContent;

		// Icon-only triggers carry no text of their own. In the API reference
		// (Swagger UI) code/curl blocks keep the text in a sibling .microlight/pre,
		// while the per-operation copy button exposes the endpoint path as data-path
		// on .opblock-summary-path.
		if (!text?.trim()) {
			const block = currentTarget.closest(
				".highlight-code, .curl-command, .request-url",
			);
			text = (block || currentTarget.parentElement)
				?.querySelector(".microlight, pre, code, textarea")
				?.textContent?.trim();
		}
		if (!text?.trim())
			text = currentTarget
				.closest(".opblock-summary")
				?.querySelector("[data-path]")
				?.getAttribute("data-path")
				?.trim();

		// Nothing we can read, e.g. a button whose value lives only in a JS prop.
		if (!text) return console.warn("nothing to copy");

		this.writeText(text)
			.then((copied) =>
				copied ? this.showTooltip() : console.warn("copy failed"),
			)
			.catch((error) => console.error(error));
	}
	// Writes text to the clipboard. The async Clipboard API needs a secure context
	// (HTTPS/localhost); over plain HTTP navigator.clipboard is undefined, so fall
	// back to a hidden textarea + execCommand.
	async writeText(text) {
		try {
			if (navigator.clipboard?.writeText) {
				await navigator.clipboard.writeText(text);
				return true;
			}
		} catch {
			// fall through to the legacy path
		}
		try {
			const textarea = document.createElement("textarea");
			textarea.value = text;
			textarea.setAttribute("readonly", "");
			textarea.style.position = "fixed";
			textarea.style.top = "-9999px";
			document.body.appendChild(textarea);
			textarea.select();
			const copied = document.execCommand("copy");
			textarea.remove();
			return copied;
		} catch {
			return false;
		}
	}
	async showTooltip() {
		const tooltip = document.createElement("span");
		tooltip.classList.add("clipboard-notice");
		// A page with its own language switcher (e.g. the OpenAPI/schema reference,
		// where the ?language= locale differs from the account UI locale) can hand us
		// the already-localized notice via data-clipboard-notice on an ancestor, so
		// the feedback follows the switched page language instead of the JS I18n
		// account locale. Everywhere else we fall back to the account translation.
		const override = this.item.closest("[data-clipboard-notice]")?.dataset
			.clipboardNotice;
		tooltip.textContent =
			override?.trim() || (await I18n.translate("actions.copied_to_clipboard"));
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

/**
 * Freezes an attribute's action buttons while one of them is working (#47879, #47881).
 *
 * The suggestion services answer in seconds, not instantly, so a second click during that window
 * is easy to make and expensive to get wrong: every one of these buttons writes into the same form,
 * and an import arriving mid-import either loses its own values or overwrites the ones just
 * written.
 *
 * The button that was clicked goes through DataCycle.disableElement, i.e. the data-disable-with
 * path every remote button in the backend already uses, and shows a spinner in place of its icon.
 *
 * The others cannot: that helper works by adding .disabled, and _base.scss styles
 * .copy-attribute-to-all.disabled by showing that button's own .loading-icon and hiding its
 * .copy-icon -- so every copy button in the form would sit there spinning for work it is not
 * doing. It also leaves the element itself operable (Rails.disableElement plus the class; the
 * disabled attribute is set on descendants only), and .translate-inline-button is an <a>
 * (editors/_string.html.erb), which has no disabled attribute to set. Hence a class of this
 * helper's own, plus aria-disabled and the attribute where the element takes one.
 */
const ACTION_BUTTON_SELECTOR = [
	".pixie-generate-button",
	".copy-attribute-to-all",
	".translate-inline-button",
	".ai-lector-dropdown-button",
].join(", ");

const SPINNER =
	'<i class="fa fa-spinner fa-spin fa-fw" aria-hidden="true"></i>';

const BusyButtons = {
	/**
	 * @param button [HTMLElement|null] the button that was clicked, which gets the spinner
	 * @param container [HTMLElement] where the buttons to freeze live; the clicked button's form by
	 *   default, which in the upload mask is the one file being edited
	 * @param except [Array<HTMLElement>] buttons to leave operable. A frozen button ignores
	 *   .click(), so a caller that drives another button itself -- "apply to all files" clicks the
	 *   wand beside it for the file being edited -- has to name it here or that click is dropped.
	 * @return [Function] releases exactly what this call froze, and nothing that was already frozen
	 */
	hold(button, { container, except = [] } = {}) {
		const scope = container ?? button?.closest("form") ?? document.body;
		const keep = [button, ...except];
		const others = [...scope.querySelectorAll(ACTION_BUTTON_SELECTOR)].filter(
			(element) => !keep.includes(element) && BusyButtons.deactivate(element),
		);

		if (button) DataCycle.disableElement(button, SPINNER);

		return () => {
			if (button) DataCycle.enableElement(button);
			for (const element of others) BusyButtons.reactivate(element);
		};
	},

	/**
	 * @return [Boolean] whether this call is the one that froze the element -- a button already
	 *   frozen by an outer hold stays that way and is left to it
	 */
	deactivate(element) {
		if (element.classList.contains("dc-inactive")) return false;

		element.classList.add("dc-inactive");
		element.setAttribute("aria-disabled", "true");

		// pointer-events alone still leaves a focused button operable by keyboard; the flag records
		// that the attribute was ours to remove, so an already disabled button is not enabled here
		if ("disabled" in element && !element.disabled) {
			element.disabled = true;
			element.dataset.dcInactiveDisabled = "true";
		}

		return true;
	},

	reactivate(element) {
		element.classList.remove("dc-inactive");
		element.removeAttribute("aria-disabled");

		if (element.dataset.dcInactiveDisabled) {
			element.disabled = false;
			delete element.dataset.dcInactiveDisabled;
		}
	},
};

export default BusyButtons;

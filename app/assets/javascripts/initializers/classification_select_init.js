import SimpleSelect2 from "../components/simple_select2";
import AsyncSelect2 from "../components/async_select2";
import CheckBoxSelector from "../components/check_box_selector";
import RadioButtonSelector from "../components/radio_button_selector";

export default function () {
	// FIXME: remove when https://github.com/select2/select2/issues/5993 is resolved
	$(document).on("select2:open", (e) => {
		const searchField = e.target.parentNode.querySelector(
			".select2-search__field",
		);
		if (searchField) searchField.focus();
	});

	DataCycle.initNewElements(
		".classification-checkbox-list:not(.dcjs-check-box-selector)",
		(e) => new CheckBoxSelector(e).init(),
	);

	DataCycle.initNewElements(
		".classification-radiobutton-list:not(.dcjs-radio-button-selector)",
		(e) => new RadioButtonSelector(e).init(),
	);

	DataCycle.initNewElements(
		".auto-tagging-button:not(.dcjs-auto-tagging)",
		initAutoTagging.bind(this),
	);
	DataCycle.initNewElements(".async-select:not(.dcjs-select2)", (e) =>
		new AsyncSelect2(e).init(),
	);
	DataCycle.initNewElements(
		".single-select:not(.dcjs-select2), .multi-select:not(.dcjs-select2)",
		(e) => new SimpleSelect2(e).init(),
	);
}

function initAutoTagging(element) {
	element.classList.add("dcjs-auto-tagging");

	$(element).on("click", (event) => {
		$(event.target)
			.closest(".form-element")
			.find("> .v-select > select")
			.val(null)
			.trigger("change");
	});
}

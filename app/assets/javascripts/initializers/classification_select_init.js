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

	DataCycle.registerAddCallback(
		".classification-checkbox-list",
		"check-box-selector",
		(e) => new CheckBoxSelector(e).init(),
	);

	DataCycle.registerAddCallback(
		".classification-radiobutton-list",
		"radio-button-selector",
		(e) => new RadioButtonSelector(e).init(),
	);

	DataCycle.registerAddCallback(
		".auto-tagging-button",
		"auto-tagging",
		initAutoTagging.bind(this),
	);
	DataCycle.registerAddCallback(".async-select", "select2", (e) =>
		new AsyncSelect2(e).init(),
	);
	DataCycle.registerAddCallback(
		".single-select, .multi-select",
		"select2",
		(e) => new SimpleSelect2(e).init(),
	);
}

function initAutoTagging(element) {
	$(element).on("click", (event) => {
		$(event.target)
			.closest(".form-element")
			.find("> .v-select > select")
			.val(null)
			.trigger("change");
	});
}

import CollectionFilter from "../components/collection_filter";
import CollectionForm from "../components/collection_form";
import CollectionOrderButton from "../components/collection_order_button";

export default function () {
	function init() {
		DataCycle.initNewElements(
			".dropdown-pane.watch-lists:not(.dcjs-collection-filter)",
			(e) => new CollectionFilter(e),
		);
		DataCycle.initNewElements(
			".add-items-to-watch-list-form:not(.dcjs-collection-form)",
			(e) => new CollectionForm(e),
		);
		DataCycle.initNewElements(
			".manual-order-button:not(.dcjs-collection-order-button)",
			(e) => new CollectionOrderButton(e),
		);
	}
	init();
}

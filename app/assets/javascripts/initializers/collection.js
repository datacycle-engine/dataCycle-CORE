import CollectionFilter from "../components/collection_filter";
import CollectionForm from "../components/collection_form";
import CollectionOrderButton from "../components/collection_order_button";

export default function () {
	function init() {
		DataCycle.registerAddCallback(
			".dropdown-pane.watch-lists",
			"collection-filter",
			(e) => new CollectionFilter(e),
		);
		DataCycle.registerAddCallback(
			".add-items-to-watch-list-form",
			"collection-form",
			(e) => new CollectionForm(e),
		);
		DataCycle.registerAddCallback(
			".manual-order-button",
			"collection-order-button",
			(e) => new CollectionOrderButton(e),
		);
	}
	init();
}

import LoadMoreLinkedButton from "../components/ajax_buttons/load_more_linked_button";

export default function () {
	DataCycle.initNewElements(
		".load-more-linked-contents:not(.dcjs-load-more-linked)",
		(e) => new LoadMoreLinkedButton(e),
	);
}

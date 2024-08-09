import LoadMoreLinkedButton from "../components/ajax_buttons/load_more_linked_button";

export default function () {
	DataCycle.registerAddCallback(
		".load-more-linked-contents",
		"load-more-linked",
		(e) => new LoadMoreLinkedButton(e),
	);
}

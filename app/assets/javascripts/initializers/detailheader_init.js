import ShowMoreLinkToggler from "../components/togglers/show_more_link_toggler";
import CopyToClipboard from "../components/copy_to_clipboard";

export default function () {
	DataCycle.registerAddCallback(
		".copy-to-clipboard",
		"copy-clipboard",
		(e) => new CopyToClipboard(e),
	);

	DataCycle.registerAddCallback(
		".show-more > .show-more-link",
		"show-more-link-toggler",
		(e) => new ShowMoreLinkToggler(e),
	);
}

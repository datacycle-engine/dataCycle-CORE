import ObjectBrowser from "./../components/object_browser";

export default function () {
	DataCycle.registerAddCallback(
		".object-browser",
		"object-browser",
		(e) => new ObjectBrowser(e),
	);
}

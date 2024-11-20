import OembedPreview from "../components/oembed_preview";

export default function () {
	DataCycle.registerLazyAddCallback(
		"input.oembed-input",
		"oembed-preview",
		(e) => new OembedPreview(e),
	);
}

import AssetSelector from "./../components/asset_selector";
const AssetUploader = () => import("./../components/asset_uploader");

function initAssetUploader(item) {
	item.classList.add("dcjs-asset-uploader");
	AssetUploader().then((mod) => new mod.default(item));
}

export default function () {
	DataCycle.initNewElements(
		".asset-selector-reveal:not(.dcjs-asset-selector)",
		(e) => new AssetSelector(e),
	);

	DataCycle.initNewElements(
		".asset-upload-reveal:not(.dcjs-asset-uploader)",
		initAssetUploader.bind(this),
	);

	DataCycle.initNewElements(
		".download-content-form:not(.dcjs-download-content-form)",
		initDownloadContentReveal.bind(this),
	);

	function initDownloadContentReveal(element) {
		element.classList.add("dcjs-download-content-form");
		toggleAssetVersion(element);
		toggleAssetTransformation(element);

		$(element)
			.find(".active.serialize_formats input")
			.on("change", (event) => {
				event.preventDefault();
				toggleAssetVersion(element);
			});

		$(element)
			.find(".active.version input")
			.on("change", (event) => {
				event.preventDefault();
				toggleAssetTransformation(element);
			});
	}

	function toggleAssetVersion(element) {
		if (
			$(element)
				.find('.active.serialize_formats :input[value="asset"]')
				.is(":checked")
		) {
			$(element).find(".active.version").removeClass("hidden");
		} else {
			$(element).find(".active.version").addClass("hidden");
		}

		toggleAssetTransformation(element);
	}

	function toggleAssetTransformation(element) {
		const selectedVal = $(element)
			.find('.active.version :input[name="version"]:checked')
			.val();
		$(element).find(".active.transformation").addClass("hidden");
		if (
			$(element)
				.find('.active.serialize_formats :input[value="asset"]')
				.is(":checked")
		) {
			$(element)
				.find(`.active.transformation.${selectedVal}`)
				.removeClass("hidden");
		}
	}
}

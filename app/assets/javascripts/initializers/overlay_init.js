import OverlayTypeCheckbox from "../components/overlay_type_checkbox";

export default function () {
	DataCycle.initNewElements(
		".dc-overlay-type:not(.dcjs-overlay-type-checkbox)",
		(e) => new OverlayTypeCheckbox(e),
	);
}

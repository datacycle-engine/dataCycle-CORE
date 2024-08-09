import TourSprungEditor from "./../components/tour_sprung_editor";
import MapLibreGlViewer from "./../components/maplibre_gl_viewer";
import MapLibreGlEditor from "./../components/maplibre_gl_editor";
import MapLibreGlDashboard from "./../components/maplibre_gl_dashboard";
import DomElementHelpers from "../helpers/dom_element_helpers";
import ReverseGeocoding from "../components/reverse_geocoding";

const mapEditors = {
	TourSprung: TourSprungEditor,
	MapLibreGl: MapLibreGlEditor,
};

export default function () {
	DataCycle.registerLazyAddCallback(
		".geographic-map",
		"map",
		initMap.bind(this),
	);

	DataCycle.registerLazyAddCallback(
		".reverse-geocode-button",
		"reverse-geocoding",
		(e) => new ReverseGeocoding(e),
	);
}

function initMap(item) {
	if (item.classList.contains("editor")) {
		const editor = DomElementHelpers.parseDataAttribute(
			item.dataset.mapOptions,
		).editor;

		if (
			Object.hasOwn(mapEditors, editor) &&
			mapEditors[editor].isAllowedType(item.dataset.type)
		)
			return new mapEditors[editor](item).setup();
		return new MapLibreGlEditor(item).setup();
	}

	if (item.classList.contains("dashboard"))
		return new MapLibreGlDashboard(item).setup();

	return new MapLibreGlViewer(item).setup();
}

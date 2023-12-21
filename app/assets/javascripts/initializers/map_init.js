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
	const intersectionObserver = new IntersectionObserver(initMap.bind(this), {
		rootMargin: "0px 0px 50px 0px",
		threshold: 0.1,
	});

	DataCycle.initNewElements(".geographic-map:not(.dcjs-map)", (e) => {
		e.classList.add("dcjs-map");
		intersectionObserver.observe(e);
	});

	DataCycle.initNewElements(
		".reverse-geocode-button:not(.dcjs-reverse-geocoding)",
		(e) => new ReverseGeocoding(e),
	);
}

function initMap(entries, observer) {
	for (const entry of entries) {
		if (!entry.isIntersecting) continue;

		const item = entry.target;
		observer.unobserve(item);

		if (item.classList.contains("editor")) {
			const editor = DomElementHelpers.parseDataAttribute(
				item.dataset.mapOptions,
			).editor;

			if (
				Object.hasOwn(mapEditors, editor) &&
				mapEditors[editor].isAllowedType(item.dataset.type)
			)
				return new mapEditors[editor](item).setup();
			else return new MapLibreGlEditor(item).setup();
		} else if (item.classList.contains("dashboard")) {
			return new MapLibreGlDashboard(item).setup();
		} else {
			return new MapLibreGlViewer(item).setup();
		}
	}
}

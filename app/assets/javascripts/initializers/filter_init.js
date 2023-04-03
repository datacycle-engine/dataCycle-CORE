import DashboardFilter from "../components/dashboard_filter";
import GeolocationButton from "../components/geolocation_button";

export default function () {
	DataCycle.initNewElements(
		"#search-form:not(.dcjs-dashboard-filter)",
		(e) => new DashboardFilter(e),
	);
	DataCycle.initNewElements(
		".geolocation-button:not(.dcjs-geolocation-button)",
		(e) => new GeolocationButton(e),
	);
}

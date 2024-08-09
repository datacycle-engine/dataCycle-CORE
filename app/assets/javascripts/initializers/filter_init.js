import DashboardFilter from "../components/dashboard_filter";
import GeolocationButton from "../components/geolocation_button";

export default function () {
	DataCycle.registerAddCallback(
		"#search-form",
		"dashboard-filter",
		(e) => new DashboardFilter(e),
	);
	DataCycle.registerAddCallback(
		".geolocation-button",
		"geolocation-button",
		(e) => new GeolocationButton(e),
	);
}

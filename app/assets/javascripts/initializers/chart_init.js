const Chart = () => import("../components/chart");
const ElevationProfileChart = () =>
	import("../components/elevation_profile_chart");

function initChartJs(element) {
	Chart().then((mod) => new mod.default(element));
}

function initElevationProfileChartJs(element) {
	ElevationProfileChart().then((mod) => new mod.default(element));
}

export default function () {
	DataCycle.registerLazyAddCallback(
		".dc-chart",
		"chart",
		initChartJs.bind(this),
	);

	DataCycle.registerLazyAddCallback(
		".dc-elevation-profile-chart",
		"elevation-profile-chart",
		initElevationProfileChartJs.bind(this),
	);
}

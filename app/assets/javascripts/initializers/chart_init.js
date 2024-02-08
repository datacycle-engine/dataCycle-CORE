const Chart = () => import("../components/chart");
const ElevationProfileChart = () =>
	import("../components/elevation_profile_chart");

function initChartJs(element) {
	element.classList.add("dcjs-chart");
	Chart().then((mod) => new mod.default(element));
}

function checkForNewVisibleElements(entries, observer) {
	for (const entry of entries) {
		if (!entry.isIntersecting) continue;

		console.log("checkForNewVisibleElements");

		observer.unobserve(entry.target);
		ElevationProfileChart().then((mod) => new mod.default(entry.target));
	}
}

export default function () {
	DataCycle.initNewElements(
		".dc-chart:not(.dcjs-chart)",
		initChartJs.bind(this),
	);

	const intersectionObserver = new IntersectionObserver(
		checkForNewVisibleElements,
		{
			rootMargin: "0px 0px 50px 0px",
			threshold: 0.1,
		},
	);

	DataCycle.initNewElements(
		".dc-elevation-profile-chart:not(.dcjs-elevation-profile-chart)",
		(e) => {
			e.classList.add("dcjs-elevation-profile-chart");
			intersectionObserver.observe(e);
		},
	);
}

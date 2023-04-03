const Chart = () => import("../components/chart");

function initChartJs(element) {
	element.classList.add("dcjs-chart");
	Chart().then((mod) => new mod.default(element));
}

export default function () {
	DataCycle.initNewElements(
		".dc-chart:not(.dcjs-chart)",
		initChartJs.bind(this),
	);
}

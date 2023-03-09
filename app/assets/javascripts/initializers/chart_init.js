const Chart = () => import("../components/chart");

function initChartJs(element) {
	Chart().then((mod) => new mod.default(element));
}

export default function () {
	DataCycle.initNewElements(".dc-chart", initChartJs.bind(this));
}

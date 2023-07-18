import DashboardPagination from "../components/dashboard_pagination";
import DashboardTreeLoader from "../components/dashboard_tree_loader";
import DashboardContentLink from "../components/dashboard_content_link";

export default function () {
	DataCycle.initNewElements(
		"li.grid-item:not(.dcjs-dashboard-content-link), li.list-item:not(.dcjs-dashboard-content-link)",
		(e) => new DashboardContentLink(e),
	);
	DataCycle.initNewElements(
		".pagination-link:not(.dcjs-dashboard-pagination)",
		(e) => new DashboardPagination(e),
	);
	DataCycle.initNewElements(
		".tree-link:not(.dcjs-dashboard-tree-loader)",
		(e) => new DashboardTreeLoader(e),
	);
}

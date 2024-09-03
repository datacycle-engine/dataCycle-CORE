import DashboardPagination from "../components/dashboard_pagination";
import DashboardTreeLoader from "../components/dashboard_tree_loader";
import DashboardContentLink from "../components/dashboard_content_link";

export default function () {
	DataCycle.registerAddCallback(
		"li.grid-item, li.list-item",
		"dashboard-content-link",
		(e) => new DashboardContentLink(e),
	);
	DataCycle.registerAddCallback(
		".pagination-link",
		"dashboard-pagination",
		(e) => new DashboardPagination(e),
	);
	DataCycle.registerAddCallback(
		".tree-link",
		"dashboard-tree-loader",
		(e) => new DashboardTreeLoader(e),
	);
}

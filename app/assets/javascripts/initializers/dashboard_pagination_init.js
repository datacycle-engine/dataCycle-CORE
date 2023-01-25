import DashboardPagination from '../components/dashboard_pagination';
import DashboardTreeLoader from '../components/dashboard_tree_loader';

export default function () {
  DataCycle.initNewElements('.pagination-link:not(.dcjs-dashboard-pagination)', e => new DashboardPagination(e));

  DataCycle.initNewElements('.tree-link:not(.dcjs-dashboard-tree-loader)', e => new DashboardTreeLoader(e));
}

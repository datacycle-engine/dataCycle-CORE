import DashboardPagination from '../components/dashboard_pagination';
import DashboardTreeLoader from '../components/dashboard_tree_loader';

export default function () {
  for (const paginationLink of document.getElementsByClassName('pagination-link')) {
    new DashboardPagination(paginationLink);
  }

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('pagination-link') && !e.classList.contains('dcjs-dashboard-pagination'),
    e => new DashboardPagination(e)
  ]);

  for (const paginationLink of document.getElementsByClassName('tree-link')) {
    new DashboardTreeLoader(paginationLink);
  }

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('tree-link') && !e.classList.contains('dcjs-dashboard-tree-loader'),
    e => new DashboardTreeLoader(e)
  ]);
}

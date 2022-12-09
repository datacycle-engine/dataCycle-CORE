import DashboardFilter from '../components/dashboard_filter';

export default function () {
  const searchForm = document.getElementById('search-form');
  if (searchForm) new DashboardFilter(searchForm);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.id == 'search-form' && !e.classList.contains('dcjs-dashboard-filter'),
    e => new DashboardFilter(e)
  ]);
}

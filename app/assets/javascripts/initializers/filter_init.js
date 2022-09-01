import DashboardFilter from '../components/dashboard_filter';

export default function () {
  const searchForm = document.getElementById('search-form');
  if (searchForm) new DashboardFilter(searchForm);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.id == 'search-form' && !e.hasOwnProperty('dcDashboardFilter'),
    e => new DashboardFilter(e)
  ]);
}

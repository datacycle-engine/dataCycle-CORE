import DashboardFilter from '../components/dashboard_filter';

export default function () {
  DataCycle.initNewElements('#search-form:not(.dcjs-dashboard-filter)', e => new DashboardFilter(e));
}

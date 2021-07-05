import DashboardFilter from '../components/dashboard_filter';

export default function () {
  if ($('.filters').length > 0) {
    init();
  }

  function init(element = document) {
    $(element)
      .find('#search-form')
      .each((_index, elem) => {
        new DashboardFilter(elem);
      });
  }
}

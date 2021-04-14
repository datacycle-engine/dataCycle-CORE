// Filter
const DashboardFilter = require('../components/dashboard_filter');

module.exports.initialize = function ($) {
  if ($('#primary_nav_wrap').length > 0) {
    init();
  }

  function init(element = document) {
    $(element)
      .find('#search-form')
      .each((_index, elem) => {
        new DashboardFilter(elem);
      });
  }
};

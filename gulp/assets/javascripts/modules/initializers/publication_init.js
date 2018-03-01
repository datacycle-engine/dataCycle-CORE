let Spinner = require('./../components/loading_spinner');

module.exports.initialize = () => {

  if ($('.publications-list').length) {
    let loading = false;
    let page = 1;
    let pages = $('.publications-list').data('pages');
    $(document).on('scroll', event => {
      if (!loading && ($(window).scrollTop() + $(window).height()) >= ($(document).height() - 100) && page < pages) {
        page += 1;
        let form_data = $('#search-form').serializeArray();
        let url = $('#search-form').prop('action');
        let method = $('#search-form').prop('method');
        form_data.push({
          name: 'infinite_scroll',
          value: true
        }, {
          name: 'page',
          value: page
        }, {
          name: 'last_month',
          value: $('.publication-month').last().data('month-year')
        }, {
          name: 'last_day',
          value: $('.publication-day').last().data('day')
        });
        loading = true;
        let spinner = new Spinner($('.publications-list'));
        spinner.show();
        $.ajax({
          url: url,
          method: method,
          data: form_data,
          dataType: 'script'
        }).done((data) => {
          loading = false;
          spinner.hide();
        });
      }
    });
  }

};

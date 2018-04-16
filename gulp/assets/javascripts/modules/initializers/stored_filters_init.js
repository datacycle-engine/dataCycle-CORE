let Spinner = require('./../components/loading_spinner');

module.exports.initialize = () => {

  if ($('.search-history-list').length) {
    let loading = false;
    let page = 1;
    let pages = $('.search-history-list').data('pages');
    let load_more = function () {
      page += 1;
      let form_data = [{
        name: 'infinite_scroll',
        value: true
      }, {
        name: 'page',
        value: page
      }, {
        name: 'last_day',
        value: $('.stored-search-day').last().data('day')
      }];
      loading = true;
      let spinner = new Spinner($('.search-history-list'));
      spinner.show();
      $.ajax({
        url: '',
        method: 'GET',
        data: form_data,
        dataType: 'script'
      }).done((data) => {
        loading = false;
        spinner.hide();
        if (page < pages && !loading && ($('.search-history-list .content-item').last().offset().top + $('.search-history-list .content-item').last().outerHeight() + 80) < $(window).height()) {
          load_more();
        }
      });
    };

    if (page < pages && !loading && ($('.search-history-list .content-item').last().offset().top + $('.search-history-list .content-item').last().outerHeight() + 80) < $(window).height()) {
      load_more();
    }

    $(document).on('scroll', event => {
      if (!loading && ($(window).scrollTop() + $(window).height()) >= ($(document).height() - 100) && page < pages) {
        load_more();
      }
    });
  }

};

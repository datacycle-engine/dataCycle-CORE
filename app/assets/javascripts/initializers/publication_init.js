import loadingIcon from '../templates/loadingIcon';

export default function () {
  if ($('.publications-list').length) {
    let loading = false;
    let page = 1;
    let pages = $('.publications-list').data('pages');
    let load_more = function () {
      page += 1;
      var form_data = $('#search-form').serializeArray();
      var url = $('#search-form').prop('action');
      var method = $('#search-form').prop('method');
      form_data.push(
        {
          name: 'infinite_scroll',
          value: true
        },
        {
          name: 'page',
          value: page
        },
        {
          name: 'last_year',
          value: $('.publication-year').last().data('year')
        },
        {
          name: 'last_month',
          value: $('.publication-month').last().data('month')
        },
        {
          name: 'last_day',
          value: $('.publication-day').last().data('day')
        }
      );
      loading = true;

      $('.publications-list').append(loadingIcon());

      DataCycle.httpRequest({
        url: url,
        method: method,
        data: form_data,
        dataType: 'script'
      }).then(_data => {
        loading = false;
        $('.publications-list .loading').remove();
        if (
          page < pages &&
          !loading &&
          $('.publication-content').last().offset().top + $('.publication-content').last().outerHeight() + 80 <
            $(window).height()
        ) {
          load_more();
        }
      });
    };

    if (
      page < pages &&
      !loading &&
      $('.publication-content').last().offset().top + $('.publication-content').last().outerHeight() + 80 <
        $(window).height()
    ) {
      load_more();
    }

    $(document).on('scroll', _event => {
      if (!loading && $(window).scrollTop() + $(window).height() >= $(document).height() - 100 && page < pages) {
        load_more();
      }
    });
  }
}

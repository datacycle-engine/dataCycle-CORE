import loadingIcon from '../templates/loadingIcon';

export default function () {
  if ($('.search-history-list').length) {
    let loading = false;
    let page = 1;
    let pages = $('.search-history-list').data('pages');
    let load_more = function () {
      page += 1;
      let form_data = [
        {
          name: 'infinite_scroll',
          value: true
        },
        {
          name: 'page',
          value: page
        },
        {
          name: 'last_day',
          value: $('.stored-search-day').last().data('day')
        }
      ];
      loading = true;

      $('.search-history-list').append(loadingIcon());

      DataCycle.httpRequest({
        url: '',
        method: 'GET',
        data: form_data,
        dataType: 'script'
      }).then(_data => {
        loading = false;
        $('.search-history-list .loading').remove();

        if (
          page < pages &&
          !loading &&
          $('.search-history-list .content-item').last().offset().top +
            $('.search-history-list .content-item').last().outerHeight() +
            80 <
            $(window).height()
        ) {
          load_more();
        }
      });
    };

    if (
      page < pages &&
      !loading &&
      $('.search-history-list .content-item').last().offset().top +
        $('.search-history-list .content-item').last().outerHeight() +
        80 <
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

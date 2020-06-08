module.exports.initialize = function ($) {
  let input_timeout = null;
  $('input.watch-list-filter-param').on('input', event => {
    event.preventDefault();

    if (input_timeout !== null) {
      clearTimeout(input_timeout);
    }
    input_timeout = setTimeout(() => {
      let watchList = $(event.target).closest('.dropdown-pane.watch-lists');
      let query = filterWatchList(watchList);

      $('.dropdown-pane.watch-lists')
        .not(watchList)
        .each((_, elem) => filterWatchList(elem, query));
    }, 500);
  });

  $('button.reset-watch-list-filter').on('click', event => {
    event.preventDefault();

    let watchList = $(event.currentTarget).closest('.dropdown-pane.watch-lists');
    $(event.currentTarget).siblings('.watch-list-filter-param').val(null);

    let query = filterWatchList(watchList);
    $('.dropdown-pane.watch-lists')
      .not(watchList)
      .each((_, elem) => filterWatchList(elem, query));
  });

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    filterWatchList($(event.target).closest('.dropdown-pane.watch-lists'));
  });

  $(document).on('dc:watchlist:calculate_even', '*', event => {
    event.stopImmediatePropagation();

    if ($(event.target).siblings('.visible').addBack().index($(event.target)) % 2 == 0)
      $(event.currentTarget).addClass('even');
  });

  function filterWatchList(watchList, query = null) {
    $.rails.disableFormElement($(watchList).find('.reset-watch-list-filter'));
    let q;
    if (query !== null && query !== undefined) {
      q = query;
      $(watchList).find('input.watch-list-filter-param').val(q);
    } else {
      q = $(watchList).find('input.watch-list-filter-param').val();
    }

    let value = (q || '').trim().toLowerCase();

    if (value.length) {
      $(watchList)
        .find('> .list-items > li')
        .removeClass('visible even')
        .filter('[data-name*="' + value + '"]')
        .addClass('visible')
        .filter(':even')
        .addClass('even');
      $(watchList).find('.reset-watch-list-filter:hidden').fadeIn(100);
      $.rails.enableFormElement($(watchList).find('.reset-watch-list-filter'));
    } else {
      $(watchList).find('> .list-items > li').removeClass('even').addClass('visible').filter(':even').addClass('even');
      $(watchList).find('.reset-watch-list-filter:visible').fadeOut(100);
      $.rails.enableFormElement($(watchList).find('.reset-watch-list-filter'));
    }

    if ($(watchList).is(':visible')) $(watchList).trigger('dc:dropdown:resize');

    return q;
  }
};

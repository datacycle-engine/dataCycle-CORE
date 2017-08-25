// Merklisten
module.exports.initialize = function () {

  $(document).on('click', '.add-to-watchlist-link, .remove-from-watchlist-link', function (ev) {
    ev.preventDefault();
    var $parent = $(this).closest('.watch-list-item');
    var $change_link = $parent.find('.change-link a');

    $.get($(this).attr('href'), function (data) {
      if ($(this).hasClass('add-to-watchlist-link')) {
        $parent.find('.watchlist-headline').html(data.headline);
      } else if ($(this).hasClass('remove-from-watchlist-link')) {
        $parent.find('.watchlist-headline').html('<a class="add-to-watchlist-link" href="' + data.url + '">' + data.headline + '</a>');
      }

      $parent.find('.check').toggleClass('checked');
      $change_link.toggleClass('add-to-watchlist-link remove-from-watchlist-link');
      $change_link.find('.fa').toggleClass('fa-plus-circle fa-minus-circle');
      $change_link.attr('href', data.url);

      var $watch_lists_link = $parent.closest('.watch-lists').siblings('.watch-lists-link').find('.fa');

      if (data.count > 0) $watch_lists_link.removeClass('fa-bookmark-o').addClass('fa-bookmark');
      else $watch_lists_link.removeClass('fa-bookmark').addClass('fa-bookmark-o');

    }.bind(this));
  });

  $(document).on('submit', '.add-watchlist-form', function (ev) {
    ev.preventDefault();

    $.post($(this).attr('action'), $(this).serializeArray(), function (data) {
      var html = '<li><span class="watch-list-item">';
      html += '<span class="check"><i class="fa fa-check" aria-hidden="true"></i></span>';
      html += '<span class="watchlist-headline">';
      html += '<a class="add-to-watchlist-link" href="' + data.url + '">' + data.headline;
      html += '</a></span><span class="change-link">';
      html += '<a class="add-to-watchlist-link" href="' + data.url + '">';
      html += '<i class="fa fa-plus-circle" aria-hidden="true"></i></a></span></span></li>';

      $target = $(this).closest('.add-watchlist').first();
      $target.before(html);

      $('.grid-item .add-watchlist').not($target).each(function () {
        $(this).before(html);
      });

      this.reset();
    }.bind(this));
  });

};
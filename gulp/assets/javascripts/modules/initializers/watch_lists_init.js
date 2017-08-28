// Merklisten
module.exports.initialize = function () {

  $(document).on('click', '.watch-list-item .add-to-watchlist-link, .watch-list-item .remove-from-watchlist-link', function (ev) {
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

      $('.add-watchlist').each(function () {
        var id = $(this).find('input#hashable_id').val();
        var type = $(this).find('input#hashable_type').val();
        var html = '<li><span class="watch-list-item">';
        html += '<span class="check"><i class="fa fa-check" aria-hidden="true"></i></span>';
        html += '<span class="watchlist-headline">';
        html += '<a class="add-to-watchlist-link" href="' + data.url + '/addItem?hashable_id=' + id + '&hashable_type=' + type + '">' + data.headline;
        html += '</a></span><span class="change-link">';
        html += '<a class="add-to-watchlist-link" href="' + data.url + '/addItem?hashable_id=' + id + '&hashable_type=' + type + '">';
        html += '<i class="fa fa-plus-circle" aria-hidden="true"></i></a></span></span></li>';
        $(this).before(html);
      });

      var menu_html = '<li><span class="watch-list-item"><span class="watchlist-headline">';
      menu_html += '<a class="watchlist-link" href="' + data.url + '">' + data.headline + '</a>';
      menu_html += '</span></span></li>';

      $('.add-watchlist-to-menu').before(menu_html);

      this.reset();
    }.bind(this));
  });

};
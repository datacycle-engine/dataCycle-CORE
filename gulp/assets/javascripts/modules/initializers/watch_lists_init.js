// Merklisten
module.exports.initialize = function () {

  $(document).on('click', '.watch-list-item .add-to-watchlist-link, .watch-list-item .remove-from-watchlist-link', function (ev) {
    ev.preventDefault();
    var $parent = $(this).closest('.watch-list-item');
    var $change_link = $parent.find('.change-link a');

    $.get($(this).attr('href'), function (data) {
      if ($(this).hasClass('add-to-watchlist-link')) {
        $parent.find('.watchlist-headline').html(data.headline);
        $(this).on('click', check_confirmation);
      } else if ($(this).hasClass('remove-from-watchlist-link')) {
        $parent.find('.watchlist-headline').html('<a class="add-to-watchlist-link" href="' + data.url + '">' + data.headline + '</a>');
      }

      $parent.find('.check').toggleClass('checked');
      $change_link.toggleClass('add-to-watchlist-link remove-from-watchlist-link confirm');
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

  //  Confirmation to Delete Watchlists or Watchlist Entries

  $('a.confirm').on('click', check_confirmation);

  function check_confirmation(ev, options) {
    options = options || {};
    if (options.done) {
      $(this).off(ev);
      $(this)[0].click();
    } else {
      ev.stopPropagation();
      ev.preventDefault();
      confirm_delete(this, ev);
    }
  };

  function confirm_delete(elem, event) {
    var $confirmation = $('.confirmation.watchlist-dialog');
    var text = $(elem).data('confirmation-text');
    if ($confirmation.length > 0) {
      $confirmation.find('.text').html(text);
    } else {
      $('.off-canvas-wrapper').append(render_confirmation(text));
      $confirmation = $('.confirmation.watchlist-dialog');
    }
    var left = event.pageX - $confirmation.width() + 8;
    var top = event.pageY - $confirmation.height() - 40;

    $confirmation.css({
      'left': left,
      'top': top
    });

    $confirmation.show();
    $confirmation.off('click', '.cancel-confirmation').on('click', '.cancel-confirmation', function (ev) {
      ev.preventDefault();
      $confirmation.hide();
    });

    $confirmation.off('click', '.accept-confirmation').on('click', '.accept-confirmation', function (ev) {
      ev.preventDefault();
      $confirmation.hide();
      $(elem).triggerHandler('click', {
        done: true
      });
    });
  };

  function render_confirmation(text) {
    var html = '<div class="confirmation watchlist-dialog">';
    html += '<span class="text">' + text + '</span>';
    html += '<button class="button accept-confirmation">Ok</button>';
    html += '<button class="button cancel-confirmation">Abbrechen</button>';
    html += '</div>';
    return html;
  };

};
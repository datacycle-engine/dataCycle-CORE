// Dropdown Pane Overflow Fix
module.exports.initialize = function () {

  $(document).on('show.zf.dropdown', '.dropdown-pane.bottom', event => {
    let linked_item = $('[data-toggle="' + $(event.currentTarget).prop('id') + '"]');

    if ((linked_item.offset().top + linked_item.outerHeight() - $(document).scrollTop() + $(event.currentTarget).outerHeight() + 20) >= $(window).height() && (linked_item.offset().top - $(document).scrollTop()) > ($(window).height() - (linked_item.offset().top - $(document).scrollTop() + linked_item.outerHeight()))) {
      $(event.currentTarget).addClass('align-top');

      if ($(event.currentTarget).children('.list-items').length) {
        $(event.currentTarget).children('.list-items').first().css('max-height', '');

        if ($(document).scrollTop() < ($('header').outerHeight() + 5) && (linked_item.offset().top - $(document).scrollTop() - $(event.currentTarget).outerHeight()) <= ($('header').outerHeight())) {
          $(event.currentTarget).children('.list-items').first().css('max-height', $(event.currentTarget).children('.list-items').first().outerHeight() - 40 + (linked_item.offset().top - $(document).scrollTop() - $(event.currentTarget).outerHeight() - ($('header').outerHeight() - $(document).scrollTop())));
        } else if ((linked_item.offset().top - $(document).scrollTop() - $(event.currentTarget).outerHeight()) <= 20) {
          $(event.currentTarget).children('.list-items').first().css('max-height', $(event.currentTarget).children('.list-items').first().outerHeight() - 30 + (linked_item.offset().top - $(document).scrollTop() - $(event.currentTarget).outerHeight()));
        }
      }
    } else {
      $(event.currentTarget).removeClass('align-top');
      if ($(event.currentTarget).children('.list-items').length) {
        $(event.currentTarget).children('.list-items').first().css('max-height', '');

        if (($(window).height() - (linked_item.offset().top + linked_item.outerHeight() - $(document).scrollTop() + $(event.currentTarget).outerHeight())) <= 20) {
          $(event.currentTarget).children('.list-items').first().css('max-height', $(event.currentTarget).children('.list-items').first().outerHeight() + ($(window).height() - 20 - (linked_item.offset().top + linked_item.outerHeight() - $(document).scrollTop() + $(event.currentTarget).outerHeight())));
        }
      }
    }
  });

};

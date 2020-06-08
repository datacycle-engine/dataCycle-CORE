// Dropdown Pane Overflow Fix
module.exports.initialize = function ($) {
  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    let dropdownParent = $(event.target).closest('.dropdown-pane.bottom');
    if (dropdownParent.length) resizeDropdown(dropdownParent);
  });

  $(document).on('show.zf.dropdown dc:dropdown:resize', '.dropdown-pane.bottom', event => {
    resizeDropdown(event.currentTarget);
  });

  function resizeDropdown(element) {
    let linked_item = $('[data-toggle="' + $(element).prop('id') + '"]');

    if (
      linked_item.offset().top + linked_item.outerHeight() - $(document).scrollTop() + $(element).outerHeight() + 20 >=
        $(window).height() &&
      linked_item.offset().top - $(document).scrollTop() >
        $(window).height() - (linked_item.offset().top - $(document).scrollTop() + linked_item.outerHeight())
    ) {
      $(element).addClass('align-top');

      if ($(element).children('.list-items').length) {
        $(element).children('.list-items').first().css('max-height', '');

        if (
          $(document).scrollTop() < $('header').outerHeight() + 5 &&
          linked_item.offset().top - $(document).scrollTop() - $(element).outerHeight() <= $('header').outerHeight()
        ) {
          $(element)
            .children('.list-items')
            .first()
            .css(
              'max-height',
              $(element).children('.list-items').first().outerHeight() -
                40 +
                (linked_item.offset().top -
                  $(document).scrollTop() -
                  $(element).outerHeight() -
                  ($('header').outerHeight() - $(document).scrollTop()))
            );
        } else if (linked_item.offset().top - $(document).scrollTop() - $(element).outerHeight() <= 20) {
          $(element)
            .children('.list-items')
            .first()
            .css(
              'max-height',
              $(element).children('.list-items').first().outerHeight() -
                30 +
                (linked_item.offset().top - $(document).scrollTop() - $(element).outerHeight())
            );
        }
      }
    } else {
      $(element).removeClass('align-top');
      if ($(element).children('.list-items').length) {
        $(element).children('.list-items').first().css('max-height', '');

        if (
          $(window).height() -
            (linked_item.offset().top +
              linked_item.outerHeight() -
              $(document).scrollTop() +
              $(element).outerHeight()) <=
          20
        ) {
          $(element)
            .children('.list-items')
            .first()
            .css(
              'max-height',
              $(element).children('.list-items').first().outerHeight() +
                ($(window).height() -
                  20 -
                  (linked_item.offset().top +
                    linked_item.outerHeight() -
                    $(document).scrollTop() +
                    $(element).outerHeight()))
            );
        }
      }
    }
  }
};

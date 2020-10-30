// Dropdown Pane Overflow Fix
module.exports.initialize = function ($) {
  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    let dropdownParent = $(event.target).closest('.dropdown-pane');
    if (dropdownParent.length) dropdownParent.foundation('open');
  });

  $(document).on('show.zf.dropdown dc:dropdown:resize', '.dropdown-pane', event => {
    resizeDropdown(event.currentTarget);
  });

  function resizeDropdown(element) {
    element.style.setProperty('--dropdown-arrow-left-offset', Math.abs($(element).position().left) + 'px');
    let linked_item = $('[data-toggle="' + $(element).prop('id') + '"]');

    if (!linked_item.length) return;

    if (
      linked_item.offset().top + linked_item.outerHeight() - $(document).scrollTop() + $(element).outerHeight() + 20 >=
        $(window).height() &&
      linked_item.offset().top - $(document).scrollTop() >
        $(window).height() - (linked_item.offset().top - $(document).scrollTop() + linked_item.outerHeight())
    ) {
      $(element).addClass('top');

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
      $(element).removeClass('top');
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

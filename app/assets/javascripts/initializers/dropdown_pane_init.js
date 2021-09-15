export default function () {
  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    let dropdownParent = $(event.target).closest('.dropdown-pane');
    if (dropdownParent.length) dropdownParent.foundation('open');
  });

  $(document).on('show.zf.dropdown dc:dropdown:resize', '.dropdown-pane', event => {
    resizeDropdown(event.currentTarget);
  });

  function resizeDropdown(element) {
    const $linkedItem = $('[data-toggle="' + $(element).prop('id') + '"]');
    const pseudoWidth = parseInt(window.getComputedStyle(element, ':before').width);
    let resetOffset = Math.abs($(element).position().left) - pseudoWidth / 2;
    if ($linkedItem.length)
      resetOffset = Math.min(resetOffset + $linkedItem[0].offsetWidth / 2, element.offsetWidth - pseudoWidth - 3);

    element.style.setProperty('--dropdown-arrow-left-offset', resetOffset + 'px');

    if (!$linkedItem.length) return;
    if (
      $linkedItem.offset().top + $linkedItem.outerHeight() - $(document).scrollTop() + $(element).outerHeight() + 20 >=
        $(window).height() &&
      $linkedItem.offset().top - $(document).scrollTop() >
        $(window).height() - ($linkedItem.offset().top - $(document).scrollTop() + $linkedItem.outerHeight())
    ) {
      $(element).addClass('top');
      if ($(element).children('.list-items').length) {
        $(element).children('.list-items').first().css('max-height', '');
        if (
          $(document).scrollTop() < $('header').outerHeight() + 5 &&
          $linkedItem.offset().top - $(document).scrollTop() - $(element).outerHeight() <= $('header').outerHeight()
        ) {
          $(element)
            .children('.list-items')
            .first()
            .css(
              'max-height',
              $(element).children('.list-items').first().outerHeight() -
                40 +
                ($linkedItem.offset().top -
                  $(document).scrollTop() -
                  $(element).outerHeight() -
                  ($('header').outerHeight() - $(document).scrollTop()))
            );
        } else if ($linkedItem.offset().top - $(document).scrollTop() - $(element).outerHeight() <= 20) {
          $(element)
            .children('.list-items')
            .first()
            .css(
              'max-height',
              $(element).children('.list-items').first().outerHeight() -
                30 +
                ($linkedItem.offset().top - $(document).scrollTop() - $(element).outerHeight())
            );
        }
      }
    } else {
      $(element).removeClass('top');
      if ($(element).children('.list-items').length) {
        $(element).children('.list-items').first().css('max-height', '');
        if (
          $(window).height() -
            ($linkedItem.offset().top +
              $linkedItem.outerHeight() -
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
                  ($linkedItem.offset().top +
                    $linkedItem.outerHeight() -
                    $(document).scrollTop() +
                    $(element).outerHeight()))
            );
        }
      }
    }
  }
}

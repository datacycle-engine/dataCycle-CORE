// Add Focus Class to DOM Element on focus
module.exports.initialize = function () {

  // todo: fix multiple focusout triggers
  $('body').on('mousedown', function (ev) {
    $('.focus').each(function () {
      $(this).removeClass('focus');
      $(this).trigger('focusout');
    });
    ev.stopPropagation();
  });

  $('.validation-container:not(".focus")').on('mousedown click focusin', function (ev) {
    $('.focus').not(this).each(function () {
      $(this).removeClass('focus');
      $(this).trigger('focusout');
    });
    $(this).addClass('focus');
    ev.stopPropagation();
  });

};
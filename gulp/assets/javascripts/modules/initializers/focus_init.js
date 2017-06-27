// Add Focus Class to DOM Element on focus
module.exports.initialize = function () {

  $('body').on('mousedown', '.selected-tag button.close', function (ev) {
    $(this).closest('.validation-container').trigger('focus');

    ev.stopPropagation();
  });

  $('body').on('focusout', '.validation-container', function (ev) {
    var parent = this;
    setTimeout(function () {
      if ($(this).find(':focus').length == 0) {
        $(this).removeClass('focus');
      }
    }.bind(this), 50);
    ev.stopPropagation();
  });
  $('body').on('focusin', '.validation-container', function (ev) {
    $(this).addClass('focus');

    ev.stopPropagation();
  });

};
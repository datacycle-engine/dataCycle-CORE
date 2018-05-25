// Add Focus Class to DOM Element on focus
module.exports.initialize = function () {

  $(document).on('focusout', '.form-element', function (ev) {
    setTimeout(function () {
      if ($(this).find(':focus').addBack(':focus').length == 0) {
        $(this).removeClass('focus');
      }
    }.bind(this), 50);
  });

  $(document).on('focusin', '.form-element', function (ev) {
    $(this).addClass('focus');
  });

};

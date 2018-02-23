// Add Focus Class to DOM Element on focus
module.exports.initialize = function () {

  $(document).on('focusout', '.validation-container', function (ev) {
    setTimeout(function () {
      if ($(this).find(':focus').addBack(':focus').length == 0) {
        $(this).removeClass('focus');
      }
    }.bind(this), 50);
    // ev.stopPropagation();
  });
  $(document).on('focusin', '.validation-container', function (ev) {
    $(this).addClass('focus');

    // ev.stopPropagation();
  });

};

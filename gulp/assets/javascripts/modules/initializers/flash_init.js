// Add Timeout to slideup Flash Messages
module.exports.initialize = function ($) {
  //schickt flash callout success nach oben
  if ($('div.flash.callout.success, div.flash.callout.info').length) {
    setTimeout(function () {
      $('div.flash.callout.success, div.flash.callout.info').slideUp();
    }, 4000);
  }

  $('.close-subscribe-notice').on('click', function (ev) {
    ev.preventDefault();
    $(this).closest('.subscribe-parent').hide();
  });
};

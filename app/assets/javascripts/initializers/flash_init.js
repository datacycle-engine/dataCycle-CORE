import CalloutHelpers from './../helpers/callout_helpers';

export default function () {
  //schickt flash callout success nach oben
  if ($('div.flash.callout.success, div.flash.callout.info').length) {
    setTimeout(function () {
      $('div.flash.callout.success, div.flash.callout.info').slideUp('fast');
    }, 4000);
  }

  $('.close-subscribe-notice').on('click', function (ev) {
    ev.preventDefault();
    $(this).closest('.subscribe-parent').hide();
  });

  $('body').on('dc:flash:renderMessage', (event, data = {}) => {
    event.preventDefault();
    event.stopImmediatePropagation();

    if (!data) return;

    CalloutHelpers.show(data.text, data.type);
  });
}

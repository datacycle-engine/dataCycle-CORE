import CalloutHelpers from './../helpers/callout_helpers';

export default function () {
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

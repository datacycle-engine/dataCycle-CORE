export default function () {
  $(window).on('message onmessage', event => {
    if (
      $('.new-content-reveal:not(.in-object-browser):visible iframe').length &&
      event.originalEvent.data.action !== undefined &&
      event.originalEvent.data.action == 'import'
    ) {
      var AUTH_TOKEN = $('meta[name=csrf-token]').attr('content');
      DataCycle.httpRequest({
        type: 'POST',
        url: '/things/import',
        data: JSON.stringify({
          authenticity_token: AUTH_TOKEN,
          data: event.originalEvent.data.data,
          render_html: true
        }),
        contentType: 'application/json'
      }).finally(() => {
        $('iframe:visible').closest('.reveal').foundation('close');
      });
    } else if (
      $('#' + $('.new-content-reveal:visible iframe').data('uploader-id')).length &&
      event.originalEvent.data.action !== undefined &&
      event.originalEvent.data.action == 'open-upload-form'
    ) {
      // open upload form triggered by media_archive
      $('#' + $('.new-content-reveal:visible iframe').data('uploader-id')).foundation('open');
    } else if (event.originalEvent.data.action !== undefined && event.originalEvent.data.action == 'close_iframe') {
      // close reveal
      $('iframe:visible').closest('.reveal').foundation('close');
    }
  });
}

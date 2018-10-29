// Configure Iframe Events
module.exports.initialize = function () {

  $(window).on('message onmessage', event => {
    if ($('.new-content-reveal:not(.in-object-browser):visible iframe').length && event.originalEvent.data.action !== undefined && event.originalEvent.data.action == 'import') {
      var AUTH_TOKEN = $('meta[name=csrf-token]').attr('content');
      $.ajax({
        type: 'POST',
        url: '/creative_works/import',
        data: JSON.stringify({
          authenticity_token: AUTH_TOKEN,
          data: event.originalEvent.data.data,
          render_html: true
        }),
        contentType: 'application/json'
      }).always(() => {
        $('iframe:visible').closest('.reveal').foundation('close');
      });
    } else if ($('#content-upload-reveal').length && event.originalEvent.data.action !== undefined && event.originalEvent.data.action == 'open-upload-form') {
      // open upload form triggered by media_archive
      $('#content-upload-reveal').foundation('open');
    } else if (event.originalEvent.data.action !== undefined && event.originalEvent.data.action == 'close_iframe') {
      // close reveal
      $('iframe:visible').closest('.reveal').foundation('close');
    }
  });

};

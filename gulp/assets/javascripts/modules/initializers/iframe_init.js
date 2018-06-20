// Configure Iframe Events
module.exports.initialize = function () {

  $(window).on('message onmessage', event => {
    if ($('#new_image_iframe:visible iframe, #new_video_iframe:visible iframe').length && event.originalEvent.data.action !== undefined && event.originalEvent.data.action == 'import') {
      $('iframe:visible').closest('.reveal').foundation('close');

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
      });
    } else if ($('#content-upload-reveal').length && event.originalEvent.data.action !== undefined && event.originalEvent.data.action == 'open-upload-form') {
      $('#content-upload-reveal').foundation('open');
    }
  });

};

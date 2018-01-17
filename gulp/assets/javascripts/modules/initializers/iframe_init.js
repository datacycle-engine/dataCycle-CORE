// Configure Iframe Events
module.exports.initialize = function () {

  $(window).on('message onmessage', function (event) {
    if ($('#new_image_iframe:visible iframe, #new_video_iframe:visible iframe').length > 0) {
      $('iframe:visible').closest('.reveal').foundation('close');

      if (event.originalEvent.data.action !== undefined && event.originalEvent.data.action == 'import') {
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
      }
    }
  });

};

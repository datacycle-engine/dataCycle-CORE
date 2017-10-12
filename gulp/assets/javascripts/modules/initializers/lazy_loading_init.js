// Add Lazy Loading to Images
module.exports.initialize = function () {

  $(document).ajaxStart(function () {
    if ($(event.target).closest('#subscribe').length > 0) {
      $(event.target).closest('li').html('<i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i>');
    };
  });

  // lazy load for images in foundation raveal
  function init_lazy_loader() {
    $('.reveal.media-preview').off('open.zf.reveal');
    $('.reveal.media-preview').on('open.zf.reveal', function () {
      var images_to_load = $(this).find('img.lazyload');
      if (images_to_load.length > 0) {
        images_to_load.each(function () {
          if ($(this).attr('src') == undefined || $(this).attr('src') == "") {
            var self = this;
            $(this).after('<div class="loading"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>')
            $(this).one('load', function () {
              $(this).siblings('.loading').remove();
              $(this).fadeIn();
            }.bind(this)).one('error', function () {
              $(this).siblings('.loading').remove();
              $(this).after('<span class="load-error">Ladefehler: Bild nicht gefunden.</span>');
            }.bind(this));
            $(this).hide().attr('src', $(this).data('src'));
          }
        });
      }
    });
  }

  if ($('.reveal.media-preview').length > 0) init_lazy_loader();

  $('.media-thumbs > div').on('media_previews_added', function () {
    init_lazy_loader();
  });

  $(document).on('clone-added', '.content-object-item', function () {
    $(this).find('.media-thumbs > div').on('media_previews_added', function () {
      init_lazy_loader();
    });
  });

  // stop video playback on modal close
  $('#video-overlay, .media-preview').on('closed.zf.reveal', function () {
    $(this).find('video').trigger('pause');
  });

};

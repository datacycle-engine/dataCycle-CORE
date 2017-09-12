// Add Lazy Loading to Images
module.exports.initialize = function () {

  // lazy load for images in foundation raveal
  function init_lazy_loader() {
    $('.reveal.media-preview').off('open.zf.reveal');
    $('.reveal.media-preview').on('open.zf.reveal', function () {
      var images_to_load = $(this).find('img.lazyload');
      if (images_to_load.length > 0) {
        images_to_load.each(function () {
          $(this).attr('src', $(this).data('src'));
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

};
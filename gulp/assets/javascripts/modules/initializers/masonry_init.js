var masonry = require('masonry-layout');

// Masonry Config
module.exports.initialize = function () {

  let animation_complete = false;

  let show_animated = function (index, grid) {
    setTimeout(() => {
      if (index == 0) $('.grid .grid-loading').removeClass("show");
      $('.grid-item').eq(index).addClass("show");
      if ($('.grid-item').eq(index + 1).length) show_animated(index + 1, grid);
      else animation_complete = true;
      grid.layout();
    }, 10);
  };

  let init = function () {
    if ($('.grid').html() != undefined) {
      var grid = new masonry('.grid', {
        itemSelector: '.grid-item',
        columnWidth: '.grid-sizer',
        gutter: '.gutter-sizer',
        percentPosition: true,
        transitionDuration: 0
      });

      show_animated(0, grid);

      $(document).on('lazyloaded', function () {
        if (animation_complete) grid.layout();
      });
    }
  }

  init();

};

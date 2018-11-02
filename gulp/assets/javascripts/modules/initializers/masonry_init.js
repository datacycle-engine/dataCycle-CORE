var masonry = require('masonry-layout');

// Masonry Config
module.exports.initialize = function () {

  function init(element = document) {
    if ($(element).find('.grid').length) {
      var grid = new masonry('.grid', {
        itemSelector: '.grid-item',
        columnWidth: '.grid-sizer',
        gutter: '.gutter-sizer',
        percentPosition: true,
        transitionDuration: 0
      });

      $(element).find('.grid .grid-loading').removeClass("show");
      $(element).find('.grid-item').addClass("show");

      $(window).on('load lazyloaded', function () {
        grid.layout();
      });
    }
  };

  init();

};

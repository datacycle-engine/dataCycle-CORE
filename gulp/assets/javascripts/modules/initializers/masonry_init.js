var masonry = require('masonry-layout');

// Masonry Config
module.exports.initialize = function () {

  let init = function () {
    if ($('.grid').html() != undefined) {
      var grid = new masonry('.grid', {
        itemSelector: '.grid-item',
        columnWidth: '.grid-sizer',
        gutter: '.gutter-sizer',
        percentPosition: true,
        transitionDuration: 0
      });

      $('.grid .grid-loading').removeClass("show");

      $('.grid-item').each((index, element) => {
        setTimeout(function () {
          $(element).addClass("show");
        }, 50 + (index * 20));
      });

      $(document).on('lazyloaded', function () {
        grid.layout();
      });

      $(window).on('load', event => {
        grid.layout();
      });
    }
  }

  init();

  $(document).on('results-loaded', '.search-results', event => {
    console.log('test');
    init();
  });

};

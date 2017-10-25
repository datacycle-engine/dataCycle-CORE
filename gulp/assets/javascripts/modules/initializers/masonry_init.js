var masonry = require('masonry-layout');

// Masonry Config
module.exports.initialize = function () {

  function init() {
    if ($('.grid').html() != undefined) {
      var grid = new masonry('.grid', {
        // var $grid = $('.grid').masonry({
        // options
        // set itemSelector so .grid-sizer is not used in layout
        itemSelector: '.grid-item',
        // use element for option
        columnWidth: '.grid-sizer',
        gutter: '.gutter-sizer',
        percentPosition: true,
        transitionDuration: 0
      });
      $('.grid .grid-loading').removeClass("show");
      $.each($('.grid-item'), function (i, el) {
        setTimeout(function () {
          $(el).addClass("show");
        }, 50 + (i * 20));
      });
      $(document).on('lazyloaded', function () {
        grid.layout();
      });

    }
  }


  // realign masonry after all images are loaded
  var chkReadyState = setInterval(function () {

    if ($('.grid').html() != undefined) {
      $('.grid .grid-loading').addClass("show");
    }

    if (document.readyState == "complete") {

      clearInterval(chkReadyState);
      init();
      // finally your page is loaded.
    }
  }, 100);

};

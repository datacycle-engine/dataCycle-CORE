// Add Lazyloading + fixes
module.exports.initialize = function () {

  document.addEventListener('lazyloaded', function (e) {
    var $reveal = $(e.target).closest('.reveal');
    var new_top = ($(window).height() - $reveal.height()) / 3;
    $reveal.animate({
      top: new_top
    }, 100);
  });

  document.addEventListener('lazybeforeunveil', function (e) {
    console.log($(e.target));
    $(e.target).siblings('.lazy-loading').hide();
  });

};

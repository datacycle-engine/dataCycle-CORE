// Add Lazyloading + fixes
module.exports.initialize = function () {

  document.addEventListener('lazyloaded', function (e) {
    var $reveal = $(e.target).closest('.reveal');
    var new_top = ($(window).height() - $reveal.height()) / 3;
    $reveal.animate({
      top: new_top
    }, 100);
  });

  $(document).on('open.zf.reveal', '.new-item[data-reset-on-close="true"]', function (event) {
    if ($(this).find('iframe').length) {
      $(this).append('<div class="loading-iframe"><i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i></div>');
      $(this).find('iframe').on('lazyloaded', function () {
        $(this).find('.loading-iframe').remove();
      }.bind(this));
    }
  });

  $(document).on('closed.zf.reveal', '[data-reset-on-close="true"]', function (event) {
    $(this).children('iframe').removeClass('lazyloaded lazyloading').addClass('lazyload');
  });

};

// Reveal Blur
module.exports.initialize = function () {

  if ($('.edit-header').length > 0) {
    var edit_header_offset = $('.edit-header').offset().top;

    $(window).on('scroll', function (e) {
      if ($(this).scrollTop() > edit_header_offset) $('.edit-header').addClass('fix-edit-bar').next().addClass('no-edit-bar');
      else $('.edit-header').removeClass('fix-edit-bar').next().removeClass('no-edit-bar');
    });
  }

  $('.reveal').on('open.zf.reveal', function () {
    $('.reveal-blur').addClass("show");
    window.scrollTo(0, 0);
  });

  $('.reveal').on('closed.zf.reveal', event => {
    if ($('.reveal:visible').not(event.currentTarget).length) {
      $('body').addClass('is-reveal-open');
    } else {
      $('.reveal-blur').removeClass("show");
    }
  });

};

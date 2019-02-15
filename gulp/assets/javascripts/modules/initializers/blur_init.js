// Reveal Blur
module.exports.initialize = function() {
  if ($('.edit-header').length > 0) {
    var edit_header_offset = $('.edit-header').offset().top;

    $(window).on('scroll', function(e) {
      if ($(this).scrollTop() > edit_header_offset)
        $('.edit-header')
          .addClass('fix-edit-bar')
          .next()
          .addClass('no-edit-bar');
      else
        $('.edit-header')
          .removeClass('fix-edit-bar')
          .next()
          .removeClass('no-edit-bar');
    });
  }

  var scroll_top = [];

  $(document).on('open.zf.reveal', '.reveal', event => {
    $('.reveal-blur').addClass('show');
    if ($(event.currentTarget).data('overlay') === false) {
      scroll_top.push($(window).scrollTop());
      window.scrollTo(0, 0);
    }
  });

  $(document).on('closed.zf.reveal', '.reveal', event => {
    if ($(event.target).hasClass('reveal')) {
      if ($('.reveal:visible').not(event.currentTarget).length) {
        $('body').addClass('is-reveal-open');
      } else {
        $('.reveal-blur').removeClass('show');
      }
      if ($(event.currentTarget).data('overlay') === false) window.scrollTo(0, scroll_top.pop());
    }
  });
};

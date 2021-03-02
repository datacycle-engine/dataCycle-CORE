// Reveal Blur
export default function () {
  if ($('.edit-header').length > 0) {
    var edit_header_offset = $('.edit-header').offset().top;

    $(window).on('scroll', function (e) {
      if ($(this).scrollTop() > edit_header_offset)
        $('.edit-header').addClass('fix-edit-bar').next().addClass('no-edit-bar');
      else $('.edit-header').removeClass('fix-edit-bar').next().removeClass('no-edit-bar');
    });
  }

  var scrollTop = [];

  $(document).on('open.zf.reveal', '.reveal.object-browser-overlay', event => {
    $('.inner-container').addClass('overflow-hidden');
    if ($(event.currentTarget).data('overlay') === false) {
      scrollTop.push($(window).scrollTop());
      window.scrollTo(0, 0);
    }
  });

  $(document).on('closed.zf.reveal', '.reveal', event => {
    if ($(event.target).hasClass('reveal')) {
      if ($('.reveal:visible').not(event.currentTarget).length) $('body').addClass('is-reveal-open');
      if (
        $(event.target).hasClass('object-browser-overlay') &&
        !$('.reveal.object-browser-overlay:visible').not(event.target).length
      )
        $('.inner-container').removeClass('overflow-hidden');
      if ($(event.currentTarget).data('overlay') === false) window.scrollTo(0, scrollTop.pop());
    }
  });
}

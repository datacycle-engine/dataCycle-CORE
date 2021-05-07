export default function () {
  if ($('.edit-header').length > 0) {
    var edit_header_offset = $('.edit-header').offset().top;

    $(window).on('scroll', function (_) {
      if ($(this).scrollTop() > edit_header_offset)
        $('.edit-header').addClass('fix-edit-bar').next().addClass('no-edit-bar');
      else $('.edit-header').removeClass('fix-edit-bar').next().removeClass('no-edit-bar');
    });
  }
}

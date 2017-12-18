// Split View Inhalte kopieren
module.exports.initialize = function () {

  $('.flex-box .detail-content .properties > div[data-editor=objectBrowser]').each(function () {
    var label = $(this).data('label');
    var ids = $(this).data('id');
    if ($('.flex-box .edit-content [data-label=' + label + ']').length > 0 && ids.length > 0) {
      // add buttons to copy single elements
      // console.log($(this).find('.copy-single'));
      $(this).find('.copy-single').append('<a class="button-prime small copy-single-button"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>');

      if ($(this).find('.buttons').length > 0) $(this).find('.buttons').append('<a class="button-prime small copy"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>');
      else $(this).append('<div class="buttons"><a class="button-prime small copy"><i class="fa fa-arrow-right" aria-hidden="true"></i></a></div>');
    }
  });

  $(document).on('click', '.flex-box .copy', function (ev) {
    ev.preventDefault();
    var id = $(this).parents('[data-editor]').data('id');
    var label = $(this).parents('[data-editor]').data('label');
    copy_contents(id, label);
  });

  $(document).on('click', '.flex-box .copy-single-button', function (ev) {
    ev.preventDefault();
    var id = [$(this).parents('.copy-single').data('id')];
    var label = $(this).parents('[data-editor]').data('label');
    copy_contents(id, label);
  });

  function copy_contents(ids, label) {
    var target_container = $('.flex-box .edit-content [data-label=' + label + ']');
    target_container.find('.object-browser').trigger('import-data', {
      ids: ids
    });

    var first_error_offset = target_container.first().offset().top - target_container.offsetParent().offset().top;

    $('.flex-box .edit-content').animate({
      scrollTop: first_error_offset - 50
    }, 500);
  }

};

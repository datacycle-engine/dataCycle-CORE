// Split View Inhalte kopieren
module.exports.initialize = function () {

  $('.flex-box .detail-content .properties > div[data-editor=objectBrowser]').each(function () {
    var label = $(this).data('label');
    if ($('.flex-box .edit-content [data-label=' + label + ']').length > 0) $(this).append('<a class="button-prime small copy"><i class="fa fa-plus" aria-hidden="true"></i></a>');
  });

  $(document).on('click', '.flex-box .copy', function (ev) {
    ev.preventDefault();
    var id = $(this).parent().data('id');
    var label = $(this).parent().data('label');
    $('.flex-box .edit-content [data-label=' + label + '] .media-thumbs > div').trigger('import-data', {
      ids: id
    });
  });

};
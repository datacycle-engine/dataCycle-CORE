// Split View Inhalte kopieren
module.exports.initialize = function () {

  $('.flex-box .detail-content .properties > div[data-editor=objectBrowser]').each(function () {
    var label = $(this).data('label');
    var ids = $(this).data('id');
    if ($('.flex-box .edit-content [data-label=' + label + ']').length > 0 && ids.length > 0) {
      // add buttons to copy single elements
      // console.log($(this).find('.copy-single'));
      $(this).find('.copy-single').append('<a class="button-prime small copy-single-button"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>');

      if ($(this).children('.buttons').length > 0) $(this).children('.buttons').append('<a class="button-prime small copy"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>');
      else $(this).append('<div class="buttons"><a class="button-prime small copy"><i class="fa fa-arrow-right" aria-hidden="true"></i></a></div>');
    }
  });

  $('.flex-box .detail-content .properties > div[data-editor=embeddedObject]').each(function () {
    var label = $(this).data('label');
    var ids = $(this).data('id');
    if ($('.flex-box .edit-content [data-label=' + label + ']').length > 0 && ids.length > 0) {
      if ($(this).children('.buttons').length > 0) $(this).children('.buttons').append('<a class="button-prime small copy"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>');
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
    target_container.children('.object-browser, .embedded-object').trigger('import-data', {
      ids: ids
    });

    var first_error_offset = target_container.first().offset().top - target_container.offsetParent().offset().top;

    $('.flex-box .edit-content').animate({
      scrollTop: first_error_offset - 50
    }, 500);
  }


  // SPLIT CONTENT
  if ($(".split-content").length) {
    $(".split-content").on("mouseover", function () {
      $(".split-content").addClass('nothover');
      $(this).removeClass('nothover');
    });
    $(".has-changes").on("click", function () {
      $(".split-content .properties .selected").removeClass('selected');
      current = $(this).data("label");
      newelem = $(".split-content").last().find("[data-label='" + current + "']");
      newelem.addClass('selected');
      $('.split-content').last().animate({
        scrollTop: newelem.offset().top - $('.split-content').last().offset().top + $('.split-content').last().scrollTop() - 150
      }, 500);
      $('.split-content').first().animate({
        scrollTop: $(this).offset().top - $('.split-content').first().offset().top + $('.split-content').first().scrollTop() - 150
      }, 500);
    });
  }

};

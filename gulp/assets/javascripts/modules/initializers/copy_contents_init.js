var ConfirmationModal = require('./../components/confirmation_modal');

// Split View Inhalte kopieren
module.exports.initialize = function () {

  $('.flex-box .detail-content .properties > div[data-editor=object_browser]').each(function () {
    var label = $(this).data('label');
    var ids = $(this).data('id');
    if ($('.flex-box .edit-content [data-label="' + label + '"]').length > 0 && ids.length > 0) {
      $(this).find('.copy-single').append('<a class="button-prime small copy-single-button"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>');

      if ($(this).children('.buttons').length > 0) $(this).children('.buttons').append('<a class="button-prime small copy ids"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>');
      else $(this).append('<div class="buttons"><a class="button-prime small copy ids"><i class="fa fa-arrow-right" aria-hidden="true"></i></a></div>');
    }
  });

  $('.flex-box .detail-content .properties > div[data-editor=embedded_object]').each(function () {
    var label = $(this).data('label');
    var ids = $(this).data('id');
    if ($('.flex-box .edit-content [data-label="' + label + '"]').length > 0 && ids.length > 0) {
      if ($(this).children('.buttons').length > 0) $(this).children('.buttons').append('<a class="button-prime small copy ids"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>');
      else $(this).append('<div class="buttons"><a class="button-prime small copy ids"><i class="fa fa-arrow-right" aria-hidden="true"></i></a></div>');
    }
  });

  $('.flex-box .detail-content .properties > div[data-editor=input], .flex-box .detail-content .properties > div[data-editor=quill_editor]').each(function () {
    var label = $(this).data('label');
    var value = $(this).find('.detail-content').html();
    if ($('.flex-box .edit-content [data-label="' + label + '"]').length > 0 && value.length > 0) {
      if ($(this).children('.buttons').length > 0) $(this).children('.buttons').append('<a class="button-prime small copy text"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>');
      else $(this).append('<div class="buttons"><a class="button-prime small copy text"><i class="fa fa-arrow-right" aria-hidden="true"></i></a></div>');
    }
  });

  $(document).on('click', '.flex-box .copy.ids', function (ev) {
    ev.preventDefault();
    var id = $(this).parents('[data-editor]').data('id');
    var label = $(this).parents('[data-editor]').data('label');
    copy_contents(id, label);
  });

  $(document).on('click', '.flex-box .copy.text', function (ev) {
    ev.preventDefault();
    var text = $(this).parents('[data-editor]').find('.detail-content').html();
    var label = $(this).parents('[data-editor]').data('label');
    copy_contents(text, label);
  });

  $(document).on('click', '.flex-box .copy-single-button', function (ev) {
    ev.preventDefault();
    var id = [$(this).parents('.copy-single').data('id')];
    var label = $(this).parents('[data-editor]').data('label');
    copy_contents(id, label);
  });

  function copy_contents(values, label) {
    var target_container = $('.flex-box .edit-content [data-label="' + label + '"]');
    target_container.children('.object-browser, .embedded-object').trigger('import-data', {
      label: label,
      ids: values
    });

    target_container.children('input[type=text]').trigger('import-data', {
      label: label,
      value: values
    });

    target_container.find('> .editor-block > .quill-editor').trigger('import-data', {
      label: label,
      value: values
    });

    var first_error_offset = target_container.first().offset().top - target_container.offsetParent().offset().top;

    $('.flex-box .edit-content').animate({
      scrollTop: first_error_offset - 50
    }, 500);
  }

  $('.flex-box .edit-content .form-element.input').on('import-data', function (event, data) {
    if ($(this).find('input[type=text]').val().length === 0) {
      $(this).find('input[type=text]').val(data.value).trigger('input');
    } else {
      var confirmationModal = new ConfirmationModal(data.label + ' wird überschrieben. <br>Fortfahren?', 'success', true, function () {
        $(this).find('input[type=text]').val(data.value).trigger('input');
      }.bind(this));
    }
  });


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

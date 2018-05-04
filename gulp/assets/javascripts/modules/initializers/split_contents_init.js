var ConfirmationModal = require('./../components/confirmation_modal');

// Split View Inhalte kopieren
module.exports.initialize = function () {

  init('.flex-box .detail-content .properties');

  $(document).on('contents-added', (event, data) => {
    if (data.editor != undefined && $(event.target).data('id') != undefined && $(event.target).data('label') != undefined) {
      let container = $(event.target).parents('div[data-editor=' + data.editor + ']');
      add_buttons(event.target, $(event.target).data('label'), $(event.target).data('id'), 'data-id', data.single);
    } else if (data.editor != undefined && $(event.target).data('id') != undefined) {
      let container = $(event.target).parents('div[data-editor=' + data.editor + ']');
      add_buttons(event.target, $(container).data('label'), $(event.target).data('id'), 'data-id', data.single);
    }
  });

  $(document).on('click', '.flex-box .copy', event => {
    event.preventDefault();
    let value = '';

    if ($(event.currentTarget).data('copy-attribute') == 'data-id') value = $(event.currentTarget).parents('[data-editor]').data('id');
    else if ($(event.currentTarget).data('copy-attribute') == 'html') value = $(event.currentTarget).parents('[data-editor]').find('.detail-content').html();
    else if ($(event.currentTarget).data('copy-attribute') == 'single-data-id') value = $(event.currentTarget).parents('.copy-single').data('id');

    let label = $(event.currentTarget).parents('[data-editor]').data('label');
    copy_contents(value, label);
  });

  function add_buttons(element, label, value, copy_attr, single = false) {
    if (single && $(element).hasClass('copy-single') && $('.flex-box .edit-content [data-label="' + label + '"]').length > 0 && value.length > 0) {
      $(element).append('<a class="button-prime small copy copy-single-button" data-copy-attribute="single-data-id"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>');
    } else if (single && $('.flex-box .edit-content [data-label="' + label + '"]').length > 0 && value.length > 0) {
      $(element).find('.copy-single').append('<a class="button-prime small copy copy-single-button" data-copy-attribute="single-data-id"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>');
    } else if ($('.flex-box .edit-content [data-label="' + label + '"]').length > 0 && value.length > 0 && $(element).children('.buttons').length > 0) {
      $(element).children('.buttons').append('<a class="button-prime small copy" data-copy-attribute="' + copy_attr + '"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>');
    } else if ($('.flex-box .edit-content [data-label="' + label + '"]').length > 0 && value.length > 0) {
      $(element).append('<div class="buttons"><a class="button-prime small copy" data-copy-attribute="' + copy_attr + '"><i class="fa fa-arrow-right" aria-hidden="true"></i></a></div>');
    }
  }

  function init(container) {
    $(container).children('div[data-editor=object_browser]').each((idx, elem) => {
      add_buttons(elem, $(elem).data('label'), $(elem).data('id'), 'data-id');
      add_buttons(elem, $(elem).data('label'), $(elem).data('id'), 'data-id', true);
    });

    $(container).children('div[data-editor=embedded_object]').each((idx, elem) => {
      add_buttons(elem, $(elem).data('label'), $(elem).data('id'), 'data-id');
    });

    $(container).children('div[data-editor=input], div[data-editor=text_editor]').each((idx, elem) => {
      add_buttons(elem, $(elem).data('label'), $(elem).find('.detail-content').html(), 'html');
    });
  }

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

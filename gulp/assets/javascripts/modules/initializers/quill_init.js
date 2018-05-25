var quill = require('quill');
var Counter = require('./../components/quill_counter');
var ConfirmationModal = require('./../components/confirmation_modal');
var quill_helpers = require('./../helpers/quill_helpers');

// Quill Config
module.exports.initialize = function () {

  let init = function (node) {
    var Delta = quill.import('delta');

    // set edit mode
    var mode = "full";
    if ($(node).data('size') != undefined && $(node).data('size') != false) mode = $(node).data('size');
    else if ($(node).attr('size') != undefined && $(node).attr('size') != false) mode = $(node).attr('size');

    var formats = {
      "none": [],
      "basic": ['bold', 'italic', 'header', 'underline'],
      "full": ['bold', 'italic', 'header', 'underline', 'link', 'list', 'align']
    };

    var toolbar = {
      "none": [],
      "basic": [
        [{
          header: [1, 2, 3, false]
        }],
        ['bold', 'italic', 'underline']
      ],
      "full": [
        [{
          'align': []
        }],
        [{
          'list': 'ordered'
        }, {
          'list': 'bullet'
        }],
        [{
          header: [1, 2, 3, false]
        }],
        ['bold', 'italic', 'underline'],
        ['link']
      ]
    };

    var max = $(node).parent().data('max');

    var readonly = $(node).attr('readonly') ? true : false;

    var options = {
      modules: {
        counter: {
          unit: 'zeichen',
          max: max
        },
        toolbar: toolbar[mode]
      },
      theme: 'snow', // or 'bubble'
      formats: formats[mode],
      readOnly: readonly
    };

    var editor = new quill('#' + node.id, options);

    editor.on('selection-change', (range, oldRange, source) => {
      if (range == null) quill_helpers.update_value(editor.container);
    });

    $(editor.container).on('import-data', function (event, data) {
      if (editor.getLength() > 1) {
        var confirmationModal = new ConfirmationModal(data.label + ' wird überschrieben. <br>Fortfahren?', 'success', true, function () {
          editor.clipboard.dangerouslyPasteHTML(data.value);
        });
      } else {
        editor.clipboard.dangerouslyPasteHTML(data.value);
      }
    });
  }

  quill.register('modules/counter', Counter);

  $(document).on('clone-added', '.content-object-item', function () {

    if ($(this).find('.quill-editor').html() != undefined) {
      $(this).find('.quill-editor').each(function () {
        init(this);
      });
    }
  });

  if ($('.quill-editor').html() != undefined) {
    $('.quill-editor').each(function () {
      init(this);
    });
  }

  if ($('.editor-block').length > 0) {
    if ($('.split-content').length > 0) {
      $('.split-content.edit-content').on('scroll', function (ev) {
        $('.editor-block').each(function () {
          var pos = $(this).offset().top - $(window).scrollTop();
          if (pos < 182 && pos > -$(this).height() + 230) {
            var right = $(window).width() - ($(this).offset().left + $(this).width());
            var rest_width = right + $(this).offset().left;
            $(this).find('.ql-toolbar').css({
              right: right,
              width: "calc(100% - " + rest_width + "px)"
            });
            $(this).siblings('label').css('left', $(this).offset().left + 10);
            $(this).find('.ql-toolbar').addClass('fixed-split-toolbar');
            $(this).siblings('label').addClass('fixed-split-toolbar');
          } else {
            $(this).find('.ql-toolbar').removeClass('fixed-split-toolbar').removeAttr('style');
            $(this).siblings('label').removeClass('fixed-split-toolbar').removeAttr('style');
          }
        });
      });
    } else {
      $(window).on('scroll', function (ev) {
        $('.editor-block').each(function () {
          var pos = $(this).offset().top - $(window).scrollTop();
          if (pos < 55 && pos > -$(this).height() + 130) {
            var right = $(window).width() - ($(this).offset().left + $(this).width());
            var rest_width = right + $(this).offset().left;
            $(this).find('.ql-toolbar').css({
              right: right,
              width: "calc(100% - " + rest_width + "px)"
            });
            $(this).siblings('label').css('left', $(this).offset().left + 10);
            $(this).find('.ql-toolbar').addClass('fixed-toolbar');
            $(this).siblings('label').addClass('fixed-toolbar');
          } else {
            $(this).find('.ql-toolbar').removeClass('fixed-toolbar').removeAttr('style');
            $(this).siblings('label').removeClass('fixed-toolbar').removeAttr('style');
          }
        });
      });
    }
  }

};

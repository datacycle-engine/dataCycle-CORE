var quill = require('quill');
var Counter = require('./../components/quill_counter');
var ConfirmationModal = require('./../components/confirmation_modal');
var quill_helpers = require('./../helpers/quill_helpers');

// Quill Config
module.exports.initialize = function () {

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

  function init(node) {
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

  let position_editor_toolbar = function (element, fixed_class = '') {
    var right = $(window).width() - ($(element).offset().left + $(element).width());
    var rest_width = right + $(element).offset().left;
    $(element).find('.ql-toolbar').css({
      right: right,
      width: "calc(100% - " + rest_width + "px)"
    });
    $(element).siblings('label').css('left', $(element).offset().left + 10);
    $(element).find('.ql-toolbar').addClass(fixed_class);
    $(element).siblings('label').addClass(fixed_class);
    if ($(element).siblings('label[for*="textblock"]').length) $(element).parents('.content-object-item.textblock').find('> .embedded-header > input').addClass(fixed_class).css('left', $(element).offset().left + 10);
  };

  let reset_editor_toolbar = function (element, fixed_class = '') {
    $(element).find('.ql-toolbar').removeClass(fixed_class).removeAttr('style');
    $(element).siblings('label').removeClass(fixed_class).removeAttr('style');
    if ($(element).siblings('label[for*="textblock"]').length) $(element).parents('.content-object-item.textblock').find('> .embedded-header > input').removeClass(fixed_class).removeAttr('style');
  };

  if ($('.editor-block').length > 0) {
    if ($('.split-content').length > 0) {
      $('.split-content.edit-content').on('scroll', function (ev) {
        $('.editor-block').each(function () {
          var pos = $(this).offset().top - $(window).scrollTop();
          if (pos < 182 && pos > -$(this).height() + 230) {
            position_editor_toolbar(this, 'fixed-split-toolbar');
          } else {
            reset_editor_toolbar(this, 'fixed-split-toolbar');
          }
        });
      });
    } else {
      $(window).on('scroll', function (ev) {
        $('.editor-block').each(function () {
          var pos = $(this).offset().top - $(window).scrollTop();
          if (pos < 55 && pos > -$(this).height() + 130) {
            position_editor_toolbar(this, 'fixed-toolbar');
          } else {
            reset_editor_toolbar(this, 'fixed-toolbar');
          }
        });
      });
    }
  }

};

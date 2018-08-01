var Quill = require('quill');
var Counter = require('./../components/quill_counter');
var ConfirmationModal = require('./../components/confirmation_modal');
var quill_helpers = require('./../helpers/quill_helpers');

var Delta = Quill.import('delta');
let Break = Quill.import('blots/break');
let Embed = Quill.import('blots/embed');

function lineBreakMatcher() {
  var newDelta = new Delta();
  newDelta.insert({
    'break': ''
  });
  return newDelta;
}

Break.prototype.insertInto = function (parent, ref) {
  Embed.prototype.insertInto.call(this, parent, ref)
};
Break.prototype.length = function () {
  return 1;
};
Break.prototype.value = function () {
  return '\n';
};
Quill.register(Break);

// Quill Config
module.exports.initialize = function () {

  let init = function (node) {
    // set edit mode
    var mode = "full";
    if ($(node).data('size') != undefined && $(node).data('size') != false) mode = $(node).data('size');
    else if ($(node).attr('size') != undefined && $(node).attr('size') != false) mode = $(node).attr('size');

    var formats = {
      "none": ['break'],
      "basic": ['bold', 'italic', 'header', 'underline', 'break'],
      "full": ['bold', 'italic', 'header', 'underline', 'link', 'list', 'align', 'break']
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

    var max = $(node).data('max');

    var readonly = $(node).attr('readonly') ? true : false;

    var options = {
      modules: {
        counter: {
          unit: 'zeichen',
          max: max
        },
        toolbar: toolbar[mode],
        clipboard: {
          matchers: [
            ['BR', lineBreakMatcher]
          ]
        },
        keyboard: {
          bindings: {
            handleEnter: {
              key: 13,
              handler: function (range, context) {
                if (range.length > 0) {
                  this.quill.scroll.deleteAt(range.index, range.length); // So we do not trigger text-change
                }
                let lineFormats = Object.keys(context.format).reduce(function (lineFormats, format) {
                  if (Parchment.query(format, Parchment.Scope.BLOCK) && !Array.isArray(context.format[format])) {
                    lineFormats[format] = context.format[format];
                  }
                  return lineFormats;
                }, {});
                var previousChar = this.quill.getText(range.index - 1, 1);
                // Earlier scroll.deleteAt might have messed up our selection,
                // so insertText's built in selection preservation is not reliable
                this.quill.insertText(range.index, '\n', lineFormats, Quill.sources.USER);
                if (previousChar == '' || previousChar == '\n') {
                  this.quill.setSelection(range.index + 2, Quill.sources.SILENT);
                } else {
                  this.quill.setSelection(range.index + 1, Quill.sources.SILENT);
                }
                // this.quill.selection.scrollIntoView();
                Object.keys(context.format).forEach((name) => {
                  if (lineFormats[name] != null) return;
                  if (Array.isArray(context.format[name])) return;
                  if (name === 'link') return;
                  this.quill.format(name, context.format[name], Quill.sources.USER);
                });
              }
            },
            linebreak: {
              key: 13,
              shiftKey: true,
              handler: function (range) {
                let currentLeaf = this.quill.getLeaf(range.index)[0]
                let nextLeaf = this.quill.getLeaf(range.index + 1)[0]

                this.quill.insertEmbed(range.index, 'break', true, 'user');

                // Insert a second break if:
                // At the end of the editor, OR next leaf has a different parent (<p>)
                if (nextLeaf === null || (currentLeaf.parent !== nextLeaf.parent)) {
                  this.quill.insertEmbed(range.index, 'break', true, 'user');
                }

                // Now that we've inserted a line break, move the cursor forward
                this.quill.setSelection(range.index + 1, Quill.sources.SILENT);
              }
            }
          }
        }
      },
      theme: 'snow', // or 'bubble'
      formats: formats[mode],
      readOnly: readonly
    };

    var editor = new Quill('#' + node.id, options);

    var length = editor.getLength();
    var text = editor.getText(length - 2, 2);

    // Remove extraneous new lines
    if (text === '\n\n') {
      editor.deleteText(editor.getLength() - 2, 2);
    }

    editor.on('selection-change', (range, oldRange, source) => {
      if (range == null) quill_helpers.update_value(editor.container);
    });

    $(editor.container).on('import-data', function (event, data) {
      if (editor.getText().trim().length > 1) {
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

  Quill.register('modules/counter', Counter);

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

};

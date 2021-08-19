import Quill from 'quill';
import Counter from './../components/quill_counter';
import { QuillContentlinkModule, ContentlinkBlot } from './../components/quill_content_link';
import { QuillLinkFormat, QuillLinkModule } from '../components/quill_custom_link';
import { SmartBreak, lineBreakMatcher, lineBreakHandler } from '../components/quill_smart_break';
import handleEnter from '../components/quill_enter_handler';
import ConfirmationModal from './../components/confirmation_modal';
import quill_helpers from './../helpers/quill_helpers';
import quillCustomHandlers from '../components/quill_custom_handlers';
const icons = Quill.import('ui/icons');
import cloneDeep from 'lodash/cloneDeep';

Quill.register(SmartBreak);
Quill.register('modules/contentlink', QuillContentlinkModule);
Quill.register('formats/contentlink', ContentlinkBlot);
Quill.register('modules/customlink', QuillLinkModule);
Quill.register('formats/customlink', QuillLinkFormat);

export default function () {
  var formats = {
    none: ['break'],
    minimal: ['bold', 'italic', 'underline', 'break'],
    basic: ['bold', 'italic', 'header', 'underline', 'break', 'script'],
    full: ['bold', 'italic', 'header', 'underline', 'customlink', 'list', 'align', 'break', 'script', 'contentlink']
  };

  var toolbar = {
    none: {
      container: []
    },
    minimal: { container: [['bold', 'italic', 'underline'], ['insertNbsp', 'replaceAllNbsp'], ['clean']] },
    basic: {
      container: [
        [
          {
            header: [1, 2, 3, 4, false]
          }
        ],
        [{ script: 'sub' }, { script: 'super' }],
        ['bold', 'italic', 'underline'],
        ['insertNbsp', 'replaceAllNbsp'],
        ['clean']
      ]
    },
    full: {
      container: [
        [
          {
            align: []
          }
        ],
        [
          {
            list: 'ordered'
          },
          {
            list: 'bullet'
          }
        ],
        [
          {
            header: [1, 2, 3, 4, false]
          }
        ],
        [{ script: 'sub' }, { script: 'super' }],
        ['bold', 'italic', 'underline'],
        ['insertNbsp', 'replaceAllNbsp'],
        ['customlink', 'contentlink'],
        ['clean']
      ]
    }
  };

  var default_options = {
    modules: {
      counter: true,
      contentlink: {},
      customlink: {},
      toolbar: toolbar['none'],
      clipboard: {
        matchers: [['BR', lineBreakMatcher]]
      },
      keyboard: {
        bindings: {
          handleEnter: {
            key: 13,
            handler: handleEnter
          },
          linebreak: {
            key: 13,
            shiftKey: true,
            handler: lineBreakHandler
          }
        }
      }
    },
    theme: 'snow',
    formats: formats['none'],
    readOnly: false
  };

  function init(container = document) {
    $(container)
      .find('.quill-editor')
      .each(async (_, node) => {
        // set edit mode
        let mode = 'full';
        if ($(node).data('size') != undefined && $(node).data('size') != false) mode = $(node).data('size');
        else if ($(node).attr('size') != undefined && $(node).attr('size') != false) mode = $(node).attr('size');

        let readOnly = $(node).attr('readonly') ? true : false;

        let options = cloneDeep(default_options);
        options.modules.toolbar = toolbar[mode];
        options.modules.toolbar.handlers = quillCustomHandlers;
        options.formats = formats[mode];
        options.readOnly = readOnly;
        options.bounds = node;

        try {
          if (mode != 'none' && !icons.hasOwnProperty('insertNbsp'))
            icons['insertNbsp'] = `<span title="${await I18n.translate(
              'frontend.text_editor.insertNbsp'
            )}"><svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 0 24 24" width="24px" fill="#000000"><path d="M0 0h24v24H0V0z" fill="none"/><path d="M18 9v4H6V9H4v6h16V9z"/></svg></span>`;

          if (mode != 'none' && !icons.hasOwnProperty('replaceAllNbsp'))
            icons['replaceAllNbsp'] = `<span title="${await I18n.translate(
              'frontend.text_editor.replaceAllNbsp'
            )}"><svg class="spacebar-icon" xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 0 24 24" width="24px" fill="#000000"><path d="M0 0h24v24H0V0z" fill="none"/><path d="M18 9v4H6V9H4v6h16V9z"/></svg><svg class="times-icon" xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 0 24 24" width="24px" fill="#000000"><path d="M0 0h24v24H0z" fill="none"/><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg></span>`;

          let editor = new Quill(node, options);
          let length = editor.getLength();
          let text = editor.getText(length - 2, 2);

          // Remove extraneous new lines
          if (text === '\n\n') {
            editor.deleteText(editor.getLength() - 2, 2);
          }

          editor.on('selection-change', (range, _oldRange, _source) => {
            if (range == null) quill_helpers.updateEditors(editor.container);
          });

          $(editor.container)
            .closest('form')
            .on('reset', _event => {
              editor.clipboard.dangerouslyPasteHTML($(editor.container).data('default-value') || '');
              quill_helpers.updateEditors(editor.container);
            });

          $(editor.container).on('dc:import:data', async (_event, data) => {
            if (editor.getText().trim().length > 1 && (!data || !data.force)) {
              new ConfirmationModal({
                text: await I18n.translate('frontend.override_warning', { data: data.label }),
                confirmationText: await I18n.translate('common.yes'),
                cancelText: await I18n.translate('common.no'),
                confirmationClass: 'success',
                cancelable: true,
                confirmationCallback: () => {
                  editor.clipboard.dangerouslyPasteHTML(data.value);
                }
              });
            } else {
              editor.clipboard.dangerouslyPasteHTML(data.value);
            }
          });
        } catch (err) {
          console.error(err);
          if (window.appSignal) appSignal.sendError(err);
        }
      });
  }

  function positionEditorToolbar(element, fixed_class = '') {
    var right = $(window).width() - ($(element).offset().left + $(element).width());
    var rest_width = right + $(element).offset().left;
    $(element)
      .find('.ql-toolbar')
      .css({
        right: right,
        width: 'calc(100% - ' + rest_width + 'px)'
      });
    $(element)
      .siblings('.translated')
      .css('left', $(element).offset().left + 10);
    if ($(element).siblings('.translated').length)
      $(element)
        .siblings('label')
        .css('left', $(element).offset().left + 30);
    else
      $(element)
        .siblings('label')
        .css('left', $(element).offset().left + 10);
    $(element).find('.ql-toolbar').addClass(fixed_class);
    $(element).siblings('label, .translated').addClass(fixed_class);
    if ($(element).siblings('label[for*="textblock"]').length)
      $(element)
        .parents('.content-object-item.textblock')
        .find('> .embedded-header > input')
        .addClass(fixed_class)
        .css('left', $(element).offset().left + 10);

    if ($(element).parents('.content-object-item.textblock').find('> .embedded-header > .translated').length)
      $(element)
        .parents('.content-object-item.textblock')
        .find('> .embedded-header > .translated')
        .addClass(fixed_class)
        .css('left', $(element).offset().left + 10);
    $(element)
      .parents('.content-object-item.textblock')
      .find('> .embedded-header > input')
      .css('left', $(element).offset().left + 30);
  }

  let resetEditorToolbar = function (element, fixed_class = '') {
    $(element).find('.ql-toolbar').removeClass(fixed_class).removeAttr('style');
    $(element).siblings('label, .translated').removeClass(fixed_class).removeAttr('style');
    if ($(element).siblings('label[for*="textblock"]').length)
      $(element)
        .parents('.content-object-item.textblock')
        .find('> .embedded-header > input, > .embedded-header > .translated')
        .removeClass(fixed_class)
        .removeAttr('style');
  };

  if ($('.editor-block').length > 0) {
    if ($('.split-content').length > 0) {
      $('.split-content.edit-content').on('scroll', function (ev) {
        $('.editor-block').each(function () {
          var pos = $(this).offset().top - $(window).scrollTop();
          if (pos < 182 && pos > -$(this).height() + 230) {
            positionEditorToolbar(this, 'fixed-split-toolbar');
          } else {
            resetEditorToolbar(this, 'fixed-split-toolbar');
          }
        });
      });
    } else {
      $(window).on('scroll', function (_ev) {
        $('.editor-block').each(function () {
          var pos = $(this).offset().top - $(window).scrollTop();
          if (pos < 55 && pos > -$(this).height() + 130) {
            positionEditorToolbar(this, 'fixed-toolbar');
          } else {
            resetEditorToolbar(this, 'fixed-toolbar');
          }
        });
      });
    }
  }

  Quill.register('modules/counter', Counter);

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    init(event.target);
  });

  init();
}

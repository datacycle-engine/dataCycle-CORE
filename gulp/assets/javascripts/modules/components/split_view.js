var ConfirmationModal = require('./confirmation_modal');

// Split View
class SplitView {
  constructor(container = document) {
    this.container = $(container);
    this.selectors = [
      '> .object-browser',
      '> .embedded-object',
      '> input[type=text]',
      '> .editor-block > .quill-editor',
      '> .v-select > select.multi-select',
      '> .v-select > select.single-select',
      '> .v-select > select.async-select'
    ];
    this.setup();
  }
  setup() {
    this.setupObjectBrowserButtons();
    this.setupEmbeddedObjectButtons();
    this.setupClassificationButtons();
    this.setupTextFieldButtons();

    this.container.on('click', '.copy', this.handleButtonClick.bind(this));
    this.container.on('dc:contents:added', this.setupAdditionalButtons.bind(this));
  }
  setupAdditionalButtons(event, data) {
    event.stopImmediatePropagation();
    if (data.editor !== undefined && $(event.target).data('id') !== undefined) {
      let key =
        $(event.target).data('key') ||
        $(event.target)
          .parents('div[data-editor=' + data.editor + ']')
          .data('key');

      this.addButtons(
        event.target,
        key,
        $(event.target).data('id'),
        data.single ? 'single-data-id' : 'data-id',
        data.single
      );
    }
  }
  setupObjectBrowserButtons() {
    this.container.children('div[data-editor=object_browser]').each((_, elem) => {
      this.addButtons(elem, $(elem).data('key'), $(elem).data('id') || [], 'data-id');
      this.addButtons(elem, $(elem).data('key'), $(elem).data('id') || [], 'single-data-id', true);
    });
  }
  setupEmbeddedObjectButtons() {
    this.container.children('div[data-editor=embedded_object]').each((_, elem) => {
      this.addButtons(elem, $(elem).data('key'), $(elem).data('id') || [], 'data-id');
    });
  }
  setupTextFieldButtons() {
    this.container.children('div[data-editor=string], div[data-editor=text_editor]').each((_, elem) => {
      this.addButtons(
        elem,
        $(elem).data('key'),
        $(elem)
          .find('.detail-content')
          .html()
          .trim() || [],
        'html'
      );
    });
  }
  setupClassificationButtons() {
    this.container.children('div[data-editor=classification]').each((_, elem) => {
      this.addButtons(elem, $(elem).data('key'), $(elem).data('id') || [], 'data-id');
    });
  }
  addButtons(element, key, value, copy_attr, single = false) {
    if ($('.flex-box .edit-content [data-key="' + key + '"]').length && value.length > 0) {
      if (single && !$(element).hasClass('copy-single')) element = $(element).find('.copy-single');
      this.renderButton(element, copy_attr, single);
    }
  }
  renderButton(element, copy_attr, single) {
    if (!single && !$(element).children('.buttons').length) $(element).append('<div class="buttons"></div');
    if ($(element).children('.buttons').length) element = $(element).children('.buttons');

    $(element).append(
      '<a class="button-prime small copy' +
        (single ? ' copy-single-button' : '') +
        '" data-copy-attribute="' +
        copy_attr +
        '" title="Übernehmen"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>'
    );
  }
  handleButtonClick(event) {
    event.preventDefault();
    let value = '';
    let elem = $(event.currentTarget);
    switch (elem.data('copy-attribute')) {
      case 'single-data-id':
        value = elem.parents('.copy-single').data('id');
        break;
      case 'data-id':
        value = elem.parents('[data-editor]').data('id');
        break;
      case 'html':
        value = elem
          .parents('[data-editor]')
          .find('.detail-content')
          .html();
        break;
    }

    let label = elem.parents('[data-editor]').data('label');
    let key = elem.parents('[data-editor]').data('key');
    this.copyContents(value, label, key);
  }
  copyContents(value, label, key) {
    let target = $('.flex-box .edit-content [data-key="' + key + '"]');

    target.find(this.selectors.join(', ')).trigger('dc:import:data', {
      label: label,
      value: value
    });

    target.get(0).scrollIntoView({ behavior: 'smooth' });
  }
}

module.exports = SplitView;

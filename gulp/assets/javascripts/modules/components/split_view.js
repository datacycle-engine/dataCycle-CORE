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
      '> .v-select > select.async-select',
      '> .form-element > .flatpickr-wrapper > input[type=text].flatpickr-input',
      '> .asset-selector-button',
      '> .geographic > .geographic-map'
    ];
    this.setup();
  }
  setup() {
    this.setupObjectBrowserButtons();
    this.setupEmbeddedObjectButtons();
    this.setupClassificationButtons();
    this.setupTextFieldButtons();
    this.setupDateTimeButtons();
    this.setupAssetSelectorButtons();
    this.setupGeographicButtons();

    this.setupCopyAllButtons(this.container.closest('.split-content'));
    this.setupCopyAllButtons(this.availableEditors(['included-object']));

    this.container.on('click', '.copy', this.handleButtonClick.bind(this));
    this.container.closest('.split-content').on('click', '.copy-all', this.triggerAllButtons.bind(this));
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
  availableEditors(selectors = []) {
    let selector_string = selectors
      .map(x => {
        return '> div[data-editor=' + x + '], > div[data-editor=included-object] > div[data-editor=' + x + ']';
      })
      .join(', ');
    return this.container.find(selector_string);
  }
  setupObjectBrowserButtons() {
    this.availableEditors(['object_browser']).each((_, elem) => {
      this.addButtons(elem, $(elem).data('key'), $(elem).data('id') || [], 'data-id');
      this.addButtons(elem, $(elem).data('key'), $(elem).data('id') || [], 'single-data-id', true);
    });
  }
  setupEmbeddedObjectButtons() {
    this.availableEditors(['embedded_object']).each((_, elem) => {
      this.addButtons(elem, $(elem).data('key'), $(elem).data('id') || [], 'data-id');
    });
  }
  setupTextFieldButtons() {
    this.availableEditors(['string', 'text_editor']).each((_, elem) => {
      this.addButtons(
        elem,
        $(elem).data('key'),
        $(elem)
          .find('.detail-content')
          .html()
          .trim() || '',
        'html'
      );
    });
  }
  setupClassificationButtons() {
    this.availableEditors(['classification']).each((_, elem) => {
      this.addButtons(elem, $(elem).data('key'), $(elem).data('id') || [], 'data-id');
    });
  }
  setupDateTimeButtons() {
    this.availableEditors(['date_picker']).each((_, elem) => {
      this.addButtons(elem, $(elem).data('key'), $(elem).data('value') || '', 'data-value');
    });
  }
  setupAssetSelectorButtons() {
    this.availableEditors(['asset_selector']).each((_, elem) => {
      this.addButtons(elem, $(elem).data('key'), $(elem).data('id') || [], 'data-id');
    });
  }
  setupGeographicButtons() {
    this.availableEditors(['geographic']).each((_, elem) => {
      this.addButtons(elem, $(elem).data('key'), $(elem).data('value') || {}, 'data-value');
    });
  }
  setupCopyAllButtons(elements) {
    elements.each((_, item) => {
      if ($(item).find('a.copy').length)
        $(item).append(
          '<a class="button-prime small copy-all" title="Alle übernehmen"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>'
        );
    });
  }
  addButtons(element, key, value, copy_attr, single = false) {
    if (
      $('.flex-box .edit-content [data-key="' + key + '"]').length &&
      this.valueNotEmpty(value) &&
      !$('.flex-box .edit-content [data-key="' + key + '"]')
        .first()
        .data('readonly')
    ) {
      if (single && !$(element).hasClass('copy-single')) element = $(element).find('.copy-single');
      this.renderButton(element, copy_attr, single);
    }
  }
  valueNotEmpty(value) {
    if (value === undefined || value === null) return false;
    switch (typeof value) {
      case 'object':
        return Object.values(value).filter(x => x != '' && x !== null && x !== undefined).length > 0;
      case 'string':
        return value.length > 0;
    }
  }
  renderButton(element, copy_attr, single) {
    if (!single && !$(element).children('.buttons').length) $(element).append('<div class="buttons"></div');
    if ($(element).find('> .content-link > .buttons').length) element = $(element).find('> .content-link > .buttons');
    if ($(element).children('.buttons').length) element = $(element).children('.buttons');

    $(element).append(
      '<a class="button-prime small copy' +
        (single ? ' copy-single-button' : '') +
        '" data-copy-attribute="' +
        copy_attr +
        '" title="übernehmen"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>'
    );
  }
  handleButtonClick(event) {
    event.preventDefault();
    let value = '';
    let elem = $(event.currentTarget);
    switch (elem.data('copy-attribute')) {
      case 'single-data-id':
        value = elem
          .parents('.copy-single')
          .first()
          .data('id');
        break;
      case 'data-id':
        value = elem
          .parents('[data-editor]')
          .first()
          .data('id');
        break;
      case 'data-value':
        value = elem
          .parents('[data-editor]')
          .first()
          .data('value');
        break;
      case 'html':
        value = elem
          .parents('[data-editor]')
          .first()
          .find('.detail-content')
          .html();
        break;
    }

    let label = elem.parents('[data-editor]').data('label');
    let key = elem.parents('[data-editor]').data('key');
    this.copyContents(value, label, key);
  }
  triggerAllButtons(event) {
    event.preventDefault();
    $(event.currentTarget)
      .parent('.split-content, [data-editor="included-object"]')
      .find('a.copy')
      .trigger('click');
  }
  copyContents(value, label, key) {
    let target = $('.flex-box .edit-content [data-key="' + key + '"]');

    target.find(this.selectors.join(', ')).trigger('dc:import:data', {
      label: label,
      value: typeof value == 'string' ? value.trim() : value
    });

    target.get(0).scrollIntoView({ behavior: 'smooth' });
  }
}

module.exports = SplitView;

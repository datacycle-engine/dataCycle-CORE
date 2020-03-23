// Split View
class SplitView {
  constructor(container = document) {
    this.container = $(container);
    this.embedLocale = this.container.closest('.split-content').data('embed-locale');
    this.leftLocale = this.container.closest('.split-content').data('locale');
    this.rightLocale = this.container
      .closest('form')
      .find('input#locale:hidden')
      .val();
    this.setup();
  }
  setup() {
    this.setupObjectBrowserButtons();
    this.setupEmbeddedObjectButtons();
    this.setupClassificationButtons();
    this.setupTextFieldButtons();
    this.setupDateTimeButtons();
    this.setupGeographicButtons();
    this.setupBooleanButtons();
    this.setupNumberButtons();
    this.setupUrlButtons();

    this.setupCopyAllButtons(this.container.closest('.split-content'));
    this.setupCopyAllButtons(this.availableEditors(['included-object']));

    this.container.on('click', '.copy', this.handleButtonClick.bind(this));
    this.container.on('click', '.translate', this.handleButtonClick.bind(this));
    this.container.closest('.split-content').on('click', '.copy-all', this.triggerAllButtons.bind(this));
    this.container.on('dc:contents:added', this.setupAdditionalButtons.bind(this));
    this.container
      .closest('.split-content')
      .find('.close-subscribe-notice')
      .on('click', this.dismissSubscribeNotice.bind(this));
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
  dismissSubscribeNotice(_event) {
    document.cookie = 'subscribe_notice_dismissed=true';
  }
  availableEditors(selectors = []) {
    let newSelectorString = selectors.map(x => 'div[data-editor=' + x + ']').join(', ');
    let notInSelector = 'div[data-editor]:not([data-editor="included-object"]) div[data-editor]';

    return this.container.find(newSelectorString).not(notInSelector);
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
  setupGeographicButtons() {
    this.availableEditors(['geographic']).each((_, elem) => {
      this.addButtons(elem, $(elem).data('key'), $(elem).data('value') || {}, 'data-value');
    });
  }
  setupBooleanButtons() {
    this.availableEditors(['boolean']).each((_, elem) => {
      this.addButtons(elem, $(elem).data('key'), $(elem).data('value'), 'data-value');
    });
  }
  setupNumberButtons() {
    this.availableEditors(['number', 'duration']).each((_, elem) => {
      this.addButtons(elem, $(elem).data('key'), $(elem).data('value'), 'data-value');
    });
  }
  setupUrlButtons() {
    this.availableEditors(['url']).each((_, elem) => {
      this.addButtons(
        elem,
        $(elem).data('key'),
        $(elem)
          .find('.detail-content > a')
          .attr('href'),
        'href'
      );
    });
  }
  setupCopyAllButtons(elements) {
    elements.each((_, item) => {
      if ($(item).find('a.copy').length)
        $(item).prepend(
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
      case 'boolean':
        return true;
    }
  }
  renderButton(element, copy_attr, single) {
    if (!single && !$(element).children('.buttons').length) $(element).append('<div class="buttons"></div');
    if ($(element).find('> .content-link > .buttons').length) element = $(element).find('> .content-link > .buttons');
    if ($(element).children('.buttons').length) element = $(element).children('.buttons');

    if (copy_attr === 'html') {
      $(element).append(
        '<a class="button-prime small translate' +
        (single ? ' translate-single-button' : '') + //??
          '" data-copy-attribute="' +
          copy_attr +
          '" data-translate-attribute="true"' +
          ' title="übersetzen"><i class="fa fa-globe" aria-hidden="true"></i></a>'
      );
    }

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
      case 'href':
        value = elem
          .parents('[data-editor]')
          .first()
          .find('.detail-content > a')
          .attr('href');
        break;
    }

    let label = elem.parents('[data-editor]').data('label');
    let key = elem.parents('[data-editor]').data('key');

    if (elem.data('translate-attribute')) {
      this.translateText(value, label, key);
    } else {
      this.copyContents(value, label, key);
    }
  }
  triggerAllButtons(event) {
    event.preventDefault();
    $(event.currentTarget)
      .parent('.split-content, [data-editor="included-object"]')
      .find('a.copy:not(.copy-single-button)')
      .trigger('click');
  }
  copyContents(value, label, key) {
    if ($('.edit-header .submit-edit-form').prop('disabled')) return;

    let target = $('.flex-box .edit-content [data-key="' + key + '"]');

    target.find(window.EDITORSELECTORS.join(', ')).trigger('dc:import:data', {
      label: label,
      value: typeof value == 'string' ? value.trim() : value,
      locale: this.embedLocale ? this.leftLocale : ''
    });

    target.get(0).scrollIntoView({ behavior: 'smooth' });
  }
  translateText(value, label, key) {
    let formData = {
      text: value.trim(),
      source_locale: this.leftLocale,
      target_locale: this.rightLocale
    };
    $.ajax({
      url: '/things/translate_text',
      method: 'POST',
      data: formData,
      dataType: 'json',
      contentType: 'application/x-www-form-urlencoded'
    }).done(data => {
      console.log(data);
      this.copyContents(data.text, label, key);
    });
  }
}

module.exports = SplitView;

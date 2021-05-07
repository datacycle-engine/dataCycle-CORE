import CalloutHelpers from './../helpers/callout_helpers';

class SplitView {
  constructor(container = document) {
    this.container = $(container);
    this.embedLocale = this.container.closest('.split-content').data('embed-locale');
    this.leftLocale = this.container.closest('.split-content').data('locale');
    this.enableTranslateButtons = this.container.closest('.split-content').data('enable-translate-buttons');
    this.rightLocale = this.container.closest('form').find('input#locale:hidden').val();

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
    this.container
      .closest('.split-content')
      .on('click', '.copy-all, .translate-all', this.triggerAllButtons.bind(this));
    this.container.on('dc:contents:added', '[data-id]:not(.dc-sw-initialized)', this.setupAdditionalButtons.bind(this));
    this.container
      .closest('.split-content')
      .find('.close-subscribe-notice')
      .on('click', this.dismissSubscribeNotice.bind(this));
  }
  setupAdditionalButtons(event, data) {
    let item = $(event.target);

    if (data.editor !== undefined && item.data('id') !== undefined) {
      let key = item.data('key') || item.parents('div[data-editor=' + data.editor + ']').data('key');

      this.addButtons(event.target, key, item.data('id'), data.single ? 'single-data-id' : 'data-id', data.single);
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
      this.addButtons(elem, $(elem).data('key'), $(elem).data('value') || '', 'data-value');
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
      this.addButtons(elem, $(elem).data('key'), $(elem).find('.detail-content > a').attr('href'), 'href');
    });
  }
  setupCopyAllButtons(elements) {
    elements.each((_, item) => {
      if ($(item).find('a.copy').length) {
        if (this.enableTranslateButtons) {
          $(item).prepend(
            '<a class="button-prime small translate-all" title="Alle übersetzen"><i class="fa fa-language" aria-hidden="true"></i></a>'
          );
        }
        $(item).prepend(
          '<a class="button-prime small copy-all" title="Alle übernehmen"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>'
        );
      }
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
    $(element).addClass('dc-sw-initialized');
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

    if (this.enableTranslateButtons && this.isTranslatableField(element)) {
      $(element).append(
        '<a class="button-prime small translate' +
          (single ? ' translate-single-button' : '') + //??
          '" data-copy-attribute="' +
          copy_attr +
          '" data-translate-attribute="true"' +
          ' data-disable-with="<i class=\'fa fa-circle-o-notch fa-spin\'></i>"' +
          ' title="übersetzen"><i class="fa fa-language aria-hidden="true"></i></a>'
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
  isTranslatableField(element) {
    let field = element.parents('[data-editor]').first();
    return field.hasClass('string') && (field.data('editor') === 'text_editor' || field.data('editor') === 'string');
  }
  handleButtonClick(event) {
    event.preventDefault();
    let value = '';
    let elem = $(event.currentTarget);
    switch (elem.data('copy-attribute')) {
      case 'single-data-id':
        value = elem.parents('.copy-single').first().data('id');
        break;
      case 'data-id':
        value = elem.parents('[data-editor]').first().data('id');
        break;
      case 'data-value':
        value = elem.parents('[data-editor]').first().data('value');
        break;
      case 'html':
        value = elem.parents('[data-editor]').first().find('.detail-content').html();
        break;
      case 'href':
        value = elem.parents('[data-editor]').first().find('.detail-content > a').attr('href');
        break;
    }

    let label = elem.parents('[data-editor]').data('label');
    let key = elem.parents('[data-editor]').data('key');

    if (elem.data('translate-attribute')) {
      this.translateText(elem, value, label, key);
    } else {
      this.copyContents(value, label, key);
    }
  }
  triggerAllButtons(event) {
    event.preventDefault();

    let selector = event.currentTarget.classList.contains('translate-all')
      ? 'a.translate'
      : 'a.copy:not(.copy-single-button)';

    $(event.currentTarget).parent('.split-content, [data-editor="included-object"]').find(selector).trigger('click');
  }
  copyContents(value, label, key) {
    if ($('.edit-header .submit-edit-form').prop('disabled')) return;

    let target = $('.flex-box .edit-content [data-key="' + key + '"]');

    target.find(DataCycle.config.EditorSelectors.join(', ')).trigger('dc:import:data', {
      label: label,
      value: typeof value == 'string' ? value.trim() : value,
      locale: this.embedLocale ? this.leftLocale : ''
    });

    target.get(0).scrollIntoView({ behavior: 'smooth', block: 'end' });
  }
  translateText(elem, value, label, key) {
    let formData = {
      text: value.trim(),
      source_locale: this.leftLocale,
      target_locale: this.rightLocale
    };
    DataCycle.httpRequest({
      url: '/things/translate_text',
      method: 'POST',
      data: formData,
      dataType: 'json',
      contentType: 'application/x-www-form-urlencoded'
    })
      .done(data => {
        this.copyContents(data.text, label, key);
      })
      .fail(data => {
        CalloutHelpers.show('Fehler beim Laden der Übersetzung', 'alert');
      })
      .always(() => {
        DataCycle.enableElement(elem);
      });
  }
}

export default SplitView;

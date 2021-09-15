import CalloutHelpers from './../helpers/callout_helpers';

class SplitView {
  constructor(container = document) {
    this.$container = $(container);
    this.$leftContainer = this.$container.closest('.split-content.detail-content').first();
    this.rightContainer = this.$container.closest('.flex-box').find('.split-content.edit-content').get(0);
    this.embedLocale = this.$leftContainer.data('embed-locale');
    this.leftLocale = this.$leftContainer.data('locale');
    this.rightLocale = this.$container[0].closest('form').querySelector('input[name="locale"]').value;
    this.enableTranslateButtons = this.$leftContainer.data('enable-translate-buttons');
    this.translatableTypes = ['string', 'text_editor'];
    this.copyableTypes = [
      'object_browser',
      'embedded_object',
      'string',
      'text_editor',
      'classification',
      'date_picker',
      'geographic',
      'boolean',
      'number',
      'duration',
      'url'
    ];
    this.buttonMappings = {
      translate: {
        icon: 'fa-language',
        class: 'dc-translatable-field'
      },
      copy: {
        icon: 'fa-arrow-right',
        class: 'dc-copyable-field'
      }
    };
    this.addButtonRequests = [];

    this.setup();
  }
  setup() {
    this.setupButtons(this.$container);
    this.observeForNewFields();

    Promise.all(this.addButtonRequests).then(_values => {
      this.setupCopyAllButtons(this.$leftContainer);
      this.setupCopyAllButtons(this.availableEditors(this.$container, ['included-object']));
    });

    this.$container.on('click', '.copy', this.handleButtonClick.bind(this));
    this.$container.on('click', '.translate', this.handleButtonClick.bind(this));
    this.$container
      .closest('.split-content')
      .on('click', '.copy-all, .translate-all', this.triggerAllButtons.bind(this));
    this.$container.on(
      'dc:contents:added',
      '[data-id]:not(.dc-splitview-initialized)',
      this.setupAdditionalButtons.bind(this)
    );
    this.$container
      .closest('.split-content')
      .find('.close-subscribe-notice')
      .on('click', this.dismissSubscribeNotice.bind(this));
  }
  observeForNewFields() {
    DataCycle.newContent.callbacks.push({
      condition: e =>
        !e.classList.contains('dc-copyable-field') && e.dataset.editor && !e.closest('.detail-type.embedded'),
      callback: async e => this.setupButtons($(e))
    });

    DataCycle.newContent.callbacks.push({
      condition: e => e.classList.contains('form-element') && e.dataset.key && !e.closest('.form-element.embedded'),
      callback: async e => this.addButtonsForEditFields(e)
    });
  }
  setupButtons($container) {
    this.availableEditors($container, this.copyableTypes).each((_, elem) => {
      this.addButtons(elem);
    });

    this.availableEditors($container, ['object_browser']).each((_, elem) => {
      this.addButtons(elem, true);
    });
  }
  addButtonsForEditFields(element) {
    const key = element.dataset.key;
    const viewField = this.$leftContainer[0].querySelector(
      `[data-key*="${key.getAttributeKey()}"]:not([data-editor]:not([data-editor="included-object"]) [data-key*="${key.getAttributeKey()}"]):not(.dc-copyable-field)`
    );

    if (viewField) this.setupButtons($(viewField));
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
  availableEditors($container, selectors = []) {
    let newSelectorString = selectors.map(x => 'div[data-editor=' + x + ']').join(', ');
    let notInSelector = 'div[data-editor]:not([data-editor="included-object"]) div[data-editor]';

    return $container.find(newSelectorString).addBack(newSelectorString).not(notInSelector);
  }
  setupCopyAllButtons(elements) {
    elements.each(async (_, item) => {
      if ($(item).find('.dc-copyable-field').length) {
        if (this.enableTranslateButtons) {
          $(item).prepend(
            `<a class="button-prime small translate-all" title="${await I18n.translate(
              'frontend.split_view.translate_all'
            )}"><i class="fa fa-language" aria-hidden="true"></i></a>`
          );
        }
        $(item).prepend(
          `<a class="button-prime small copy-all" title="${await I18n.translate(
            'frontend.split_view.copy_all'
          )}"><i class="fa fa-arrow-right" aria-hidden="true"></i></a>`
        );
      }
    });
  }
  addButtons(element, single = false) {
    const key = element.dataset.key;

    const editField = this.rightContainer.querySelector(
      `[data-key*="${key.getAttributeKey()}"]:not([data-editor]:not([data-editor="included-object"]) [data-key*="${key.getAttributeKey()}"])`
    );

    if (!editField || editField.dataset.readonly == 'true') return;

    if (single && !element.classList.contains('copy-single')) {
      const singleElements = element.getElementsByClassName('copy-single');
      for (let i = 0; i < singleElements.length; i++) {
        this.addButtonRequests.push(this.renderButton(singleElements[i], single));
      }
    } else this.addButtonRequests.push(this.renderButton(element, single));
  }
  async renderButton(element, single) {
    let buttonContainer = element.querySelector(':scope > .buttons');

    if (!buttonContainer) buttonContainer = element.querySelector(':scope > .content-link > .buttons');
    if (!buttonContainer) {
      element.insertAdjacentHTML('beforeend', '<div class="buttons"></div');
      buttonContainer = element.querySelector(':scope > .buttons');
    }

    if (
      this.enableTranslateButtons &&
      (this.translatableTypes.includes(element.dataset.editor) ||
        (element.dataset.editor == 'embedded_object' && element.dataset.translatable))
    )
      await this.addSpecificButton(element, buttonContainer, single, 'translate');

    await this.addSpecificButton(element, buttonContainer, single, 'copy');
  }
  async addSpecificButton(element, buttonContainer, single, type) {
    buttonContainer.insertAdjacentHTML(
      'beforeend',
      `<a class="button-prime small ${type} ${
        single ? `${type}-single-button` : ''
      }" data-disable-with="<i class=\'fa fa-circle-o-notch fa-spin\'></i>" title="${await I18n.translate(
        `frontend.split_view.${type}`
      )}"><i class="fa ${this.buttonMappings[type].icon} aria-hidden="true"></i></a>`
    );

    element.classList.add(this.buttonMappings[type].class);
  }
  handleButtonClick(event) {
    event.preventDefault();

    const element = event.target;

    const key = element.closest('[data-key]').dataset.key;

    if (element.classList.contains('copy-single-button')) {
      console.log('copy-single');
    }

    console.log('handleButtonClick', key.getKeyPath());

    // let value = '';
    // let elem = $(event.currentTarget);
    // switch (elem.data('copy-attribute')) {
    //   case 'single-data-id':
    //     value = elem.parents('.copy-single').first().data('id');
    //     break;
    //   case 'data-id':
    //     value = elem.parents('[data-editor]').first().data('id');
    //     break;
    //   case 'data-value':
    //     value = elem.parents('[data-editor]').first().data('value');
    //     break;
    //   case 'html':
    //     value = elem.parents('[data-editor]').first().find('.detail-content').html();
    //     break;
    //   case 'href':
    //     value = elem.parents('[data-editor]').first().find('.detail-content > a').attr('href');
    //     break;
    // }

    // let label = elem.parents('[data-editor]').data('label');
    // let key = elem.parents('[data-editor]').data('key');

    // if (elem.data('translate-attribute')) {
    //   this.translateText(elem, value, label, key);
    // } else {
    //   this.copyContents(value, label, key);
    // }
  }
  triggerAllButtons(event) {
    event.preventDefault();

    const $parent = $(event.currentTarget).parent('.split-content, [data-editor="included-object"]');
    let $items;
    if (event.currentTarget.classList.contains('translate-all')) {
      $items = $parent
        .find('.dc-translatable-field > .buttons > a.translate')
        .add(
          $parent.find('.dc-copyable-field:not(.dc-translatable-field) > .buttons > a.copy:not(.copy-single-button)')
        );
    } else {
      $items = $parent.find('.dc-copyable-field > .buttons > a.copy:not(.copy-single-button)');
    }

    $items.trigger('click');
  }
  copyContents(value, label, key, translate = false) {
    if ($('.edit-header .submit-edit-form').prop('disabled')) return;

    const target = $('.flex-box .edit-content [data-key="' + key + '"]');

    target.find(DataCycle.config.EditorSelectors.join(', ')).trigger('dc:import:data', {
      label: label,
      value: typeof value == 'string' ? value.trim() : value,
      locale: this.embedLocale ? this.leftLocale : '',
      translate: translate
    });

    target.get(0).scrollIntoView({ behavior: 'smooth', block: 'end' });
  }
  translateText(elem, value, label, key) {
    if ($(elem).data('translate-attribute') == 'direct') {
      DataCycle.disableElement(elem);

      let formData = {
        text: typeof value == 'string' ? value.trim() : value,
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
        .fail(async _data => {
          CalloutHelpers.show(await I18n.translate('frontend.split_view.translate_error'), 'alert');
        })
        .always(() => {
          DataCycle.enableElement(elem);
        });
    } else {
      DataCycle.disableElement(elem);
      this.copyContents(value, label, key, true);
      DataCycle.enableElement(elem);
    }
  }
}

export default SplitView;

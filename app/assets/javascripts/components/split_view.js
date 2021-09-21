import CalloutHelpers from './../helpers/callout_helpers';
import domElementHelpers from '../helpers/dom_element_helpers';

class SplitView {
  constructor(container = document) {
    this.container = container;
    this.leftContainer = this.container.closest('.split-content.detail-content');
    this.rightContainer = this.container.closest('.flex-box').querySelector('.split-content.edit-content');
    this.embedLocale = this.leftContainer.dataset.embedLocale;
    this.leftLocale = this.leftContainer.dataset.locale;
    this.enableTranslateButtons = this.leftContainer.dataset.enableTranslateButtons;
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
    this.observeForNewFields();
    this.setupButtons(this.container);
  }
  rightLocale() {
    return this.container.closest('form').querySelector('input[name="locale"]').value;
  }
  parseDataAttribute(value) {
    if (!value) return value;

    try {
      return JSON.parse(value);
    } catch {
      return value;
    }
  }
  addSubcriberNoticeHandler() {
    const notice = this.container.closest('.split-content').querySelector('.close-subscribe-notice');

    if (notice) notice.addEventListener('click', this.dismissSubscribeNotice.bind(this));
  }
  addSingleClickHandler() {
    DataCycle.newContent.callbacks.push([
      e => e.tagName === 'A' && (e.classList.contains('copy') || e.classList.contains('translate')),
      e => e.addEventListener('click', this.handleButtonClick.bind(this))
    ]);
  }
  addAllClickHandler() {
    DataCycle.newContent.callbacks.push([
      e => e.tagName === 'A' && (e.classList.contains('copy-all') || e.classList.contains('translate-all')),
      e => e.addEventListener('click', this.triggerAllButtons.bind(this))
    ]);
  }
  observeForNewFields() {
    DataCycle.newContent.callbacks.push([
      e =>
        !e.classList.contains('dc-copyable-field') &&
        e.dataset.editor &&
        !e.closest('.detail-type.embedded:not(:scope)'),
      e => this.setupButtons(e)
    ]);

    DataCycle.newContent.callbacks.push([
      e => e.classList.contains('form-element') && e.dataset.key && !e.closest('.form-element.embedded:not(:scope)'),
      e => this.addButtonsForEditFields(e)
    ]);

    this.addSingleClickHandler();
    this.addAllClickHandler();
    this.addSubcriberNoticeHandler();
  }
  setupButtons(container) {
    const availableEditors = this.availableEditors(container, this.copyableTypes);

    for (let i = 0; i < availableEditors.length; ++i) {
      this.addButtons(availableEditors[i]);
    }

    const availableLinkedEditors = this.availableEditors(container, ['object_browser']);
    for (let i = 0; i < availableLinkedEditors.length; ++i) {
      this.addButtons(availableLinkedEditors[i], true);
    }
  }
  addButtonsForEditFields(element) {
    const key = element.dataset.key;
    const viewFields = this.findFieldsByKey(key, this.leftContainer);

    for (let i = 0; i < viewFields.length; ++i) {
      this.setupButtons(viewFields[i]);
    }
  }
  findFieldsByKey(key, container) {
    return Array.from(
      container.querySelectorAll(
        `[data-key*="[${key.getAttributeKey()}]"]:not([data-editor]:not([data-editor="included-object"]) [data-key*="[${key.getAttributeKey()}]"]):not(.dc-copyable-field)`
      )
    ).filter(domElementHelpers.isVisible.bind(this));
  }
  dismissSubscribeNotice(_event) {
    document.cookie = 'subscribe_notice_dismissed=true';
  }
  availableEditors(container, selectors = []) {
    const newSelectorString = selectors
      .map(
        x => `:scope div[data-editor=${x}]:not(div[data-editor]:not([data-editor="included-object"]) div[data-editor])`
      )
      .join(', ');

    const results = [...container.querySelectorAll(newSelectorString)];

    if (container.dataset.editor && selectors.includes(container.dataset.editor)) results.push(container);

    return results;
  }
  addButtons(element, single = false) {
    const key = element.dataset.key;
    const editField = this.findFieldsByKey(key, this.rightContainer)[0];

    if (!editField || editField.dataset.readonly == 'true') return;

    this.addElementClasses(element);

    if (single && !element.classList.contains('copy-single')) {
      const singleElements = element.getElementsByClassName('copy-single');
      for (let i = 0; i < singleElements.length; i++) {
        this.renderButton(singleElements[i], single);
      }
    } else this.renderButton(element, single);
  }
  async addAllButton(element, type) {
    let container = element.closest('[data-editor="included-object"], .split-content.detail-content');

    if (container.classList.contains(`show-${type}-all-button`)) return;

    if (!container.querySelector(':scope > .split-view-all-buttons'))
      container.insertAdjacentHTML('afterbegin', '<div class="split-view-all-buttons"></div>');
    const buttonsContainer = container.querySelector(':scope > .split-view-all-buttons');

    container.classList.add(`show-${type}-all-button`);

    await buttonsContainer.insertAdjacentHTML(
      'afterbegin',
      `<a class="button-prime small ${type}-all" title="${await I18n.translate(
        `frontend.split_view.${type}_all`
      )}"><i class="fa ${this.buttonMappings[type].icon}" aria-hidden="true"></i></a>`
    );
  }
  async addElementClasses(element) {
    if (this.isTranslatable(element)) {
      await this.addAllButton(element, 'translate');
      element.classList.add(this.buttonMappings['translate'].class);
    }

    await this.addAllButton(element, 'copy');
    element.classList.add(this.buttonMappings['copy'].class);
  }
  isTranslatable(element) {
    return (
      this.enableTranslateButtons &&
      (this.translatableTypes.includes(element.dataset.editor) ||
        (element.dataset.editor == 'embedded_object' && element.dataset.translatable))
    );
  }
  async renderButton(element, single) {
    let buttonContainer = element.querySelector(':scope > .buttons');

    if (!buttonContainer) buttonContainer = element.querySelector(':scope > .content-link > .buttons');
    if (!buttonContainer) {
      element.insertAdjacentHTML('beforeend', '<div class="buttons"></div');
      buttonContainer = element.querySelector(':scope > .buttons');
    }

    if (this.isTranslatable(element)) await this.addSpecificButton(buttonContainer, single, 'translate');

    await this.addSpecificButton(buttonContainer, single, 'copy');
  }
  async addSpecificButton(buttonContainer, single, type) {
    buttonContainer.insertAdjacentHTML(
      'beforeend',
      `<a class="button-prime small ${type} ${
        single ? `${type}-single-button` : ''
      }" data-disable-with="<i class=\'fa fa-circle-o-notch fa-spin\'></i>" title="${await I18n.translate(
        `frontend.split_view.${type}`
      )}"><i class="fa ${this.buttonMappings[type].icon} aria-hidden="true"></i></a>`
    );
  }
  loadValue(keys) {
    return DataCycle.httpRequest({
      url: `/things/${this.leftContainer.dataset.id}/attribute_value`,
      method: 'POST',
      data: {
        locale: this.leftLocale,
        keys: keys
      },
      dataType: 'json'
    });
  }
  async handleButtonClick(event) {
    event.preventDefault();

    const button = event.currentTarget;

    DataCycle.disableElement(button);

    const container = button.closest('[data-editor]');
    const linkedOrEmbedded = button.closest('.embedded[data-id], li.item[data-id]');
    const key = container.dataset.key;
    let value;

    if (linkedOrEmbedded) {
      if (linkedOrEmbedded) value = this.parseDataAttribute(linkedOrEmbedded.dataset.id);
    } else {
      const response = await this.loadValue([key]);
      if (response && response[key]) value = response[key];
    }

    if (!value && value !== false) return DataCycle.enableElement(button);

    if (button.classList.contains('translate')) await this.translateText(container.dataset.editor, value, key);
    else await this.copyContents(value, key);

    DataCycle.enableElement(button);
  }
  triggerAllButtons(event) {
    event.preventDefault();

    const target = event.currentTarget;

    const parent = target.closest('.split-content, [data-editor="included-object"]');
    let items;
    if (target.classList.contains('translate-all')) {
      items = [
        ...parent.querySelectorAll(':scope .dc-translatable-field > .buttons > a.translate'),
        ...parent.querySelectorAll(
          ':scope .dc-copyable-field:not(.dc-translatable-field) > .buttons > a.copy:not(.copy-single-button)'
        )
      ];
    } else {
      items = parent.querySelectorAll(':scope .dc-copyable-field > .buttons > a.copy:not(.copy-single-button)');
    }

    for (let i = 0; i < items.length; ++i) {
      items[i].click();
    }
  }
  async copyContents(value, key, translate = false) {
    const submitButton = document.querySelector('.edit-header .submit-edit-form');

    if (submitButton && submitButton.disabled) return;

    const target = this.findFieldsByKey(key, this.rightContainer)[0];

    await $(target)
      .find(DataCycle.config.EditorSelectors.join(', '))
      .trigger('dc:import:data', {
        value: typeof value == 'string' ? value.trim() : value,
        locale: this.embedLocale ? this.leftLocale : '',
        translate: translate
      });

    target.scrollIntoView({ behavior: 'smooth', block: 'end' });
  }
  async translateText(editor, value, key) {
    if (this.translatableTypes.includes(editor)) {
      let formData = {
        text: typeof value == 'string' ? value.trim() : value,
        source_locale: this.leftLocale,
        target_locale: this.rightLocale()
      };

      const translatedValue = await DataCycle.httpRequest({
        url: '/things/translate_text',
        method: 'POST',
        data: formData,
        dataType: 'json',
        contentType: 'application/x-www-form-urlencoded'
      }).fail(async _data => {
        CalloutHelpers.show(await I18n.translate('frontend.split_view.translate_error'), 'alert');
      });

      await this.copyContents(translatedValue.text, key);
    } else {
      await this.copyContents(value, key, true);
    }
  }
}

export default SplitView;

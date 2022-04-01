import domElementHelpers from '../helpers/dom_element_helpers';

class ConfirmationModal {
  constructor(config = {}) {
    this.confirmationCallback = config.confirmationCallback;
    this.cancelCallback = config.cancelCallback;
    this.preventCancelOnAbort = config.preventCancelOnAbort || false;
    this.confirmationClass = config.confirmationClass || '';
    this.cancelable = config.cancelable;
    this.text = config.text || '';
    this.confirmationText = config.confirmationText;
    this.cancelText = config.cancelText;
    this.confirmationIndex = 1;
    this.wrapperHtml =
      '<div class="reveal confirmation-modal" data-multiple-opened="true"><button class="close-button" data-close aria-label="Close modal" type="button"><span aria-hidden="true">&times;</span></button></div';
    this.overlay;
    this.closed = false;
    this.section;

    this.setup();
  }
  async setup() {
    this.section = $(await this.renderSectionHtml());

    if ($('.confirmation-modal:visible').length) {
      this.overlay = $('.confirmation-modal:visible').first().append(this.section);
      this.confirmationIndex = this.overlay.find('section.confirmation-section').length;

      if (this.overlay.find('.confirmation-info').length)
        this.overlay.find('.confirmation-count').text(this.confirmationIndex);
      else
        this.overlay.append(
          '<div class="confirmation-info"><span class="confirmation-index">1</span> / <span class="confirmation-count">' +
            this.confirmationIndex +
            '</span></div>'
        );
    } else {
      this.overlay = $(this.wrapperHtml).append(this.section).appendTo('body');
      new Foundation.Reveal(this.overlay);
      this.overlay.foundation('open');
    }

    this.addEvents();
  }
  async renderSectionHtml() {
    return `<section class="confirmation-section"><div class="confirmation-text">${
      this.text
    }</div><div class="confirmation-buttons">${
      this.cancelable
        ? `<a class="confirmation-cancel button" aria-label="Cancel">${
            this.cancelText || (await I18n.translate('frontend.cancel'))
          }</a>`
        : ''
    }<a class="confirmation-confirm button ${this.confirmationClass}" aria-label="Confirm">${
      this.confirmationText || (await I18n.translate('frontend.ok'))
    }</a></div></section>`;
  }
  updateConfirmationIndex(_event) {
    this.overlay.find('.confirmation-index').text(this.confirmationIndex);
  }
  addEvents() {
    this.section.find('.confirmation-confirm').on('click', this.confirm.bind(this));
    this.section.find('.confirmation-cancel').on('click', this.cancel.bind(this));
    this.overlay.on('closed.zf.reveal', _event => {
      if (!this.closed && !this.preventCancelOnAbort) this.close('cancelCallback', true);
    });

    this.section.on('dc:confirmation_count:update', this.updateConfirmationIndex.bind(this));
    this.section.on(
      {
        mouseenter: this.focusSpecificFields.bind(this),
        mouseleave: this.focusSpecificFields.bind(this)
      },
      '.focus-specific-field'
    );
  }
  cancel(event) {
    event.preventDefault();
    event.stopImmediatePropagation();
    this.close('cancelCallback');
  }
  confirm(event) {
    event.preventDefault();
    event.stopImmediatePropagation();
    this.close('confirmationCallback');
  }
  close(method_name, closeAll = false) {
    if (
      this.overlay.is(':visible') &&
      (closeAll || this.overlay.children('section.confirmation-section').length == 1)
    ) {
      this.closed = true;
      this.overlay.foundation('close').parent('.reveal-overlay').remove();
    } else if (this.overlay.is(':visible')) {
      this.section.remove();
      this.overlay.find('section.confirmation-section:visible').trigger('dc:confirmation_count:update');
    }

    if (typeof this[method_name] == 'function') {
      this[method_name]();
    }
  }
  focusSpecificFields(event) {
    const fieldId = event.currentTarget.dataset.fieldId;
    if (!fieldId) return;

    const elements = document.querySelectorAll(`[data-focus-id="${fieldId}"]`);
    const elementMethod = event.type == 'mouseenter' ? this._showSpecificField : this._hideSpecificField;
    const overlayRect = this.overlay[0].getBoundingClientRect();
    const fieldOffset = overlayRect.top + overlayRect.height + 20;

    for (let i = 0; i < elements.length; ++i) {
      elementMethod.call(this, elements[i], fieldOffset, elements.length > 1);
    }
  }
  _showAncestors(ancestors) {
    for (let i = 0; i < ancestors.length; ++i) {
      const field = ancestors[i];
      if (domElementHelpers.isVisible(field)) continue;

      if (field.style.display) field.dataset.oldDisplayValue = field.style.display;
      field.classList.add('dc-focus-show-ancestor');
      field.style.display = 'block';
    }
  }
  _hideAncestors(ancestors) {
    for (let i = 0; i < ancestors.length; ++i) {
      const field = ancestors[i];
      if (!domElementHelpers.isVisible(field) || !field.classList.contains('dc-focus-show-ancestor')) continue;

      field.classList.remove('dc-focus-show-ancestor');
      if (field.dataset.oldDisplayValue) field.style.display = field.dataset.oldDisplayValue;
      else if (field.style.display) field.style.removeProperty('display');
    }
  }
  _showSpecificField(field, fieldOffset, multiple = true) {
    if (field.style.top) field.dataset.oldTopValue = field.style.top;
    if (field.style.opacity) field.dataset.oldOpacityValue = field.style.opacity;
    if (field.style.left) field.dataset.oldLeftValue = field.style.left;

    field.style.opacity = 0;

    window.requestAnimationFrame(() => {
      const ancestors = domElementHelpers.findAncestors(field, domElementHelpers.isHidden);
      this._showAncestors(ancestors.reverse());

      let leftOffset = `${field.getBoundingClientRect().left}px`;

      field.classList.add('dc-focus-field');
      field.style.top = `${fieldOffset}px`;

      if (!multiple) leftOffset = `calc(50% - ${field.getBoundingClientRect().width}px / 2)`;

      field.style.left = leftOffset;
    });

    window.requestAnimationFrame(() => {
      field.style.opacity = 1;
    });
  }
  _hideSpecificField(field, _fieldOffset, _multiple = true) {
    if (!field.classList.contains('dc-focus-field')) return;

    field.style.opacity = 0;

    setTimeout(() => {
      const ancestors = domElementHelpers.findAncestors(field, e => e.classList.contains('dc-focus-show-ancestor'));
      this._hideAncestors(ancestors);
      field.style.removeProperty('opacity');
      field.style.removeProperty('top');
      field.style.removeProperty('left');
      field.classList.remove('dc-focus-field');
      if (field.style.oldTopValue) field.style.top = field.dataset.oldTopValue;
      if (field.style.oldOpacityValue) field.style.opacity = field.dataset.oldOpacityValue;
      if (field.style.oldLeftValue) field.style.left = field.dataset.oldLeftValue;
    }, 100);
  }
}

export default ConfirmationModal;

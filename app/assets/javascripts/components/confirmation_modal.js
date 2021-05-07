class ConfirmationModal {
  constructor(config = {}) {
    this.confirmationCallback = config.confirmationCallback;
    this.cancelCallback = config.cancelCallback;
    this.confirmationClass = config.confirmationClass || '';
    this.cancelable = config.cancelable;
    this.text = config.text || '';
    this.confirmationText = config.confirmationText || 'Ok';
    this.cancelText = config.cancelText || 'Abbrechen';
    this.confirmationIndex = 1;
    this.wrapperHtml =
      '<div class="reveal confirmation-modal" data-multiple-opened="true"><button class="close-button" data-close aria-label="Close modal" type="button"><span aria-hidden="true">&times;</span></button></div';
    this.overlay;
    this.closed = false;
    this.section;

    this.setup();
  }
  setup() {
    this.section = $(this.renderSectionHtml());
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
  renderSectionHtml() {
    return (
      '<section class="confirmation-section"><div class="confirmation-text">' +
      this.text +
      '</div><div class="confirmation-buttons">' +
      (this.cancelable ? '<a class="confirmation-cancel button" aria-label="Cancel">' + this.cancelText + '</a>' : '') +
      '<a class="confirmation-confirm button ' +
      this.confirmationClass +
      '" aria-label="Confirm">' +
      this.confirmationText +
      '</a></div></section>'
    );
  }
  updateConfirmationIndex(event) {
    this.overlay.find('.confirmation-index').text(this.confirmationIndex);
  }
  addEvents() {
    this.section.find('.confirmation-confirm').on('click', this.confirm.bind(this));
    this.section.find('.confirmation-cancel').on('click', this.cancel.bind(this));
    this.overlay.on('closed.zf.reveal', _event => {
      if (!this.closed) this.close('cancelCallback', true);
    });

    this.section.on('dc:confirmation_count:update', this.updateConfirmationIndex.bind(this));
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
}

export default ConfirmationModal;

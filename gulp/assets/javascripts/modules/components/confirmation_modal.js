// confirmation modal
var ConfirmationModal = function(
  text = '',
  buttonClass = '',
  cancelable = false,
  confirmationCallback = null,
  cancelCallback = null
) {
  this.confirmationCallback = confirmationCallback;
  this.cancelCallback = cancelCallback;
  this.buttonClass = buttonClass;
  this.cancelable = cancelable;
  this.text = text;
  this.html = '';
  this.reveal;
  this.confirmed = false;
  this.overlay;

  this.setup();
};

ConfirmationModal.prototype.setup = function() {
  this.html =
    '<div class="reveal confirmation-modal" data-multiple-opened="true"><div class="confirmation-text">' +
    this.text +
    '</div><div class="confirmation-buttons">' +
    (this.cancelable ? '<a class="confirmation-cancel button" data-close aria-label="Cancel">Abbrechen</a>' : '') +
    '<a class="confirmation-confirm button ' +
    this.buttonClass +
    '" aria-label="Confirm">Ok</a></div><button class="close-button" data-close aria-label="Close modal" type="button"><span aria-hidden="true">×</span></button></div>';

  this.overlay = $(this.html).appendTo('body');
  this.reveal = new Foundation.Reveal(this.overlay);
  this.reveal.open();
  this.addEvents();
};

ConfirmationModal.prototype.addEvents = function() {
  this.overlay.find('.confirmation-confirm').on('click', this.confirm.bind(this));
  this.overlay.on('closed.zf.reveal', this.cancel.bind(this));
};

ConfirmationModal.prototype.cancel = function(event) {
  event.preventDefault();
  event.stopImmediatePropagation();
  this.overlay.parent('.reveal-overlay').remove();
  if (!this.confirmed && this.cancelCallback != null) this.cancelCallback();
};

ConfirmationModal.prototype.confirm = function(event) {
  let close = !this.confirmed;
  this.confirmed = true;
  this.reveal.close();
  if (this.confirmationCallback != null && close) this.confirmationCallback();
};

module.exports = ConfirmationModal;

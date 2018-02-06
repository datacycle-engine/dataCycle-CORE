// confirmation modal
var ConfirmationModal = function (text = '', buttonClass = '', cancelable = false, confirmationCallback = null) {
  this.confirmationCallback = confirmationCallback;
  this.buttonClass = buttonClass;
  this.cancelable = cancelable;
  this.text = text;
  this.html = '';
  this.id = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
  this.setup();
};

ConfirmationModal.prototype.setup = function () {
  this.html = '<div id="' + this.id + '" class="confirmation-modal-overlay"><div class="confirmation-modal">';
  this.html += '<div class="confirmation-text">' + this.text + '</div>';
  this.html += '<div class="confirmation-buttons">';
  if (this.cancelable) this.html += '<a class="confirmation-cancel button" href="#" aria-label="Cancel" >Abbrechen</a>';
  this.html += '<a href="#" class="confirmation-confirm button ' + this.buttonClass + '" aria-label="Confirm">Ok</a></div>';
  this.html += '<button class="close-button" aria-label="Close modal" type="button"><span aria-hidden="true">&times;</span></button>';
  this.html += '</div></div>';

  $('body').addClass('no-overflow');
  $(this.html).appendTo('body').focus().addClass('visible');
  this.addEvents();
};

ConfirmationModal.prototype.addEvents = function () {
  var self = this;
  $('#' + this.id).on('click', function (event) {
    if (event.target !== this) return;
    self.close();
  });
  $('#' + this.id + ' .close-button, #' + this.id + ' .confirmation-cancel').on('click', this.close.bind(this));

  $('#' + this.id + ' .confirmation-confirm').on('click', this.confirm.bind(this));
  $(document).on('keydown', function (event) {
    event.preventDefault();
    if (event.which == 13) self.confirm();
    else if (event.which == 27) self.close();
  });
};

ConfirmationModal.prototype.confirm = function () {
  this.close();
  if (this.confirmationCallback != null) this.confirmationCallback();
};

ConfirmationModal.prototype.close = function () {
  $('#' + this.id + ', #' + this.id + '.close-button, #' + this.id + '.confirmation-cancel, #' + this.id + '.confirmation-confirm').off('click');
  $(document).off('keydown');

  $('#' + this.id).removeClass('visible').one("webkitTransitionEnd otransitionend oTransitionEnd msTransitionEnd transitionend", function (event) {
    $(this).remove();
    $('body').removeClass('no-overflow');
  });
};

module.exports = ConfirmationModal;

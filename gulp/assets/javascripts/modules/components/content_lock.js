// Content Lock
let ConfirmationModal = require('./../components/confirmation_modal');
let ActionCable = require('actioncable');
let DurationHelpers = require('./../helpers/duration_helpers');

class ContentLock {
  constructor(button) {
    this.button = $(button);
    this.editable = this.button.hasClass('editable-lock');
    this.lockedUntilString = parseInt(this.button.data('locked-until'));
    this.lockedUntil = new Date(this.lockedUntilString * 1000);
    this.lockLength = parseInt(this.button.data('lock-length'));
    this.lockRenewBefore = parseInt(this.button.data('lock-renew-before'));
    this.lockCheckInterval = 1; // Math.max(this.lockLength / 360, 1);
    this.lockStateInterval;
    this.renewNotified = false;
    this.renewPath = this.button.data('lock-renew-path');
    this.unlockPath = this.button.data('lock-unlock-path');
    this.uuid = this.button.data('lock-content-id');
    this.actionCable;
    this.lockContentChannel;
    this.confirmationModal = null;
    this.csrfToken = document.querySelector('meta[name=csrf-token]').getAttribute('content');
    this.csrfParam = document.querySelector('meta[name=csrf-param]').getAttribute('content');

    this.setup();
  }
  setup() {
    this.button.on('click', '.pie-text', event => {
      event.preventDefault();
      event.stopImmediatePropagation();
    });

    this.button.on('mouseenter', '.pie-text', event => {
      this.button.find('.pie-text').removeClass('show');
    });

    this.initActionCable();
    this.checkLockState();

    this.lockStateInterval = setInterval(this.checkLockState.bind(this), this.lockCheckInterval * 1000);

    if (this.editable) {
      $(window).on('beforeunload', event => {
        let data = new FormData();
        data.append(this.csrfParam, this.csrfToken);
        navigator.sendBeacon(this.unlockPath, data);
      });
    }
  }
  initActionCable() {
    this.actionCable = ActionCable.createConsumer();
    this.lockContentChannel = this.actionCable.subscriptions.create(
      {
        channel: 'DataCycleCore::ContentLockChannel',
        content_id: this.uuid
      },
      {
        received: data => {
          if (data.create && data.locked_until !== undefined) this.lockContent(data.locked_until, data.button_text);
          else if (data.locked_until !== undefined) this.renewLock(data.locked_until);
          else if (data.remove_lock) this.unlockButton();
        }
      }
    );
  }
  lockContent(lockedUntil, buttonText = '') {
    this.lockedUntil = new Date(parseInt(lockedUntil) * 1000);
    $('#' + this.button.data('toggle')).append(buttonText);

    this.checkLockState();
    this.button.prop('disabled', true).addClass('content-locked');
    this.lockStateInterval = setInterval(this.checkLockState.bind(this), this.lockCheckInterval * 1000);
  }
  renderCountDown(diffSeconds) {
    this.button.find('.pie-text').text(DurationHelpers.seconds_to_human_time(diffSeconds));
    $('#' + this.button.data('toggle'))
      .find('.locked-until')
      .text(Math.ceil(diffSeconds / 60) + 'min');

    let degree = 360 - parseInt((diffSeconds * 360) / this.lockLength);
    if (degree > 180) {
      this.button
        .find('.pie-timer > .pie-filler')
        .addClass('greater180')
        .css('transform', 'rotate(' + (degree - 180) + 'deg)');
    } else {
      this.button
        .find('.pie-timer > .pie-filler')
        .removeClass('greater180')
        .css('transform', 'rotate(' + degree + 'deg)');
    }
  }
  checkLockState() {
    let diffSeconds = Math.max(0, parseInt((this.lockedUntil - Date.now()) / 1000));
    let diffMinutes = parseInt(diffSeconds / 60);

    this.renderCountDown(diffSeconds);
    if (diffSeconds <= 0 && this.editable) return this.lockEditor();
    else if (diffSeconds <= 0) return this.unlockButton();

    if (!this.renewNotified && this.editable && diffSeconds <= this.lockRenewBefore) {
      this.button.find('.pie-text').addClass('show');
      this.renewNotified = true;
      this.confirmationModal = new ConfirmationModal({
        text:
          'Der Inhalt wird in ' +
          diffMinutes +
          'min wieder freigegeben. <br><br>Wollen Sie die Sperre um ' +
          this.lockLength / 60 +
          'min verlängern?',
        confirmationText: 'Ja',
        cancelText: 'Nein',
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: this.triggerRenewLock.bind(this),
        cancelCallback: this.removeConfirmationModal.bind(this)
      });
    }
  }
  triggerRenewLock() {
    this.removeConfirmationModal(null);
    $.get(this.renewPath).fail(() => {
      console.log('error renewing the lock');
    });
  }
  renewLock(lockedUntil) {
    this.lockedUntil = new Date(parseInt(lockedUntil) * 1000);
    this.renewNotified = false;
    this.button.find('.pie-text').removeClass('show');
  }
  lockEditor() {
    clearInterval(this.lockStateInterval);
    this.lockContentChannel.unsubscribe();

    this.button.find('.pie-timer, .pie-text').addClass('alert');
    this.button
      .find('.pie-text')
      .addClass('show')
      .text('Der Inhalt wurde wieder freigegeben und kann nicht mehr gespeichert werden.');

    if (this.confirmationModal !== null) this.confirmationModal.overlay.foundation('close');
    this.button
      .removeAttr('data-disable-with')
      .removeData('disable-with')
      .prop('disabled', true);
    this.button
      .closest('.edit-header')
      .siblings('form')
      .trigger('dc:form:disable');
  }
  removeConfirmationModal(_) {
    this.confirmationModal = null;
  }
  unlockButton() {
    clearInterval(this.lockStateInterval);
    this.button.prop('disabled', false).removeClass('content-locked');
    $('#' + this.button.data('toggle'))
      .find('.content-locked-text')
      .remove();
  }
}

module.exports = ContentLock;

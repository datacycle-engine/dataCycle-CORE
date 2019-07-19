// Content Lock
let ConfirmationModal = require('./../components/confirmation_modal');
let ActionCable = require('actioncable');

class ContentLock {
  constructor(button, editView = false) {
    this.button = $(button);
    this.editView = editView;
    this.lockedUntilString = parseInt(this.button.data('locked-until')) - 10;
    this.lockedUntil = new Date(this.lockedUntilString * 1000);
    this.lockLength = parseInt(this.button.data('lock-length'));
    this.lockRenewBefore = parseInt(this.button.data('lock-renew-before'));
    this.lockCheckInterval = this.lockLength / 360;
    this.lockStateInterval;
    this.renewNotified = false;
    this.renewPath = this.button.data('lock-renew-path');
    this.uuid = this.button.data('lock-content-id');
    this.actionCable;
    this.lockContentChannel;
    this.pieTimer = this.button.find('.pie-timer');
    this.pieFiller = this.button.find('.pie-timer > .pie-filler');
    this.confirmationModal = null;

    this.setup();
  }
  setup() {
    console.log(this.lockLength);
    console.log(this.lockRenewBefore);
    console.log(this.lockCheckInterval);

    this.initActionCable();

    this.lockStateInterval = setInterval(this.checkLockState.bind(this), this.lockCheckInterval * 1000);
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
          if (data.locked_until !== undefined) {
            this.renewLock(data.locked_until);
          }
        }
      }
    );
  }
  renderCountDown(diffSeconds) {
    let percent = (diffSeconds * 100) / this.lockLength;
    let degree = 360 - parseInt((diffSeconds * 360) / this.lockLength);
    if (degree > 180) {
      this.pieFiller.addClass('greater180').css('transform', 'rotate(' + (degree - 180) + 'deg)');
    } else {
      this.pieFiller.removeClass('greater180').css('transform', 'rotate(' + degree + 'deg)');
    }

    console.log(degree);
  }
  checkLockState() {
    let diffSeconds = Math.max(0, parseInt((this.lockedUntil - Date.now()) / 1000));
    let diffMinutes = parseInt(diffSeconds / 60);

    this.renderCountDown(diffSeconds);
    if (diffSeconds <= 0) return this.lockEditor();

    if (!this.renewNotified && this.editView && diffSeconds <= this.lockRenewBefore) {
      this.renewNotified = true;
      this.confirmationModal = new ConfirmationModal({
        text:
          'Der Inhalt wird in ' +
          diffMinutes +
          'min wieder freigegeben. <br><br>Wollen Sie die Sperre um 30min verlängern?',
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
    this.lockedUntil = new Date((parseInt(lockedUntil) - 10) * 1000);
    this.renewNotified = false;
  }
  lockEditor() {
    clearInterval(this.lockStateInterval);

    if (this.confirmationModal !== null) {
      console.log(this.confirmationModal.overlay.foundation('close'));
    }
    this.button.removeAttr('data-disable-with').prop('disabled', true);
  }
  removeConfirmationModal(_) {
    this.confirmationModal = null;
  }
}

module.exports = ContentLock;

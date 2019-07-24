// Content Lock
let ConfirmationModal = require('./../components/confirmation_modal');
let ActionCable = require('actioncable');
let DurationHelpers = require('./../helpers/duration_helpers');

class ContentLock {
  constructor(button) {
    this.button = $(button);
    this.editable = this.button.hasClass('editable-lock');
    this.lockedUntil = {};
    this.lockLength = parseInt(this.button.data('lock-length'));
    this.lockRenewBefore = parseInt(this.button.data('lock-renew-before'));
    this.buttonDataDisableWith = this.button.data('disable-with');
    this.lockCheckInterval = 1;
    this.lockStateInterval;
    this.renewNotified = false;
    this.lockPath = this.button.data('lock-path');
    this.oldLockPath = this.uuid = this.button.data('lock-content-id');
    this.userId = this.button.data('lock-user-id');
    this.actionCable;
    this.lockContentChannel;
    this.confirmationModal = null;
    this.csrfToken = document.querySelector('meta[name=csrf-token]').getAttribute('content');
    this.csrfParam = document.querySelector('meta[name=csrf-param]').getAttribute('content');

    this.setup();
  }
  setup() {
    this.calculateLockedUntil(this.button.data('locked-until'));

    this.button.on('click', '.pie-text', event => {
      event.preventDefault();
      event.stopImmediatePropagation();
    });

    this.button.closest('.edit-header').on('mouseenter', event => {
      this.button.find('.pie-text').removeClass('show');
    });

    this.initActionCable();
    this.checkLockState();

    this.lockStateInterval = setInterval(this.checkLockState.bind(this), this.lockCheckInterval * 1000);

    if (this.editable) {
      $(window).on('unload', this.leavePage.bind(this));
    }
  }
  leavePage(event) {
    this.lockContentChannel.unsubscribe();
    let data = new FormData();
    data.append(this.csrfParam, this.csrfToken);
    navigator.sendBeacon(this.lockPath, data);
  }
  calculateLockedUntil(lockedUntil = {}) {
    for (let key in lockedUntil) {
      if (lockedUntil.hasOwnProperty(key)) lockedUntil[key] = new Date((parseInt(lockedUntil[key]) - 5) * 1000);
    }

    Object.assign(this.lockedUntil, lockedUntil);
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
          if (data.create && data.locked_until !== undefined && data.user_id != this.userId && !this.editable)
            this.newLock(data.lock_id, data.locked_until, data.button_text);
          else if (
            data.locked_until !== undefined &&
            ((data.user_id != this.userId && !this.editable) || (data.user_id == this.userId && this.editable))
          )
            this.renewLock(data.lock_id, data.locked_until);
          else if (data.remove_lock && data.user_id != this.userId && !this.editable) this.unlockButton(data.lock_id);
          else if (data.remove_lock && data.user_id == this.userId && this.editable) this.lockEditor(data.lock_id);
        }
      }
    );
  }
  newLock(lockId, lockedUntil, buttonText = '') {
    let isFirst = Object.keys(this.lockedUntil).length === 0 && this.lockedUntil.constructor === Object;
    this.calculateLockedUntil({ [lockId]: lockedUntil });

    if (
      $('#' + this.button.closest('.has-tip').data('toggle') + ' .content-locked-text').length &&
      !$('#' + this.button.closest('.has-tip').data('toggle') + ' .content-locked-text#content-lock-' + lockId).length
    ) {
      $('#' + this.button.closest('.has-tip').data('toggle') + ' .content-locked-text')
        .first()
        .before(buttonText);
    } else if (!$('#' + this.button.closest('.has-tip').data('toggle') + ' .content-locked-text').length) {
      $('#' + this.button.closest('.has-tip').data('toggle')).append(buttonText);
    }

    if (isFirst) {
      this.button.prop('disabled', true).addClass('content-locked');
      this.checkLockState();
      this.lockStateInterval = setInterval(this.checkLockState.bind(this), this.lockCheckInterval * 1000);
    }
  }
  renderCountDown(diffSeconds) {
    this.button.find('.pie-text').text(DurationHelpers.seconds_to_human_time(diffSeconds));

    for (let [key, value] of Object.entries(this.lockedUntil)) {
      $(
        '#' +
          this.button.closest('.has-tip').data('toggle') +
          ' .content-locked-text#content-lock-' +
          key +
          ' .locked-until'
      ).text(Math.max(0, parseInt((value - Date.now()) / (1000 * 60))) + 'min');
    }

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
    let diffSeconds = Math.max(
      0,
      parseInt((Math.max.apply(null, Object.values(this.lockedUntil)) - Date.now()) / 1000)
    );
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
    $.ajax({
      url: this.lockPath,
      type: 'PATCH'
    }).fail(() => {
      console.log('error renewing the lock');
    });
  }
  renewLock(lockId, lockedUntil) {
    this.calculateLockedUntil({ [lockId]: lockedUntil });
    this.renewNotified = false;
    this.button.find('.pie-text').removeClass('show');
  }
  lockEditor(lockId) {
    delete this.lockedUntil[lockId];

    if (Object.keys(this.lockedUntil).length === 0 && this.lockedUntil.constructor === Object) {
      clearInterval(this.lockStateInterval);

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
  }
  removeConfirmationModal(_) {
    this.confirmationModal = null;
  }
  unlockButton(lockId) {
    delete this.lockedUntil[lockId];
    $('#' + this.button.closest('.has-tip').data('toggle') + ' .content-locked-text#content-lock-' + lockId).remove();

    if (Object.keys(this.lockedUntil).length === 0 && this.lockedUntil.constructor === Object) {
      clearInterval(this.lockStateInterval);
      this.button.prop('disabled', false).removeClass('content-locked');
    }
  }
}

module.exports = ContentLock;

// Content Lock
let ConfirmationModal = require('./../components/confirmation_modal');
let DurationHelpers = require('./../helpers/duration_helpers');

class ContentLock {
  constructor(button) {
    this.button = $(button);
    this.editable = this.button.hasClass('editable-lock');
    this.locks = {};
    this.lockLength = parseInt(this.button.data('lock-length'));
    this.lockRenewBefore = parseInt(this.button.data('lock-renew-before'));
    this.buttonDataDisableWith = this.button.data('disable-with');
    this.lockCheckInterval = 1;
    this.lockStateInterval;
    this.renewNotified = false;
    this.lockPath = this.button.data('lock-path');
    this.uuid = this.button.data('lock-content-id');
    this.userId = this.button.data('lock-user-id');
    this.checkLockPath = this.button.data('lock-check-path');
    this.lockContentChannel;
    this.confirmationModal = null;
    this.removableLockIds = [];
    this.editOffset = 5;

    this.setup();
  }
  setup() {
    this.initActionCable();
    this.calculateLockedUntil(this.button.data('locks'));

    this.button.on('click', '.pie-text', event => {
      event.preventDefault();
      event.stopImmediatePropagation();
    });

    this.button.closest('.edit-header').on('mouseenter', event => {
      this.button.find('.pie-text').removeClass('show');
    });

    if (Object.keys(this.locks).length !== 0 && this.locks.constructor === Object) {
      this.checkLockState();
      this.lockStateInterval = setInterval(this.checkLockState.bind(this), this.lockCheckInterval * 1000);
    }

    if (this.editable) {
      $(window).on('beforeunload', this.setRemoveableLocks.bind(this));
      $(window).on('unload', this.leavePage.bind(this));
    }
    if (!this.editable) this.checkInitialLockState();
  }
  checkInitialLockState() {
    $.getJSON(this.checkLockPath).done(data => {
      if (data !== undefined) this.updateLocks(data.locks, data.texts);
    });
  }
  updateLocks(newLocks = {}, texts = {}) {
    for (let key in this.locks) {
      if (this.locks.hasOwnProperty(key)) this.unlockButton(key);
    }

    if (Object.keys(newLocks).length !== 0 && newLocks.constructor === Object) {
      for (let key in newLocks) {
        if (newLocks.hasOwnProperty(key)) this.newLock(key, newLocks[key], texts[key]);
      }
    }
  }
  setRemoveableLocks() {
    this.removableLockIds = Object.keys(this.locks);
  }
  leavePage(event) {
    this.lockContentChannel.unsubscribe();
    let data = new FormData();
    data.append(
      document.querySelector('meta[name=csrf-param]').getAttribute('content'),
      document.querySelector('meta[name=csrf-token]').getAttribute('content')
    );
    this.removableLockIds.forEach(lock_id => {
      data.append('lock_ids[]', lock_id);
    });

    navigator.sendBeacon(this.lockPath, data);
  }
  calculateLockedUntil(lockedUntil = {}) {
    for (let key in lockedUntil) {
      if (lockedUntil.hasOwnProperty(key)) lockedUntil[key] = new Date(parseInt(lockedUntil[key]) * 1000);
    }

    Object.assign(this.locks, lockedUntil);
  }
  initActionCable() {
    this.lockContentChannel = window.actionCable.subscriptions.create(
      {
        channel: 'DataCycleCore::ContentLockChannel',
        content_id: this.uuid
      },
      {
        received: data => {
          if (data.create && data.locked_until !== undefined && !this.editable)
            this.newLock(data.lock_id, data.locked_until, data.button_text);
          else if (data.locked_until !== undefined) this.renewLock(data.lock_id, data.locked_until);
          else if (data.remove_lock && !this.editable) this.unlockButton(data.lock_id);
          else if (data.remove_lock && this.editable) this.lockEditor(data.lock_id);
        }
      }
    );
  }
  newLock(lockId, lockedUntil, buttonText = '') {
    let isFirst = Object.keys(this.locks).length === 0 && this.locks.constructor === Object;
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
    this.button.prop('disabled', true).addClass('content-locked');

    if (isFirst) {
      this.checkLockState();
      this.lockStateInterval = setInterval(this.checkLockState.bind(this), this.lockCheckInterval * 1000);
    }
  }
  renderCountDown(diffSeconds) {
    this.button.find('.pie-text').text(DurationHelpers.seconds_to_human_time(diffSeconds));

    for (let key in this.locks) {
      if (this.locks.hasOwnProperty(key)) {
        $(
          '#' +
            this.button.closest('.has-tip').data('toggle') +
            ' .content-locked-text#content-lock-' +
            key +
            ' .locked-until'
        ).text(Math.max(0, Math.round(parseFloat((this.locks[key] - Date.now()) / (1000 * 60)))) + 'min');
      }
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
    let diffSeconds = this.checkActiveLocks();
    let diffMinutes = parseInt(diffSeconds / 60);

    if (diffSeconds > 0) this.renderCountDown(diffSeconds);

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
  checkActiveLocks() {
    let max = 0;
    for (let key in this.locks) {
      if (!this.locks.hasOwnProperty(key)) continue;

      let rest = Math.max(0, parseInt((this.locks[key] - Date.now()) / 1000)) - (this.editable ? this.editOffset : 0);
      if (this.editable && rest <= 0) this.lockEditor(key);
      else if (rest <= 0) this.unlockButton(key);

      if (rest > max) max = rest;
    }
    return max;
  }
  triggerRenewLock() {
    this.removeConfirmationModal(null);
    $.ajax({
      url: this.lockPath,
      data: {
        lock_ids: Object.keys(this.locks)
      },
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
    delete this.locks[lockId];

    if (Object.keys(this.locks).length === 0 && this.locks.constructor === Object) {
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
    delete this.locks[lockId];
    $('#' + this.button.closest('.has-tip').data('toggle') + ' .content-locked-text#content-lock-' + lockId).remove();

    if (Object.keys(this.locks).length === 0 && this.locks.constructor === Object) {
      clearInterval(this.lockStateInterval);
      this.button.prop('disabled', false).removeClass('content-locked');
    }
  }
}

module.exports = ContentLock;

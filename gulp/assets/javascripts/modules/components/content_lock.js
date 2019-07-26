// Content Lock
let ConfirmationModal = require('./../components/confirmation_modal');
let ActionCable = require('actioncable');
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
    this.actionCable;
    this.lockContentChannel;
    this.confirmationModal = null;
    this.csrfToken = document.querySelector('meta[name=csrf-token]').getAttribute('content');
    this.csrfParam = document.querySelector('meta[name=csrf-param]').getAttribute('content');
    this.removableLockIds = [];

    this.setup();
  }
  setup() {
    console.log('setup');
    this.initActionCable();
    this.calculateLockedUntil(this.button.data('locks'));

    this.button.on('click', '.pie-text', event => {
      event.preventDefault();
      event.stopImmediatePropagation();
    });

    this.button.closest('.edit-header').on('mouseenter', event => {
      this.button.find('.pie-text').removeClass('show');
    });

    console.log(this.locks);
    console.log(Object.keys(this.locks).length !== 0 && this.locks.constructor === Object);

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
      console.log(data);
      if (data !== undefined && data.locks !== undefined) {
        this.updateLocks(data.locks, data.texts);
      } else if (data !== undefined) {
        for (let key in this.locks) {
          if (this.locks.hasOwnProperty(key)) this.unlockButton(key);
        }
      }
    });
  }
  updateLocks(newLocks = {}, texts = {}) {
    console.log('new locks fail');
    console.log(newLocks);
    this.locks = {};
    // this.calculateLockedUntil(newLocks);
    console.log(this.locks);

    if (Object.keys(newLocks).length !== 0 && newLocks.constructor === Object) {
      for (let key in newLocks) {
        console.log('new lock imported');
        console.log(key, newLocks[key]);
        if (newLocks.hasOwnProperty(key)) this.newLock(key, newLocks[key], texts[key]);
      }
    }
  }
  setRemoveableLocks() {
    this.removableLockIds = Object.keys(this.locks);
  }
  leavePage(event) {
    console.log('leave Page');

    this.lockContentChannel.unsubscribe();
    let data = new FormData();
    data.append(this.csrfParam, this.csrfToken);
    this.removableLockIds.forEach(lock_id => {
      data.append('lock_ids[]', lock_id);
    });

    navigator.sendBeacon(this.lockPath, data);
  }
  calculateLockedUntil(lockedUntil = {}) {
    console.log(lockedUntil);

    for (let key in lockedUntil) {
      if (lockedUntil.hasOwnProperty(key)) lockedUntil[key] = new Date((parseInt(lockedUntil[key]) - 5) * 1000);
    }

    Object.assign(this.locks, lockedUntil);
  }
  initActionCable() {
    console.log('init ActionCable');
    this.actionCable = ActionCable.createConsumer();
    this.lockContentChannel = this.actionCable.subscriptions.create(
      {
        channel: 'DataCycleCore::ContentLockChannel',
        content_id: this.uuid
      },
      {
        received: data => {
          console.log(data);
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
    console.log('new Lock');
    console.log(lockId, lockedUntil, buttonText);
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
    console.log('render Countdown');
    this.button.find('.pie-text').text(DurationHelpers.seconds_to_human_time(diffSeconds));

    for (let key in this.locks) {
      if (this.locks.hasOwnProperty(key)) {
        $(
          '#' +
            this.button.closest('.has-tip').data('toggle') +
            ' .content-locked-text#content-lock-' +
            key +
            ' .locked-until'
        ).text(Math.max(0, parseInt((this.locks[key] - Date.now()) / (1000 * 60))) + 'min');
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
    console.log('check lock state');
    let diffSeconds = Math.max(0, parseInt((Math.max.apply(null, Object.values(this.locks)) - Date.now()) / 1000));
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
      data: {
        lock_ids: Object.keys(this.locks)
      },
      type: 'PATCH'
    }).fail(() => {
      console.log('error renewing the lock');
    });
  }
  renewLock(lockId, lockedUntil) {
    console.log('renew lock');
    this.calculateLockedUntil({ [lockId]: lockedUntil });
    this.renewNotified = false;
    this.button.find('.pie-text').removeClass('show');
  }
  lockEditor(lockId) {
    console.log('lock Editor');
    console.log(this.locks);
    console.log(Object.keys(this.locks).length === 0 && this.locks.constructor === Object);

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
    console.log('remove Confirmation Modal');
    this.confirmationModal = null;
  }
  unlockButton(lockId) {
    console.log('unlock Button');
    console.log(this.locks);
    console.log(Object.keys(this.locks).length === 0 && this.locks.constructor === Object);

    delete this.locks[lockId];
    $('#' + this.button.closest('.has-tip').data('toggle') + ' .content-locked-text#content-lock-' + lockId).remove();

    if (Object.keys(this.locks).length === 0 && this.locks.constructor === Object) {
      clearInterval(this.lockStateInterval);
      this.button.prop('disabled', false).removeClass('content-locked');
    }
  }
}

module.exports = ContentLock;

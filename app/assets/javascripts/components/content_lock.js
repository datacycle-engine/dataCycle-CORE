import ConfirmationModal from './../components/confirmation_modal';
import DurationHelpers from './../helpers/duration_helpers';

class ContentLock {
  constructor(button) {
    this.button = $(button);
    this.editable = this.button.hasClass('editable-lock');
    this.buttonTooltip = this.button.closest('[data-dc-tooltip]').get(0);
    this.locks = {};
    this.lockLength = parseInt(this.button.data('lock-length'));
    this.lockRenewBefore = parseInt(this.button.data('lock-renew-before'));
    this.buttonDataDisableWith = this.button.data('disable-with');
    this.lockCheckInterval = 1;
    this.lockStateInterval;
    this.renewNotified = false;
    this.lockPath = this.button.data('lock-path');
    this.uuid = this.button.data('lock-content-id');
    this.token = this.button.data('lock-token');
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

    if (this.editable) {
      this.button.closest('.edit-header').on('mouseenter', _event => {
        this.button.removeClass('show-pie-text');
      });
    } else {
      this.button.closest('span').on('mouseleave', _event => {
        this.button.removeClass('show-pie-text');
      });
    }

    if (Object.keys(this.locks).length !== 0 && this.locks.constructor === Object) {
      this.checkLockState();
      this.lockStateInterval = setInterval(this.checkLockState.bind(this), this.lockCheckInterval * 1000);
    }

    if (this.editable) {
      $(window).on('unload', this.leavePage.bind(this));
    }
    if (!this.editable) this.checkInitialLockState();
  }
  checkInitialLockState() {
    const promise = DataCycle.httpRequest({
      url: this.checkLockPath,
      dataType: 'json'
    });

    promise.then(data => {
      if (data !== undefined) this.updateLocks(data.locks, data.texts);
    });

    return promise;
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
  leavePage(_event) {
    this.lockContentChannel.unsubscribe();
    let data = new FormData();
    data.append('token', this.token);
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
          else if (data.locked_until !== undefined) this.renewLock(data.lock_id, data.locked_until, data.token);
          else if (data.remove_lock && !this.editable) this.unlockButton(data.lock_id);
          else if (data.remove_lock && this.editable) this.lockEditor(data.lock_id);
        }
      }
    );
  }
  newLock(lockId, lockedUntil, buttonText = '') {
    let isFirst = Object.keys(this.locks).length === 0 && this.locks.constructor === Object;
    this.calculateLockedUntil({ [lockId]: lockedUntil });

    if (this.buttonTooltip) {
      const $tooltipHtml = $(`<div>${this.buttonTooltip.dataset.dcTooltip}</div>`);

      if (
        $tooltipHtml.find('.content-locked-text').length &&
        !$tooltipHtml.find(`.content-locked-text#content-lock-${lockId}`).length
      ) {
        $tooltipHtml.find('.content-locked-text').first().first().before(buttonText);
      } else if (!$tooltipHtml.find('.content-locked-text').length) {
        $tooltipHtml.append(buttonText);
      }

      if (Object.keys(this.locks).length >= 50) {
        $tooltipHtml.find('.content-locked-text').hide();
        $tooltipHtml
          .find('.content-locked-text#content-lock-multiple .lock-count')
          .html(Object.keys(this.locks).length);
        $tooltipHtml.find('.content-locked-text#content-lock-multiple').show();
      }

      this.buttonTooltip.dataset.dcTooltip = $tooltipHtml.html();
    }

    this.button.prop('disabled', true).addClass('content-locked show-pie-text');
    $('.delete-content-locks').addClass('show');

    if (isFirst) {
      this.checkLockState();
      this.lockStateInterval = setInterval(this.checkLockState.bind(this), this.lockCheckInterval * 1000);
    }
  }
  renderCountDown(diffSeconds) {
    this.button.find('.pie-text').text(DurationHelpers.seconds_to_human_time(diffSeconds));

    for (let key in this.locks) {
      if (this.locks.hasOwnProperty(key) && this.buttonTooltip) {
        const $tooltipHtml = $(`<div>${this.buttonTooltip.dataset.dcTooltip}</div>`);

        $tooltipHtml
          .find(`.content-locked-text#content-lock-${key}  .locked-until`)
          .text(Math.max(0, Math.round(parseFloat((this.locks[key] - Date.now()) / (1000 * 60)))) + 'min');

        this.buttonTooltip.dataset.dcTooltip = $tooltipHtml.html();
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
  async checkLockState() {
    let diffSeconds = this.checkActiveLocks();
    let diffMinutes = parseInt(diffSeconds / 60);

    if (diffSeconds > 0) this.renderCountDown(diffSeconds);

    if (!this.renewNotified && this.editable && diffSeconds <= this.lockRenewBefore) {
      this.button.addClass('show-pie-text');
      this.renewNotified = true;
      this.confirmationModal = new ConfirmationModal({
        text: await I18n.translate('frontend.content_lock.renew_lock', {
          min: diffMinutes,
          renew: this.lockLength / 60
        }),
        confirmationText: await I18n.translate('common.yes'),
        cancelText: await I18n.translate('common.no'),
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
    DataCycle.httpRequest({
      url: this.lockPath,
      data: {
        token: this.token
      },
      type: 'PATCH'
    }).catch(() => {
      console.error('CONTENT_LOCK_ERROR: error renewing the lock');
    });
  }
  renewLock(lockId, lockedUntil, token) {
    this.calculateLockedUntil({ [lockId]: lockedUntil });
    this.token = token;
    this.renewNotified = false;
    this.button.removeClass('show-pie-text');
  }
  async lockEditor(lockId) {
    delete this.locks[lockId];

    if (Object.keys(this.locks).length === 0 && this.locks.constructor === Object) {
      clearInterval(this.lockStateInterval);

      this.button.find('.pie-timer, .pie-text').addClass('alert');
      this.button
        .addClass('show-pie-text')
        .find('.pie-text')
        .text(await I18n.translate('frontend.content_lock.released'));

      if (this.confirmationModal !== null) this.confirmationModal.overlay.foundation('close');
      this.button.removeAttr('data-disable-with').removeData('disable-with').prop('disabled', true);
      this.button.closest('.edit-header').siblings('form').trigger('dc:form:disable');
    }
  }
  removeConfirmationModal(_) {
    this.confirmationModal = null;
  }
  unlockButton(lockId) {
    delete this.locks[lockId];

    if (this.buttonTooltip) {
      const $tooltipHtml = $(`<div>${this.buttonTooltip.dataset.dcTooltip}</div>`);
      $tooltipHtml.find(`.content-locked-text#content-lock-${lockId}`).remove();

      if (Object.keys(this.locks).length < 50) {
        $tooltipHtml.find('.content-locked-text').show();
        $tooltipHtml.find('.content-locked-text#content-lock-multiple').hide();
      }

      this.buttonTooltip.dataset.dcTooltip = $tooltipHtml.html();
    }

    if (Object.keys(this.locks).length === 0 && this.locks.constructor === Object) {
      clearInterval(this.lockStateInterval);
      this.button.prop('disabled', false).removeClass('content-locked show-pie-text');
      $('.delete-content-locks').removeClass('show');
    }
  }
}

export default ContentLock;

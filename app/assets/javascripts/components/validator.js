import ConfirmationModal from './confirmation_modal';
import QuillHelpers from './../helpers/quill_helpers';
import isEqual from 'lodash/isEqual';
import uniqWith from 'lodash/uniqWith';
import unionWith from 'lodash/unionWith';
import sortBy from 'lodash/sortBy';
import isEmpty from 'lodash/isEmpty';
import collectionReject from 'lodash/reject';

class Validator {
  constructor(formElement) {
    this.$form = $(formElement);
    this.$editHeader = this.$form.siblings('.edit-header').add(this.$form.find('.edit-header')).first();
    this.$submitButton = this.$editHeader.find('.submit-edit-form').first();
    this.$saveButton = this.$editHeader.find('.save-content-button').first();
    this.$languageMenu = this.$editHeader.find('#locales-menu').first();
    this.$agbsCheck = this.$editHeader.find('.form-element.agbs').first();
    this.$contentUploader = this.$form.data('content-uploader');
    this.bulkEdit = this.$form.hasClass('bulk-edit-form');
    this.initialFormData = [];
    this.submitFormData = [];
    this.requests = [];
    this.queryCount = 0;
    this.valid = true;
    this.eventHandlers = {
      beforeunload: this.pageLeaveHandler.bind(this)
    };
    this.changeObserver = new MutationObserver(this._checkForChangedFormData.bind(this));
    this.changeObserverConfig = {
      subtree: true,
      attributes: true,
      attributeFilter: ['class'],
      characterData: false,
      childList: false,
      attributeOldValue: true,
      characterDataOldValue: false
    };

    this.addEventHandlers();
  }
  addEventHandlers() {
    this.$form.on('change dc:form:validatefield', '.validation-container', this.validateSingle.bind(this));
    this.$form.on('dc:form:validate', '*', this.validateForm.bind(this));
    this.$form.on('remove-submit-button-errors', '.validation-container', event =>
      this.removeSubmitButtonErrors($(event.currentTarget))
    );
    this.$submitButton.on('click', this.clickSubmitButton.bind(this));
    this.$saveButton.on('click', this.clickSaveButton.bind(this));
    this.$form.on('submit dc:form:validateForm', this.validateForm.bind(this));
    if (this.$form.hasClass('edit-content-form')) {
      this.pageLeaveWarning();
    }
    this.$form.on('click', '.close-error', this.closeError.bind(this));
    this.$form.on('click', '.close-warning', this.closeWarning.bind(this));
    this.$agbsCheck.on('click', '.close-error', this.closeError.bind(this));
    this.$agbsCheck.on('change', this.validateSingle.bind(this));
    this.$form.on('dc:form:disable', this.disable.bind(this));
    this.$form.on('dc:form:enable', this.enable.bind(this));

    this.changeObserver.observe(this.$form[0], this.changeObserverConfig);
  }
  clickSubmitButton(event) {
    event.preventDefault();
    event.stopImmediatePropagation();

    this.$form.trigger('submit', {
      saveAndClose: true,
      mergeConfirm: this.$submitButton.hasClass('merge-with-duplicate')
    });
  }
  clickSaveButton(event) {
    event.preventDefault();
    event.stopImmediatePropagation();

    this.$form.trigger('submit');
  }
  closeError(event) {
    event.preventDefault();

    $(event.target).closest('.single_error').remove();
  }
  closeWarning(event) {
    event.preventDefault();

    $(event.target).closest('.single_warning').remove();
  }
  validateSingle(event, data) {
    event.stopPropagation();

    if (data && data.type === 'reset') return;

    this.requests = [this.validateItem(event.currentTarget)];
    this.resolveRequests(false, data);
  }
  sortedFormData(formData) {
    return collectionReject(
      sortBy(uniqWith(formData || this.$form.serializeArray(), isEqual), ['name', 'value']),
      v => v.name && ['authenticity_token', 'locale'].includes(v.name)
    );
  }
  updateSubmitFormData() {
    QuillHelpers.updateEditors(this.$form);
    this.submitFormData = this.sortedFormData();
  }
  formDataChanged() {
    return this.initialFormData.length > 0 && !isEqual(this.initialFormData, this.submitFormData);
  }
  pageLeaveHandler(event) {
    this.updateSubmitFormData();

    if (this.formDataChanged()) {
      event.preventDefault();
      return (event.returnValue = '');
    }
  }
  pageLeaveWarning() {
    QuillHelpers.updateEditors(this.$form);
    this.initialFormData = this.sortedFormData();

    $(window).on('beforeunload', this.eventHandlers.beforeunload);

    if (this.$languageMenu.length) {
      this.$languageMenu.on('click', '.list-items > li > a', async event => {
        this.updateSubmitFormData();

        if (this.formDataChanged()) {
          event.preventDefault();
          new ConfirmationModal({
            text: await I18n.translate('frontend.validate.save_and_change_language'),
            confirmationClass: 'success',
            cancelable: true,
            confirmationCallback: () => {
              this.$form.append(
                '<input type="hidden" name="new_locale" value="' + $(event.target).data('locale') + '">'
              );
              this.$form.trigger('submit');
            }
          });
        }
      });
    }
  }
  _checkForChangedFormData(mutations) {
    for (const mutation of mutations) {
      if (mutation.type !== 'attributes') continue;

      if (mutation.target.classList.contains('remote-rendered') && mutation.oldValue.includes('remote-rendering'))
        this.updateInitialFormData(mutation.target);
    }
  }
  updateInitialFormData(target) {
    this.initialFormData = collectionReject(
      sortBy(unionWith(this.initialFormData, $(target).find(':input').serializeArray(), isEqual), ['name', 'value']),
      {
        name: 'authenticity_token'
      }
    );
  }
  async validateAgbs(validationContainer) {
    let error = {
      valid: true,
      errors: {},
      warnings: {}
    };
    let agbs = $(validationContainer).find(':checkbox[name="accept_agbs"]');
    if (agbs.length && !agbs.prop('checked')) {
      const errorMessage = await I18n.translate('frontend.validate.agbs');
      $(validationContainer)
        .append(await this.renderErrorMessage({ errors: { agbs: [errorMessage] } }, validationContainer))
        .addClass('has-error');
      error.valid = false;
      error.errors.agbs = [errorMessage];
    } else {
      this.removeSubmitButtonErrors(validationContainer);
    }
    return Promise.resolve(error);
  }
  disable() {
    DataCycle.disableElement(this.$submitButton);
    DataCycle.disableElement(this.$saveButton);
    DataCycle.disableElement(this.$form);
  }
  enable() {
    if (this.queryCount == 0 && !this.$form.hasClass('disabled')) {
      DataCycle.enableElement(this.$submitButton);
      DataCycle.enableElement(this.$saveButton);
      DataCycle.enableElement(this.$form);
      this.$form.find('input#duplicate_id').remove();
    }
  }
  tooltipError(key, type = 'error') {
    return $(`<span class="tooltip-${type}" data-attribute-key="${key}"></span>`);
  }
  singleError(key, type = 'error') {
    return $(
      `<span class="single_${type}" data-attribute-key="${key}"><i class="fa fa-times close-${type}" aria-hidden="true"></i></span></span>`
    );
  }
  async renderErrorMessage(data, validationContainer, type = 'error', itemClass = 'alert') {
    const $itemLabel = $(validationContainer).find('label').first();
    const labelFor = $itemLabel.attr('for');
    const labelText = $itemLabel.text().replace(/\s+/g, ' ').trim();
    const completeKey = $(validationContainer).data('key');
    const $submitTooltip = $(`#${this.$submitButton.data('toggle')}`);
    const $tooltipError = this.tooltipError(completeKey, type);
    const $singleError = this.singleError(completeKey, type);

    for (let [key, message] of Object.entries(data[`${type}s`] || {})) {
      if (
        !(completeKey && completeKey.match(new RegExp(key, 'i'))) &&
        !(labelFor && labelFor.match(new RegExp(key, 'i')))
      )
        continue;

      if (Array.isArray(message)) message = message.join('<br>');

      $tooltipError.append(
        `<b>${labelText || (await I18n.translate(`frontend.validate.${type}`))}</b><br>${message}<br>`
      );
      $singleError.append(`<b>${labelText || (await I18n.translate(`frontend.validate.${type}`))}</b> ${message}<br>`);
    }

    if (!$singleError.text().length) return $();

    if (this.$form.hasClass('edit-content-form')) {
      this.$submitButton.addClass(itemClass);
      $submitTooltip.find(`.tooltip-${type}[data-attribute-key="${completeKey}"]`).remove();
      $submitTooltip.append($tooltipError);
    }

    return $singleError;
  }
  locale() {
    return this.$form.find(':input[name="locale"]').val() || this.$form.find(':input[name="thing[locale]"]').val();
  }
  removeSubmitButtonErrors(item, type = 'error', itemClass = 'alert') {
    const $submitTooltip = $(`#${this.$submitButton.data('toggle')}`);

    if (item) {
      const translationLocale = this.attributeLocale(item);
      $submitTooltip.find(`[data-attribute-key="${$(item).data('key')}"]`).remove();
      if (!$submitTooltip.find(`.tooltip-${type}`).length) this.$submitButton.removeClass(itemClass);

      if (
        translationLocale &&
        !$submitTooltip.find(`.tooltip-${type}[data-attribute-key*="[translations][${translationLocale}]"]`).length
      )
        this.$form.trigger('dc:form:removeValidationError', { locale: translationLocale, type: type });
    } else {
      this.$form.trigger('dc:form:removeValidationError', { type: type });
      this.$submitButton.removeClass(itemClass);
      $submitTooltip.find(`.tooltip-${type}`).remove();
    }
  }
  resetField(validationContainer) {
    $(validationContainer).children('.single_error').remove();
    $(validationContainer).removeClass('has-error');
    $(validationContainer).children('.single_warning').remove();
    $(validationContainer).removeClass('has-warning');

    this.removeSubmitButtonErrors(validationContainer, 'error', 'alert');
    this.removeSubmitButtonErrors(validationContainer, 'warning', 'warning');
  }
  attributeLocale(validationContainer) {
    const key = $(validationContainer).data('key');

    if (!key) return;

    return key.includes('[translations]') && key.match(/\[translations\]\[([\-a-zA-Z]+)\]/)[1];
  }
  formFieldChanged(newFieldData, translationLocale, submitFormaDataUpToDate) {
    if (!translationLocale || translationLocale == this.locale() || this.bulkEdit) return true;

    newFieldData = this.sortedFormData(newFieldData || []);
    const key = newFieldData[0] && newFieldData[0].name;
    let oldFieldData = [];
    if (key) oldFieldData = this.initialFormData.filter(v => v.name.includes(key));

    if (!submitFormaDataUpToDate) this.updateSubmitFormData();

    return (
      !isEqual(oldFieldData, newFieldData) ||
      this.submitFormData.filter(v => v.name.includes(`[${translationLocale}]`)).some(v => !isEmpty(v.value))
    );
  }
  validateItem(validationContainer, submitFormaDataUpToDate = false) {
    this.resetField(validationContainer);

    if ($(validationContainer).hasClass('agbs')) {
      return this.validateAgbs(validationContainer);
    }

    let formData = $(validationContainer).find(':input').serializeArray();
    if (formData.length == 0) return Promise.resolve({ valid: true });

    const translationLocale = this.attributeLocale(validationContainer);

    if (!this.formFieldChanged(formData, translationLocale, submitFormaDataUpToDate))
      return Promise.resolve({ valid: true });

    const uuid = this.$form.find(':input[name="uuid"]').val();
    const locale = translationLocale || this.locale();
    const table = this.$form.find(':input[name="table"]').val() || 'things';
    const url = `/${table}${uuid ? '/' + uuid : ''}/validate`;
    const template = this.$form.find(':input[name="template"]').val();
    if (template != undefined) {
      formData.push({
        name: 'template',
        value: template
      });
    }

    if (locale) {
      formData.push({
        name: 'locale',
        value: locale
      });
    }

    const promise = DataCycle.httpRequest({
      type: 'POST',
      url: url,
      data: $.param(formData),
      dataType: 'json'
    });

    promise.then(async data => {
      if (data != undefined) {
        if (!data.valid && data.errors && Object.keys(data.errors).length > 0) {
          this.$form.trigger('dc:form:validationError', { locale: translationLocale, type: 'error' });
          $(validationContainer)
            .append(await this.renderErrorMessage(data, validationContainer))
            .addClass('has-error');
        }
        if (data.warnings && Object.keys(data.warnings).length > 0) {
          this.$form.trigger('dc:form:validationError', { locale: translationLocale, type: 'warning' });
          $(validationContainer)
            .append(await this.renderErrorMessage(data, validationContainer, 'warning', 'warning'))
            .addClass('has-warning');
        }
      }
    });

    return promise;
  }
  validateForm(event, data) {
    if (event.detail && event.detail.dcFormSubmitted) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    this.updateSubmitFormData();
    this.removeSubmitButtonErrors();
    this.disable();
    this.requests = [];

    $(event.target)
      .find('.validation-container')
      .add(this.$agbsCheck)
      .each((_i, elem) => {
        this.requests.push(this.validateItem(elem, true));
      });

    this.resolveRequests($(event.target).is(this.$form), data);
  }
  async submitForm(
    confirmations = { finalize: true, confirm: true, warnings: undefined, mergeConfirm: false, saveAndClose: false }
  ) {
    if (confirmations.warnings !== undefined) {
      return new ConfirmationModal({
        text: await I18n.translate('frontend.validate.ignore_warnings', {
          data: confirmations.warnings
            .closest('.form-element')
            .map((_i, elem) => $(elem).data('label'))
            .get()
            .join(', ')
        }),
        confirmationClass: 'warning',
        cancelable: true,
        confirmationCallback: () => {
          confirmations.warnings = undefined;
          this.submitForm(confirmations);
        },
        cancelCallback: () => this.enable()
      });
    }

    if (confirmations.finalize && this.$form.find(':input[name="finalize"]:checked').length) {
      return new ConfirmationModal({
        text: await I18n.translate('frontend.validate.final_save'),
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: () => {
          confirmations.finalize = false;
          this.submitForm(confirmations);
        },
        cancelCallback: () => this.enable()
      });
    }

    if (confirmations.confirm && this.$submitButton.data('confirm') !== undefined) {
      return new ConfirmationModal({
        text: this.$submitButton.data('confirm'),
        confirmationClass: 'alert',
        cancelable: true,
        confirmationCallback: () => {
          confirmations.confirm = false;
          this.submitForm(confirmations);
        },
        cancelCallback: () => this.enable()
      });
    }

    this.triggerFormSubmit(confirmations);
  }
  triggerFormSubmit(confirmations = {}) {
    if (this.$form.closest('.reveal').hasClass('in-object-browser') || this.$contentUploader) {
      return this.$form.trigger('dc:form:submitWithoutRedirect', confirmations);
    } else {
      $(window).off('beforeunload', this.eventHandlers.beforeunload);
      if (confirmations && confirmations.saveAndClose)
        this.$form.append('<input type="hidden" name="save_and_close" value="1">');
      if (confirmations && confirmations.mergeConfirm)
        this.$form.append(
          '<input id="duplicate_id" type="hidden" name="duplicate_id" value="' + this.$form.data('duplicate-id') + '">'
        );

      if (this.$form.data('remote')) Rails.fire(this.$form[0], 'submit', { dcFormSubmitted: true });
      else this.$form[0].submit();
    }
  }
  resolveRequests(submit = false, eventData = {}) {
    if (eventData.hasOwnProperty('submit')) submit = eventData.submit;

    this.queryCount++;
    let requests = this.requests.slice();
    this.requests = [];

    Promise.all(requests).then(
      values => {
        this.queryCount--;
        this.valid = true;

        let error = this.$form.find('.single_error').first();
        values.filter(Boolean).forEach(validation => {
          if (!validation.valid) this.valid = false;
        });

        if (this.valid && submit) {
          this.queryCount = 0;
          let warnings = this.$form.find('.form-element .warning.counter');

          eventData = Object.assign({}, eventData || {}, {
            finalize: true,
            confirm: true
          });

          if (warnings.length) Object.assign(eventData, { warnings: warnings });

          this.submitForm(eventData);
        } else if (!this.valid && submit) {
          if (this.$form.hasClass('edit-content-form') && error !== undefined && error[0] !== undefined) {
            error[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
          }
        }
        if (!(this.valid && submit)) this.enable();
        if (this.valid && eventData !== undefined && eventData.successCallback !== undefined) {
          eventData.successCallback();
        }
        if (!this.valid && eventData !== undefined && eventData.errorCallback !== undefined) {
          eventData.errorCallback();
        }
        // scroll to step in multi-step form
        if (!this.valid && this.$form.hasClass('multi-step') && error.is(':hidden')) {
          this.$form.trigger('dc:multistep:goto', this.$form.find('fieldset').index(error.closest('fieldset')));
        }
      },
      async error => {
        this.queryCount--;

        let buttonText = `<span id="button_server_error" class="tooltip-error"><strong>${await I18n.translate(
          'frontend.validate.error'
        )}</strong><br>${error.statusText}<br></span>`;
        this.enable();
        this.$submitButton.addClass('alert');
        $('#' + this.$submitButton.data('toggle')).append(buttonText);
      }
    );
  }
}

export default Validator;

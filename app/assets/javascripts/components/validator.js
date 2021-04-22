import ConfirmationModal from './confirmation_modal';
import QuillHelpers from './../helpers/quill_helpers';

class Validator {
  constructor(formElement) {
    this.form = $(formElement);
    this.submitButton = this.form.siblings('.edit-header').find('.submit-edit-form').first();
    this.saveButton = this.form.siblings('.edit-header').find('.save-content-button').first();
    this.languageMenu = this.form.siblings('.edit-header').find('#locales-menu').first();
    this.agbsCheck = this.form.siblings('.edit-header').find('.form-element.agbs').first();
    this.contentUploader = this.form.data('content-uploader');
    this.initialFormData = [];
    this.submitFormData = [];
    this.requests = [];
    this.queryCount = 0;
    this.valid = true;
    this.addEventHandlers();
  }
  addEventHandlers() {
    this.form.on('change dc:form:validatefield', '.validation-container', this.validateSingle.bind(this));
    this.form.on('dc:form:validate', '*', this.validateForm.bind(this));
    this.form.on('remove-submit-button-errors', '.validation-container', event =>
      this.removeSubmitButtonErrors($(event.currentTarget))
    );
    this.submitButton.on('click', event => {
      event.preventDefault();
      event.stopImmediatePropagation();
      this.form.trigger('submit', {
        saveAndClose: true,
        mergeConfirm: this.submitButton.hasClass('merge-with-duplicate')
      });
    });
    this.saveButton.on('click', event => {
      event.preventDefault();
      event.stopImmediatePropagation();
      this.form.trigger('submit');
    });
    this.form.on('submit dc:form:validateForm', this.validateForm.bind(this));
    if (this.form.hasClass('edit-content-form')) {
      this.pageLeaveWarning();
    }
    this.form.on('click', '.close-error', this.closeError.bind(this));
    this.form.on('click', '.close-warning', this.closeWarning.bind(this));
    this.agbsCheck.on('click', '.close-error', this.closeError.bind(this));
    this.agbsCheck.on('change', this.validateSingle.bind(this));
    this.form.on('dc:form:disable', this.disable.bind(this));
    this.form.on('dc:form:enable', this.enable.bind(this));
    this.form.on('dc:html:initialized', '*', this.updateInitialFormData.bind(this));
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
    if (data && data.type === 'reset') return;
    this.requests = [this.validateItem(event.currentTarget)];
    this.resolveRequests(false, data);
  }
  pageLeaveWarning() {
    QuillHelpers.updateEditors(this.form);
    this.initialFormData = this.form.serializeArray().uniqFieldValues();
    $(window).on('beforeunload', event => {
      QuillHelpers.updateEditors(this.form);
      this.submitFormData = this.form.serializeArray().uniqFieldValues();

      if (this.initialFormData.length !== 0 && !this.initialFormData.equal_to(this.submitFormData))
        return 'Wollen Sie die Seite wirklich verlassen ohne zu speichern?';
    });
    if (this.languageMenu.length) {
      this.languageMenu.on('click', '.list-items > li > a', event => {
        QuillHelpers.updateEditors(this.form);
        this.submitFormData = this.form.serializeArray().uniqFieldValues();
        if (this.initialFormData.length !== 0 && !this.initialFormData.equal_to(this.submitFormData)) {
          event.preventDefault();
          new ConfirmationModal({
            text: 'Wollen Sie speichern und auf die neue Sprache wechseln?',
            confirmationClass: 'success',
            cancelable: true,
            confirmationCallback: () => {
              this.form.append(
                '<input type="hidden" name="new_locale" value="' + $(event.target).data('locale') + '">'
              );
              this.form.trigger('submit');
            }
          });
        }
      });
    }
  }
  updateInitialFormData(event, data = {}) {
    event.preventDefault();

    if (!data || !data.newContent)
      this.initialFormData = this.initialFormData.mergeUniqueFormValues(
        $(event.target).find(':input').serializeArray()
      );
  }
  validateAgbs(validationContainer) {
    let error = {
      error: {},
      warning: {}
    };
    let agbs = $(validationContainer).find(':checkbox[name="accept_agbs"]');
    if (agbs.length && !agbs.prop('checked')) {
      $(validationContainer)
        .append(this.renderErrorMessage({ error: { agbs: ['AGBs müssen akzeptiert werden!'] } }, validationContainer))
        .addClass('has-error');
      error.error = {
        agbs: ['AGBs müssen akzeptiert werden!']
      };
    } else {
      this.removeSubmitButtonErrors(validationContainer);
    }
    return error;
  }
  disable() {
    DataCycle.disableElement(this.submitButton);
    DataCycle.disableElement(this.saveButton);
    DataCycle.disableElement(this.form);
  }
  enable() {
    if (this.queryCount == 0 && !this.form.hasClass('disabled')) {
      DataCycle.enableElement(this.submitButton);
      DataCycle.enableElement(this.saveButton);
      DataCycle.enableElement(this.form);
      this.form.find('input#duplicate_id').remove();
    }
  }
  renderErrorMessage(data, validationContainer) {
    let out = '';
    let item_id = '';
    let item_label = $(validationContainer).find('label').first();
    let button_text = '';
    if (validationContainer != null && $(validationContainer).data('id') != undefined)
      item_id = $(validationContainer).data('id') + '_error';
    else if (validationContainer != null && $(item_label).attr('for') != undefined)
      item_id = $(item_label).attr('for') + '_error';
    if ($('#' + item_id).length != 0) return '';
    button_text = '<span id="button_' + item_id + '" class="tooltip-error">';
    out = "<span id='" + item_id + "' class='single_error'>";
    for (let key in data.error) {
      if (
        ($(validationContainer).data('id') != undefined &&
          $(validationContainer).data('id').search(new RegExp(key, 'i')) != -1) ||
        ($(validationContainer).data('id') == undefined &&
          $(item_label).attr('for') != undefined &&
          $(item_label).attr('for').search(new RegExp(key, 'i')) != -1)
      ) {
        button_text += '<strong>' + ($(item_label).text() || 'Fehler') + ':</strong><br>' + data.error[key] + '<br>';
        out += '<strong>' + ($(item_label).text() || 'Fehler') + ':</strong> ' + data.error[key] + '</br>';
      }
    }
    out += '<i class="fa fa-times close-error" aria-hidden="true"></i></span>';
    if ($(out).text().length == 0) return '';
    if (this.form.hasClass('edit-content-form')) {
      this.submitButton.addClass('alert');
      $('#' + this.submitButton.data('toggle') + ' #button_' + item_id).remove();
      $('#' + this.submitButton.data('toggle')).append(button_text + '</span>');
    }
    return out;
  }
  renderWarningMessage(data, validationContainer) {
    let out = '';
    let item_id = '';
    let item_label = $(validationContainer).find('label').first();
    let button_text = '';
    if (validationContainer != null && $(validationContainer).data('id') != undefined)
      item_id = $(validationContainer).data('id') + '_warning';
    else if (validationContainer != null && $(item_label).attr('for') != undefined)
      item_id = $(item_label).attr('for') + '_warning';
    if ($('#' + item_id).length != 0) return '';
    button_text = '<span id="button_' + item_id + '" class="tooltip-warning">';
    out = "<span id='" + item_id + "' class='single_warning'>";
    for (let key in data.warning) {
      if (
        ($(validationContainer).data('id') != undefined &&
          $(validationContainer).data('id').search(new RegExp(key, 'i')) != -1) ||
        ($(validationContainer).data('id') == undefined &&
          $(item_label).attr('for') != undefined &&
          $(item_label).attr('for').search(new RegExp(key, 'i')) != -1)
      ) {
        button_text += '<strong>' + ($(item_label).text() || 'Warnung') + ':</strong><br>' + data.warning[key] + '<br>';
        out += '<strong>' + ($(item_label).text() || 'Warnung') + ':</strong> ' + data.warning[key] + '</br>';
      }
    }
    out += '<i class="fa fa-times close-warning" aria-hidden="true"></i></span>';
    if ($(out).text().length == 0) return '';
    if (this.form.hasClass('edit-content-form')) {
      this.submitButton.addClass('warning');
      $('#' + this.submitButton.data('toggle') + ' #button_' + item_id).remove();
      $('#' + this.submitButton.data('toggle')).append(button_text + '</span>');
    }
    return out;
  }
  removeSubmitButtonErrors(item) {
    var item_id = '';
    let item_label = $(item).find('label').first();
    if (item != null && $(item).data('id') != undefined) item_id = $(item).data('id') + '_error';
    else if (item != null && $(item_label).attr('for') != undefined) item_id = $(item_label).attr('for') + '_error';
    if (item == null) {
      this.submitButton.removeClass('alert');
      $('#' + this.submitButton.data('toggle') + ' .tooltip-error').remove();
    } else {
      $('#' + this.submitButton.data('toggle') + ' #button_' + item_id).remove();
      if ($('#' + this.submitButton.data('toggle') + ' .tooltip-error').length == 0) {
        this.submitButton.removeClass('alert');
      }
    }
  }
  removeSubmitButtonWarnings(item) {
    var item_id = '';
    let item_label = $(item).find('label').first();
    if (item != null && $(item).data('id') != undefined) item_id = $(item).data('id') + '_warning';
    else if (item != null && $(item_label).attr('for') != undefined) item_id = $(item_label).attr('for') + '_warning';
    if (item == null) {
      this.submitButton.removeClass('warning');
      $('#' + this.submitButton.data('toggle') + ' .tooltip-warning').remove();
    } else {
      $('#' + this.submitButton.data('toggle') + ' #button_' + item_id).remove();
      if ($('#' + this.submitButton.data('toggle') + ' .tooltip-warning').length == 0) {
        this.submitButton.removeClass('warning');
      }
    }
  }
  resetField(validationContainer) {
    $(validationContainer).children('.single_error').remove();
    $(validationContainer).removeClass('has-error');
    $(validationContainer).children('.single_warning').remove();
    $(validationContainer).removeClass('has-warning');
  }
  findItemsForField(validationContainer) {
    let items = [];
    if ($(validationContainer).data('key') != undefined) {
      items = $(validationContainer).find('[name^="' + $(validationContainer).data('key') + '"]');
    } else if ($(validationContainer).children('label').length) {
      items = $(validationContainer).find('#' + $(validationContainer).children('label').first().prop('for'));
    }
    return items;
  }
  validateItem(validationContainer) {
    this.resetField(validationContainer);
    if ($(validationContainer).hasClass('agbs')) {
      return new Promise((resolve, reject) => {
        resolve(this.validateAgbs(validationContainer));
      });
    }

    let items = this.findItemsForField(validationContainer);
    if (!items.length) return;
    let form_data = items.serializeArray();
    if (form_data.length == 0) {
      form_data.push({
        name: items.prop('name')
      });
    }
    let uuid = this.form.find(':input[name="uuid"]').val();
    let locale = this.form.find(':input[name="locale"]').val() || this.form.find(':input[name="thing[locale]"]').val();
    let table = this.form.find(':input[name="table"]').val() || 'things';
    let url = DataCycle.enginePath + '/' + table + (uuid != undefined ? '/' + uuid : '') + '/validate';
    let template = this.form.find(':input[name="template"]').val();
    if (template != undefined) {
      form_data.push({
        name: 'template',
        value: template
      });
    }

    if (locale != undefined) {
      form_data.push({
        name: 'locale',
        value: locale
      });
    }

    return DataCycle.httpRequest({
      type: 'POST',
      url: url,
      data: $.param(form_data),
      dataType: 'json'
    }).done(data => {
      if (data != undefined) {
        if (
          data.error &&
          Object.keys(data.error).length > 0 &&
          items
            .filter('[id]')
            .first()
            .prop('id')
            .search(new RegExp(Object.keys(data.error).join('|'), 'i')) != -1
        ) {
          $(validationContainer).append(this.renderErrorMessage(data, validationContainer)).addClass('has-error');
        } else {
          this.removeSubmitButtonErrors(validationContainer);
        }

        if (
          data.warning &&
          Object.keys(data.warning).length > 0 &&
          items
            .filter('[id]')
            .first()
            .prop('id')
            .search(new RegExp(Object.keys(data.warning).join('|'), 'i')) != -1
        ) {
          $(validationContainer).append(this.renderWarningMessage(data, validationContainer)).addClass('has-warning');
        } else {
          this.removeSubmitButtonWarnings(validationContainer);
        }
      } else {
        this.removeSubmitButtonErrors(validationContainer);
        this.removeSubmitButtonWarnings(validationContainer);
      }
    });
  }
  validateForm(event, data) {
    event.preventDefault();
    event.stopImmediatePropagation();
    QuillHelpers.updateEditors(event.target);
    this.removeSubmitButtonErrors();
    this.disable();
    this.requests = [];

    $(event.target)
      .find('.validation-container:visible')
      .add(this.agbsCheck)
      .each((i, elem) => {
        this.requests.push(this.validateItem(elem));
      });

    this.resolveRequests($(event.target).is(this.form), data);
  }
  submitForm(
    confirmations = { finalize: true, confirm: true, warnings: undefined, mergeConfirm: false, saveAndClose: false }
  ) {
    if (confirmations.warnings !== undefined) {
      return new ConfirmationModal({
        text:
          'Es sind Warnungen vorhanden (' +
          confirmations.warnings
            .closest('.form-element')
            .map((i, elem) => $(elem).data('label'))
            .get()
            .join(', ') +
          ').<br>Soll der Inhalt trotzdem gespeichert werden?',
        confirmationClass: 'warning',
        cancelable: true,
        confirmationCallback: () => {
          confirmations.warnings = undefined;
          this.submitForm(confirmations);
        },
        cancelCallback: () => this.enable()
      });
    }

    if (confirmations.finalize && this.form.find(':input[name="finalize"]:checked').length) {
      return new ConfirmationModal({
        text: 'Der Inhalt wird final abgeschickt und <br>kann danach nicht mehr bearbeitet werden.',
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: () => {
          confirmations.finalize = false;
          this.submitForm(confirmations);
        },
        cancelCallback: () => this.enable()
      });
    }

    if (confirmations.confirm && this.submitButton.data('confirm') !== undefined) {
      return new ConfirmationModal({
        text: this.submitButton.data('confirm'),
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
    if (this.form.closest('.reveal').hasClass('in-object-browser') || this.contentUploader) {
      return this.form.trigger('dc:form:submitWithoutRedirect', confirmations);
    } else {
      $(window).off('beforeunload');
      if (confirmations && confirmations.saveAndClose)
        this.form.append('<input type="hidden" name="save_and_close" value="1">');
      if (confirmations && confirmations.mergeConfirm)
        this.form.append(
          '<input id="duplicate_id" type="hidden" name="duplicate_id" value="' + this.form.data('duplicate-id') + '">'
        );
      this.form.trigger('submit.rails');
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
        let error = this.form.find('.single_error').first();
        values.filter(Boolean).forEach(validation => {
          if (Object.keys(validation.error).length) this.valid = false;
        });
        if (this.valid && submit) {
          this.queryCount = 0;
          let warnings = this.form.find('.form-element .warning.counter');

          eventData = Object.assign({}, eventData || {}, {
            finalize: true,
            confirm: true
          });

          if (warnings.length) Object.assign(eventData, { warnings: warnings });

          this.submitForm(eventData);
        } else if (!this.valid && submit) {
          if (this.form.hasClass('edit-content-form') && error !== undefined && error[0] !== undefined) {
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
        if (!this.valid && this.form.hasClass('multi-step') && error.is(':hidden')) {
          this.form.trigger('dc:multistep:goto', this.form.find('fieldset').index(error.closest('fieldset')));
        }
      },
      error => {
        this.queryCount--;
        let buttonText =
          '<span id="button_server_error" class="tooltip-error">' +
          '<strong>Fehler:</strong><br>' +
          error.statusText +
          '<br></span>';
        this.enable();
        this.submitButton.addClass('alert');
        $('#' + this.submitButton.data('toggle')).append(buttonText);
      }
    );
  }
}

export default Validator;

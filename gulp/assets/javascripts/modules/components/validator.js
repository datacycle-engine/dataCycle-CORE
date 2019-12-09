// Form Validator
let ConfirmationModal = require('./../components/confirmation_modal');
let QuillHelpers = require('./../helpers/quill_helpers');

class Validator {
  constructor(formElement) {
    this.form = $(formElement);
    this.submitButton = this.form
      .siblings('.edit-header')
      .find('.submit-edit-form')
      .first();
    this.saveButton = this.form
      .siblings('.edit-header')
      .find('.save-content-button')
      .first();
    this.mergeDuplicateButton = this.form
      .siblings('.edit-header')
      .find('.merge-with-duplicate')
      .first();
    this.languageMenu = this.form
      .siblings('.edit-header')
      .find('#locales-menu')
      .first();
    this.agbsCheck = this.form
      .siblings('.edit-header')
      .find('.form-element.agbs')
      .first();
    this.initialFormData = [];
    this.submitFormData = [];
    this.requests = [];
    this.queryCount = 0;
    this.valid = true;
    this.uuid = this.form.find(':hidden#uuid').val();
    this.bulkUpdateChannel;
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
      this.form.trigger('submit', { saveAndClose: true });
    });
    this.saveButton.on('click', event => {
      event.preventDefault();
      event.stopImmediatePropagation();
      this.form.trigger('submit');
    });
    this.mergeDuplicateButton.on('click', event => {
      event.preventDefault();
      event.stopImmediatePropagation();
      this.form.append(
        '<input id="duplicate_id" type="hidden" name="duplicate_id" value="' + this.form.data('duplicate-id') + '">'
      );
      this.form.trigger('submit', { mergeConfirm: true });
    });
    this.form.on('submit', this.validateForm.bind(this));
    if (this.form.hasClass('edit-content-form')) {
      this.pageLeaveWarning();
    }
    this.form.on('click', '.close-error', this.closeError.bind(this));
    this.agbsCheck.on('click', '.close-error', this.closeError.bind(this));
    this.agbsCheck.on('change', this.validateSingle.bind(this));
    this.form.on('dc:form:disable', this.disable.bind(this));
    this.form.on('dc:form:enable', this.enable.bind(this));

    if (this.form.hasClass('bulk-edit-form') && window.actionCable !== undefined) {
      this.initActionCable();
    }
  }
  initActionCable() {
    this.bulkUpdateChannel = window.actionCable.subscriptions.create(
      {
        channel: 'DataCycleCore::WatchListBulkUpdateChannel',
        watch_list_id: this.uuid
      },
      {
        received: data => {
          if (!this.submitButton.prop('disabled')) this.disable();
          if (data.progress !== undefined) {
            let progress = Math.round((data.progress * 100) / data.items);
            this.submitButton.find('.progress-value').text(progress + '%');
            this.submitButton.find('.progress-bar > .progress-filled').css('width', 'calc(' + progress + '% - 1rem)');
          }
          if (data.redirect_path !== undefined) {
            window.location.href = data.redirect_path;
          }
        }
      }
    );
  }
  closeError(event) {
    event.preventDefault();
    $(event.target)
      .closest('.single_error')
      .remove();
  }
  validateSingle(event, data) {
    this.requests = [this.validateItem(event.currentTarget)];
    this.resolveRequests(false, data);
  }
  pageLeaveWarning() {
    QuillHelpers.update_editors(this.form);
    this.initialFormData = this.form.serializeArray();
    $(window).on('beforeunload', event => {
      QuillHelpers.update_editors(this.form);
      this.submitFormData = this.form.serializeArray();
      if (this.initialFormData.length !== 0 && !this.initialFormData.equal_to(this.submitFormData))
        return 'Wollen Sie die Seite wirklich verlassen ohne zu speichern?';
    });
    if (this.languageMenu.length) {
      this.languageMenu.on('click', '.list-items > li > a', event => {
        QuillHelpers.update_editors(this.form);
        this.submitFormData = this.form.serializeArray();
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
    $.rails.disableFormElement(this.submitButton);
    $.rails.disableFormElement(this.saveButton);
    $.rails.disableFormElement(this.mergeDuplicateButton);
    $.rails.disableFormElements(this.form);
  }
  enable() {
    if (this.queryCount == 0 && !this.form.hasClass('disabled')) {
      $.rails.enableFormElement(this.submitButton);
      $.rails.enableFormElement(this.saveButton);
      $.rails.enableFormElement(this.mergeDuplicateButton);
      $.rails.enableFormElements(this.form);
      this.form.find('input#duplicate_id').remove();
    }
  }
  renderErrorMessage(data, validationContainer) {
    let out = '';
    let item_id = '';
    let item_label = $(validationContainer)
      .find('label')
      .first();
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
          $(validationContainer)
            .data('id')
            .search(new RegExp(key, 'i')) != -1) ||
        ($(validationContainer).data('id') == undefined &&
          $(item_label).attr('for') != undefined &&
          $(item_label)
            .attr('for')
            .search(new RegExp(key, 'i')) != -1)
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
  removeSubmitButtonErrors(item) {
    var item_id = '';
    let item_label = $(item)
      .find('label')
      .first();
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
  resetField(validationContainer) {
    $(validationContainer)
      .children('.single_error')
      .remove();
    $(validationContainer).removeClass('has-error');
  }
  findItemsForField(validationContainer) {
    let items = [];
    if ($(validationContainer).data('key') != undefined) {
      items = $(validationContainer).find('[name^="' + $(validationContainer).data('key') + '"]');
    } else if ($(validationContainer).children('label').length) {
      items = $(validationContainer).find(
        '#' +
          $(validationContainer)
            .children('label')
            .first()
            .prop('for')
      );
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

    if (
      this.form.hasClass('bulk-edit-form') &&
      !$(validationContainer)
        .siblings('.bulk-update-check[data-attribute-key="' + $(validationContainer).data('key') + '"]')
        .find(':checkbox')
        .prop('checked')
    )
      return;

    let items = this.findItemsForField(validationContainer);
    if (!items.length) return;
    let form_data = items.serializeArray();
    if (form_data.length == 0) {
      form_data.push({
        name: items.prop('name')
      });
    }
    let uuid = this.form.find(':input[name="uuid"]').val();
    let table = this.form.find(':input[name="table"]').val() || 'things';
    let url = '/' + table + (uuid != undefined ? '/' + uuid : '') + '/validate';
    let template = this.form.find(':input[name="template"]').val();
    if (template != undefined) {
      form_data.push({
        name: 'template',
        value: template
      });
    }
    return $.ajax({
      type: 'POST',
      url: url,
      data: $.param(form_data),
      dataType: 'json'
    }).done(data => {
      if (data != undefined && Object.keys(data.error).length > 0) {
        if (
          items
            .filter('[id]')
            .first()
            .prop('id')
            .search(new RegExp(Object.keys(data.error).join('|'), 'i')) != -1
        ) {
          $(validationContainer)
            .append(this.renderErrorMessage(data, validationContainer))
            .addClass('has-error');
        }
      } else {
        this.removeSubmitButtonErrors(validationContainer);
      }
    });
  }
  validateForm(event, data) {
    event.preventDefault();
    event.stopImmediatePropagation();
    QuillHelpers.update_editors(event.target);
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
    confirmations = { finalize: true, confirm: true, warnings: undefined, merge: false, saveAndClose: false }
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

    if (confirmations.merge && this.mergeDuplicateButton.data('confirm') !== undefined) {
      return new ConfirmationModal({
        text: this.mergeDuplicateButton.data('confirm'),
        confirmationClass: 'alert',
        cancelable: true,
        confirmationCallback: () => {
          confirmations.merge = false;
          this.submitForm(confirmations);
        },
        cancelCallback: () => this.enable()
      });
    }

    this.triggerFormSubmit(confirmations && confirmations.saveAndClose);
  }
  triggerFormSubmit(saveAndClose = false) {
    if (this.form.closest('.reveal').hasClass('in-object-browser')) {
      return this.form.trigger('submit_without_redirect');
    } else {
      $(window).off('beforeunload');
      if (saveAndClose) this.form.append('<input type="hidden" name="save_and_close" value="1">');
      this.form.trigger('submit.rails');
    }
  }
  resolveRequests(submit = false, eventData = undefined) {
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
          let confirmations = {
            finalize: true,
            confirm: true,
            warnings: warnings.length ? warnings : undefined,
            merge: eventData && eventData.mergeConfirm,
            saveAndClose: eventData && eventData.saveAndClose
          };

          this.submitForm(confirmations);
        } else if (!this.valid && submit) {
          if (this.form.hasClass('edit-content-form') && error !== undefined && error[0] !== undefined) {
            error[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
          }
        }
        if (!(this.valid && submit)) this.enable();
        if (this.valid && eventData !== undefined && eventData.success_callback !== undefined) {
          eventData.success_callback();
        }
        if (!this.valid && eventData !== undefined && eventData.error_callback !== undefined) {
          eventData.error_callback();
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

module.exports = Validator;

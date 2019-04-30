// Form Validator
let ConfirmationModal = require('./../components/confirmation_modal');
let quill_helpers = require('./../helpers/quill_helpers');

class Validator {
  constructor(form_element) {
    this.form = $(form_element);
    this.submit_button = this.form.siblings('.edit-header').find('.submit-edit-form');
    this.language_menu = this.form.siblings('.edit-header').find('#language-menu');
    this.agbs_check = this.form.siblings('.edit-header').find('.form-element.agbs');
    this.initial_form_data = [];
    this.submit_form_data = [];
    this.requests = [];
    this.query_count = 0;
    this.valid = true;
    this.addEventHandlers();
  }
  addEventHandlers() {
    this.form.on('change dc:form:validatefield', '.validation-container', this.validateSingle.bind(this));
    this.form.on('dc:form:validate', '*', this.validateForm.bind(this));
    this.form.on('remove-submit-button-errors', '.validation-container', event =>
      this.removeSubmitButtonErrors($(event.currentTarget))
    );
    this.submit_button.on('click', event => {
      event.preventDefault();
      event.stopImmediatePropagation();
      this.form.trigger('submit');
    });
    this.form.on('submit', this.validateForm.bind(this));
    if (this.form.hasClass('edit-content-form')) {
      this.pageLeaveWarning();
    }
    this.form.on('click', '.close-error', this.closeError.bind(this));
    this.agbs_check.on('click', '.close-error', this.closeError.bind(this));
    this.agbs_check.on('change', this.validateSingle.bind(this));
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
  finalizeUpdate() {}
  pageLeaveWarning() {
    quill_helpers.update_editors(this.form);
    this.initial_form_data = this.form.serializeArray();
    $(window).on('beforeunload', event => {
      quill_helpers.update_editors(this.form);
      this.submit_form_data = this.form.serializeArray();
      if (this.initial_form_data.length !== 0 && !this.initial_form_data.equal_to(this.submit_form_data))
        return 'Wollen Sie die Seite wirklich verlassen ohne zu speichern?';
    });
    // language redirect if changes present
    if (this.language_menu.length) {
      this.language_menu.on('click', '.list-items li a', event => {
        quill_helpers.update_editors(this.form);
        this.submit_form_data = this.form.serializeArray();
        if (this.initial_form_data.length !== 0 && !this.initial_form_data.equal_to(this.submit_form_data)) {
          event.preventDefault();
          new ConfirmationModal('Wollen Sie speichern und auf die neue Sprache wechseln?', 'success', true, () => {
            this.form.append('<input type="hidden" name="new_locale" value="' + $(event.target).data('locale') + '">');
            this.form.trigger('submit');
          });
        }
      });
    }
  }
  validateAgbs(validation_container) {
    let error = {
      error: {},
      warning: {}
    };
    let agbs = $(validation_container).find(':checkbox[name="accept_agbs"]');
    if (agbs.length && !agbs.prop('checked')) {
      $(validation_container)
        .append(this.renderErrorMessage({ error: { agbs: ['AGBs müssen akzeptiert werden!'] } }, validation_container))
        .addClass('has-error');
      error.error = {
        agbs: ['AGBs müssen akzeptiert werden!']
      };
    } else {
      this.removeSubmitButtonErrors(validation_container);
    }
    return error;
  }
  disable() {
    $.rails.disableFormElement(
      this.form
        .siblings('.edit-header')
        .find('.submit-edit-form')
        .first()
    );
    $.rails.disableFormElements(this.form);
  }
  enable() {
    if (this.query_count == 0 && !this.form.hasClass('disabled')) {
      $.rails.enableFormElement(
        this.form
          .siblings('.edit-header')
          .find('.submit-edit-form')
          .first()
      );
      $.rails.enableFormElements(this.form);
    }
  }
  renderErrorMessage(data, validation_container) {
    let out = '';
    let item_id = '';
    let item_label = $(validation_container)
      .find('label')
      .first();
    let button_text = '';
    if (validation_container != null && $(validation_container).data('id') != undefined)
      item_id = $(validation_container).data('id') + '_error';
    else if (validation_container != null && $(item_label).attr('for') != undefined)
      item_id = $(item_label).attr('for') + '_error';
    if ($('#' + item_id).length != 0) return '';
    button_text = '<span id="button_' + item_id + '" class="tooltip-error">';
    out = "<span id='" + item_id + "' class='single_error'>";
    for (let key in data.error) {
      if (
        ($(validation_container).data('id') != undefined &&
          $(validation_container)
            .data('id')
            .search(new RegExp(key, 'i')) != -1) ||
        ($(validation_container).data('id') == undefined &&
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
      this.submit_button.addClass('alert');
      $('#' + this.submit_button.data('toggle') + ' #button_' + item_id).remove();
      $('#' + this.submit_button.data('toggle')).append(button_text + '</span>');
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
      this.submit_button.removeClass('alert');
      $('#' + this.submit_button.data('toggle') + ' .tooltip-error').remove();
    } else {
      $('#' + this.submit_button.data('toggle') + ' #button_' + item_id).remove();
      if ($('#' + this.submit_button.data('toggle') + ' .tooltip-error').length == 0) {
        this.submit_button.removeClass('alert');
      }
    }
  }
  resetField(validation_container) {
    $(validation_container)
      .children('.single_error')
      .remove();
    $(validation_container).removeClass('has-error');
  }
  findItemsForField(validation_container) {
    let items = [];
    if ($(validation_container).data('key') != undefined) {
      items = $(validation_container).find('[name^="' + $(validation_container).data('key') + '"]');
    } else if ($(validation_container).children('label').length) {
      items = $(validation_container).find(
        '#' +
          $(validation_container)
            .children('label')
            .first()
            .prop('for')
      );
    }
    return items;
  }
  validateItem(validation_container) {
    this.resetField(validation_container);
    if ($(validation_container).hasClass('agbs')) {
      return new Promise((resolve, reject) => {
        resolve(this.validateAgbs(validation_container));
      });
    }
    let items = this.findItemsForField(validation_container);
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
          $(validation_container)
            .append(this.renderErrorMessage(data, validation_container))
            .addClass('has-error');
        }
      } else {
        this.removeSubmitButtonErrors(validation_container);
      }
    });
  }
  validateForm(event, data) {
    event.preventDefault();
    event.stopImmediatePropagation();
    quill_helpers.update_editors(event.target);
    this.removeSubmitButtonErrors();
    this.disable();
    this.requests = [];
    $(event.target)
      .find('.validation-container:visible')
      .add(this.agbs_check)
      .each((i, elem) => {
        this.requests.push(this.validateItem(elem));
      });
    this.resolveRequests($(event.target).is(this.form), data);
  }
  submitForm(confirmations = { finalize: true, confirm: true, warnings: undefined }) {
    if (confirmations.warnings !== undefined) {
      return new ConfirmationModal(
        'Es sind Warnungen vorhanden (' +
          warnings
            .closest('.form-element')
            .map((i, elem) => $(elem).data('label'))
            .get()
            .join(', ') +
          ').<br>Soll der Inhalt trotzdem gespeichert werden?',
        'warning',
        true,
        () => {
          confirmations.warnings = undefined;
          this.submitForm(confirmations);
        },
        () => this.enable()
      );
    }

    if (confirmations.finalize && this.form.find(':input[name="finalize"]:checked').length) {
      return new ConfirmationModal(
        'Der Inhalt wird final abgeschickt und <br>kann danach nicht mehr bearbeitet werden.',
        'success',
        true,
        () => {
          confirmations.finalize = false;
          this.submitForm(confirmations);
        },
        () => this.enable()
      );
    }

    if (confirmations.confirm && this.submit_button.data('confirm') !== undefined) {
      return new ConfirmationModal(
        this.submit_button.data('confirm'),
        'alert',
        true,
        () => {
          confirmations.confirm = false;
          this.submitForm(confirmations);
        },
        () => this.enable()
      );
    }

    this.triggerFormSubmit();
  }
  triggerFormSubmit() {
    if (this.form.closest('.reveal').hasClass('in-object-browser')) {
      return this.form.trigger('submit_without_redirect');
    } else {
      $(window).off('beforeunload');
      this.form.trigger('submit.rails');
    }
  }
  resolveRequests(submit = false, event_data = undefined) {
    this.query_count++;
    let requests = this.requests.slice();
    this.requests = [];
    Promise.all(requests).then(
      values => {
        this.query_count--;
        this.valid = true;
        let error = this.form.find('.single_error').first();
        values.filter(Boolean).forEach(validation => {
          if (Object.keys(validation.error).length) this.valid = false;
        });
        if (this.valid && submit) {
          this.query_count = 0;
          let warnings = this.form.find('.form-element .warning.counter');
          let confirmations = {
            finalize: true,
            confirm: true,
            warnings: warnings.length ? warnings : undefined
          };

          this.submitForm(confirmations);
        } else if (!this.valid && submit) {
          if (this.form.hasClass('edit-content-form') && error !== undefined && error[0] !== undefined) {
            error[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
          }
        }
        if (!(this.valid && submit)) this.enable();
        if (this.valid && event_data !== undefined && event_data.success_callback !== undefined) {
          event_data.success_callback();
        }
        if (!this.valid && event_data !== undefined && event_data.error_callback !== undefined) {
          event_data.error_callback();
        }
        // scroll to step in multi-step form
        if (!this.valid && this.form.hasClass('multi-step') && error.is(':hidden')) {
          this.form.trigger('dc:multistep:goto', this.form.find('fieldset').index(error.closest('fieldset')));
        }
      },
      error => {
        this.query_count--;
        let button_text =
          '<span id="button_server_error" class="tooltip-error">' +
          '<strong>Fehler:</strong><br>' +
          error.statusText +
          '<br></span>';
        this.enable();
        this.submit_button.addClass('alert');
        $('#' + this.submit_button.data('toggle')).append(button_text);
      }
    );
  }
}

module.exports = Validator;

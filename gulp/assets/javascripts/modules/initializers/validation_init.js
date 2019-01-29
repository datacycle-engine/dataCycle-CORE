var ConfirmationModal = require('./../components/confirmation_modal');
var quill_helpers = require('./../helpers/quill_helpers');

// Add Validation to Form Elements
module.exports.initialize = function() {
  var promises = [];

  let check_agbs_accepted = function() {
    if ($('#accept_agbs').length > 0 && $('#accept_agbs').is(':checked')) {
      $('#' + $('.submit-edit-form').data('toggle') + ' #button_agbs_accepted').remove();
      return true;
    } else if ($('#accept_agbs').length > 0) {
      $('#' + $('.submit-edit-form').data('toggle')).append(
        '<span id="button_agbs_accepted" class="tooltip-error"><strong>AGBs</strong><br>Die AGBs müssen noch akzeptiert werden.<br></span>'
      );
      return false;
    } else return true;
  };

  let update_editors = function() {
    $('.quill-editor').each((index, elem) => {
      quill_helpers.update_value(elem);
    });
  };

  let catch_promises = function(form, submit) {
    $.when
      .apply(undefined, promises)
      .then(function() {
        promises = [];

        var isValid = true;
        if (Array.isArray(arguments[0])) {
          for (var i = 0; i < arguments.length; i++) {
            if (
              arguments[i][0] != undefined &&
              arguments[i][0].error != undefined &&
              Object.keys(arguments[i][0].error).length > 0
            ) {
              isValid = false;
            }
          }
        } else if (arguments[0] != undefined && arguments[0].error != undefined && Object.keys(arguments[0].error).length > 0) isValid = false;

        if (isValid && submit && $(form).find('.form-element .warning.counter').length) {
          var warnings = $('.form-element .warning.counter')
            .closest('.form-element')
            .map((index, elem) => {
              return $(elem).data('label');
            })
            .get()
            .join(', ');
          var confirmationModal = new ConfirmationModal(
            'Es sind Warnungen vorhanden (' + warnings + ').<br>Soll der Inhalt trotzdem gespeichert werden?',
            'warning',
            true,
            () => {
              if (
                $(form)
                  .closest('.reveal')
                  .hasClass('in-object-browser')
              ) {
                $(form).trigger('submit_without_redirect');
              } else {
                $(window).off('beforeunload');
                form.submit();
              }
            },
            () => {
              enable_form(form);
            }
          );
        } else if (isValid && submit) {
          if (
            $(form)
              .closest('.reveal')
              .hasClass('in-object-browser')
          ) {
            $(form).trigger('submit_without_redirect');
          } else {
            $(window).off('beforeunload');
            form.submit();
          }
        } else if (submit) {
          enable_form(form);

          var first_error_offset, container;
          if ($(form).hasClass('edit-content-form')) {
            var error_container = $('.single_error').first();

            if ($('.split-content.edit-content').length > 0) {
              container = $('.flex-box .edit-content');
              first_error_offset = error_container.offset().top - container.offset().top + container.scrollTop() - 50;
            } else {
              container = $('html, body');
              first_error_offset = error_container.offset().top - 100;
            }

            container.animate(
              {
                scrollTop: first_error_offset
              },
              500
            );
          }
        }
      })
      .fail(data => {
        var button_text =
          '<span id="button_server_error" class="tooltip-error">' +
          '<strong>Fehler:</strong><br>' +
          data.statusText +
          '<br></span>';

        enable_form(form);
        $('.submit-edit-form').addClass('alert');
        $('#' + $('.submit-edit-form').data('toggle')).append(button_text);
      });
  };

  function disable_form(form) {
    $.rails.disableFormElement(
      $(form)
        .siblings('.edit-header')
        .find('.submit-edit-form')
        .first()
    );
    $.rails.disableFormElements($(form));
  }

  function enable_form(form) {
    $.rails.enableFormElement(
      $(form)
        .siblings('.edit-header')
        .find('.submit-edit-form')
        .first()
    );
    $.rails.enableFormElements($(form));
  }

  let render_error_msg = function(data, validation_container) {
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
        button_text += '<strong>' + ($(item_label).html() || 'Error') + ':</strong><br>' + data.error[key] + '<br>';
        out += '<strong>' + ($(item_label).html() || 'Error') + ':</strong> ' + data.error[key] + '</br>';
      }
    }
    out += '</span>';

    if ($(out).text().length == 0) return ''; // return if there are no errors for this container
    if (
      $(validation_container)
        .closest('form')
        .hasClass('edit-content-form')
    ) {
      $('.submit-edit-form').addClass('alert');
      $('#' + $('.submit-edit-form').data('toggle'))
        .find('#button_' + item_id)
        .remove();
      $('#' + $('.submit-edit-form').data('toggle')).append(button_text + '</span>');
    }
    return out;
  };

  let remove_submit_button_errors = function(item = null) {
    var item_id = '';
    let item_label = $(item)
      .find('label')
      .first();
    if (item != null && $(item).data('id') != undefined) item_id = $(item).data('id') + '_error';
    else if (item != null && $(item_label).attr('for') != undefined) item_id = $(item_label).attr('for') + '_error';

    if (item == null) {
      $('.submit-edit-form').removeClass('alert');
      $('#' + $('.submit-edit-form').data('toggle') + ' .tooltip-error').remove();
    } else {
      $('#' + $('.submit-edit-form').data('toggle'))
        .find('#button_' + item_id)
        .remove();
      if ($('#' + $('.submit-edit-form').data('toggle') + ' .tooltip-error').length == 0) {
        $('.submit-edit-form').removeClass('alert');
      }
    }
  };

  let validate_item = function(form, validation_container) {
    //reset errors
    $(validation_container)
      .children('.single_error')
      .remove();
    $(validation_container).removeClass('has-error');

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

    if (!items.length) return;

    let form_data = items.serializeArray();
    if (form_data.length == 0) {
      form_data.push({
        name: items.prop('name')
      });
    }

    let uuid = $(form)
      .find('input#uuid')
      .val();
    let table = $(form)
      .find('input#table')
      .val();
    let template = $(form).find('#template');
    if (template.length) {
      form_data.push({
        name: 'template',
        value: template.val()
      });
    }

    let url = '/' + table + (uuid != undefined ? '/' + uuid : '') + '/validate';

    promises.push(
      $.ajax({
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
            $(validation_container).append(render_error_msg(data, validation_container));
            $(validation_container).addClass('has-error');
          }
        } else {
          remove_submit_button_errors(validation_container);
        }
      })
    );
  };

  let submit_thing_form = function(form) {
    update_editors();
    disable_form(form);

    $('#validation_errors').html('');

    var items = [];
    promises = [];

    $(form)
      .find('.validation-container')
      .each((index, elem) => {
        validate_item(form, elem);
        items.push(elem);
      });
    catch_promises(form, true);
  };

  let init_event_handlers = function(container) {
    $(container)
      .find('.validation-form')
      .each((index, element) => {
        $(element).on('change', '.validation-container', event => {
          promises = [];
          validate_item(element, event.currentTarget);
          catch_promises(element, false);
        });

        $(element).on('remove-submit-button-errors', '.validation-container', event => {
          remove_submit_button_errors($(event.currentTarget));
        });

        $(element).on('submit', event => {
          event.preventDefault();
          event.stopImmediatePropagation();
          submit_thing_form(element);
        });
      });
  };

  let remove_event_handlers = function(container) {
    $(container)
      .find('.validation-form')
      .each((index, element) => {
        $(element).off('change', '.validation-container');
        $(element).off('remove-submit-button-errors', '.validation-container');
        $(element).off('submit');
        enable_form(element);
      });
  };

  // check if data changed and confirm leaving the page
  if ($('.edit-content-form').length > 0) {
    var form_data = [];
    $(window).on('load', event => {
      update_editors();
      form_data = $('.edit-content-form').serializeArray();
    });

    $(window).on('beforeunload', function() {
      update_editors();
      var new_form_data = $('.edit-content-form').serializeArray();

      if (form_data.length !== 0 && !form_data.equal_to(new_form_data))
        return 'Wollen Sie die Seite wirklich verlassen ohne zu speichern?';
    });

    // language redirect if changes present
    if ($('.edit-header #language-menu').length) {
      $(document).on('click', '.edit-header #language-menu .list-items li a', event => {
        update_editors();
        var new_form_data = $('.edit-content-form').serializeArray();
        if (form_data.length !== 0 && !form_data.equal_to(new_form_data)) {
          event.preventDefault();

          var confirmationModal = new ConfirmationModal(
            'Wollen Sie speichern und auf die neue Sprache wechseln?',
            'success',
            true,
            function() {
              $('.edit-content-form').append(
                '<input type="hidden" name="new_locale" value="' + $(event.target).data('locale') + '">'
              );
              $('.edit-content-form').trigger('submit');
            }.bind(this)
          );
        }
      });
    }
  }

  // Validation

  if ($('.validation-form').length > 0) {
    // disable button if agbs not accepted
    $('button.submit-edit-form').toggleClass('alert', !check_agbs_accepted());

    if ($('#accept_agbs').length > 0) {
      $('#accept_agbs').on('change', function(event) {
        $('button.submit-edit-form').toggleClass('alert', !check_agbs_accepted());
      });
    }

    var form = document.querySelector('.edit-content-form');
    $('button.submit-edit-form').on('click', function(ev) {
      ev.preventDefault();

      if (!check_agbs_accepted()) {
        return false;
      }

      remove_submit_button_errors();

      if ($(form).find('input#finalize:checked').length > 0) {
        var confirmationModal = new ConfirmationModal(
          'Der Inhalt wird final abgeschickt und <br>kann danach nicht mehr bearbeitet werden.',
          'success',
          true,
          function() {
            $(form).trigger('submit');
          }.bind(this)
        );
      } else {
        $(form).trigger('submit');
      }
    });

    // validate on value change
    init_event_handlers('body');
  }

  $(document).on('open.zf.reveal', '.new-content-reveal[data-reset-on-close]', event => {
    init_event_handlers(event.currentTarget);
  });

  $(document).on('closed.zf.reveal', '.new-content-reveal[data-reset-on-close]', event => {
    remove_event_handlers(event.currentTarget);
  });

  $(document).on('closed.zf.reveal', '.new-content-reveal', event => {
    $(event.currentTarget)
      .find('.has-error')
      .removeClass('has-error');
    $(event.currentTarget)
      .find('.single_error')
      .remove();
  });
};

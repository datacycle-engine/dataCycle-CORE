var ConfirmationModal = require('./../components/confirmation_modal');
var quill_helpers = require('./../helpers/quill_helpers');

// Add Validation to Form Elements
module.exports.initialize = function () {

  // Status Kommentar setzen

  $(document).on('click', '.release-comment-overlay .save', function (e) {
    var $input_field = $(e.target).siblings('.release-comment').first();
    var id = $(e.target).data('hidden-field-id');
    var value = $input_field.val();
    $('input[type=hidden]#' + id).val(value);
  });

  // check if data changed and confirm leaving the page

  if ($('.edit-content-form').length > 0) {
    var form_data = "";
    setTimeout(function () {
      form_data = $('.edit-content-form').serialize();
    }, 1000);

    $(window).on("beforeunload", function () {
      var new_form_data = $('.edit-content-form').serialize();
      if (form_data != new_form_data && form_data != "") return 'Wollen Sie die Seite wirklich verlassen ohne zu speichern?';
    });
  }

  function check_agbs_accepted() {
    if ($('#accept_agbs').length > 0 && $('#accept_agbs').is(':checked')) {
      $('#' + $('.submit-edit-form').data('toggle') + ' #button_agbs_accepted').remove();
      return true;
    } else if ($('#accept_agbs').length > 0) {
      $('#' + $('.submit-edit-form').data('toggle')).append('<span id="button_agbs_accepted" class="tooltip-error"><strong>AGBs</strong><br>Die AGBs müssen noch akzeptiert werden.<br></span>');
      return false;
    } else return true;
  }

  // Validation

  if ($('.edit-content-form').length > 0) {
    // disable button if agbs not accepted
    $('button.submit-edit-form').prop('disabled', !check_agbs_accepted());

    if ($('#accept_agbs').length > 0) {
      $('#accept_agbs').on('change', function (event) {
        $('button.submit-edit-form').prop('disabled', !check_agbs_accepted());
      });
    }

    var form = document.querySelector('.edit-content-form');
    $('button.submit-edit-form').on('click', function (ev) {
      ev.preventDefault();

      if ($(form).find('input#finalize:checked').length > 0) {
        var confirmationModal = new ConfirmationModal('Der Inhalt wird final abgeschickt und <br>kann danach nicht mehr bearbeitet werden.', 'success', true, function () {
          $(form).trigger('submit');
        }.bind(this));
      } else {
        $(form).trigger('submit');
      }
    });
    var promises = [];

    // validate on value change
    $(form).on('change', '.validation-container', event => {
      validate_item(form, event.currentTarget);
      catch_promises(form, false);
    });

    $(form).on('remove-submit-button-errors', '.validation-container', event => {
      remove_submit_button_errors($(event.currentTarget));
    })

    $(form).on('submit', function (event) {
      event.preventDefault();
      submit_creative_work_form(form);
    });
  }

  if ($('.new-item form').html() != undefined) {
    var forms = $('.new-item form');

    $(document).on('open.zf.reveal', '.new-item', function (ev) {
      $(this).find('form').on('submit', function (event, data) {
        event.preventDefault();
        // event.stopPropagation();
        // event.stopImmediatePropagation();
        if (data != undefined && data.object_browser) {
          if (check_fields(this)) $(this).trigger('submit', {
            valid: true
          });
        } else if (data == undefined && check_fields(this)) this.submit();
      });

      $(this).find('form .validation-container').each(function (e) {
        $(this).on('change', function () {
          $(this).closest('form').find('input[type=submit]').removeAttr('disabled');
          $(this).find('.single_error').remove();
          check_field(this);
        });
      });
    });

    $(document).on('closed.zf.reveal', '.new-item', function (e) {
      $(this).find('form').off('submit');
      $(this).find('form input[type=text]').each(function (ev) {
        $(this).off('change');
      });
    });
  }

  function catch_promises(form, submit) {
    $.when.apply($, promises).then(function () {
      var isValid = true;
      for (var i = 0; i < arguments.length; i++) {
        if (arguments[i][0] != undefined && arguments[i][0].error != undefined && Object.keys(arguments[i][0].error).length > 0) {
          isValid = false;
        }
      }
      promises = [];
      if (isValid && submit) {
        $(window).off("beforeunload");
        form.submit();
      } else if (submit) {
        var first_error_offset, container;
        var error_container = $('.single_error').first();

        if ($('.split-content.edit-content').length > 0) {
          container = $('.flex-box .edit-content');
          first_error_offset = error_container.offset().top - container.offset().top + container.scrollTop() - 50;
        } else {
          container = $('html, body');
          first_error_offset = error_container.offset().top - 100;
        }

        container.animate({
          scrollTop: first_error_offset
        }, 500);
      }
    });
  }

  function check_fields(form) {
    var isValid = true;
    $(form).find('.validation-container').each((idx, elem) => {
      if (check_field(elem) == false) isValid = false;
    });
    return isValid;
  }

  function check_field(field) {
    let input_field = $(field).find(':input').first();
    if ($(input_field).val().length == 0) {
      var data = {
        error: {}
      };
      data.error[$(input_field).prop('id')] = ["Feld darf nicht leer sein"];
      $(field).append(render_error_msg(data, field));
      return false;
    }
    remove_submit_button_errors(field);
    return true;
  }

  function submit_creative_work_form(form) {
    $('.quill-editor').each((index, elem) => {
      quill_helpers.update_value(elem);
    });

    $('#validation_errors').html('');

    var items = [];

    $(form).find('.validation-container').each(function () {
      validate_item(form, this);
      items.push(this);
    });
    catch_promises(form, true);
  }

  function validate_item(form, validation_container) {
    //reset errors
    $(validation_container).children('.single_error').remove();
    $(validation_container).removeClass('has-error');

    let items = $(validation_container).find('[name^="' + $(validation_container).data('key') + '"]');
    let form_data = items.serializeArray();
    let uuid = $(form).find('input#uuid').val();
    let table = $(form).find('input#type').val();

    let url = '/' + table + '/' + uuid + '/validate';

    promises.push($.ajax({
      type: "POST",
      url: url,
      data: $.param(form_data)
    }).done(data => {
      if (data != undefined && Object.keys(data.error).length > 0) {
        if (items.first().prop('id').search(new RegExp(Object.keys(data.error).join('|'), 'i')) != -1) {
          $(validation_container).append(render_error_msg(data, validation_container));
          $(validation_container).addClass('has-error');
        }
      } else {
        remove_submit_button_errors(validation_container);
      }
    }));
  }

  function render_error_msg(data, validation_container) {
    let out = '';
    let item_id = '';
    let item_label = $(validation_container).find('label').first();
    let button_text = '';

    if (validation_container != null && $(validation_container).data('id') != undefined) item_id = $(validation_container).data('id') + "_error";
    else if (validation_container != null && $(item_label).attr('for') != undefined) item_id = $(item_label).attr('for') + "_error";

    if ($('#' + item_id).length != 0) return '';

    $('.submit-edit-form').addClass('alert');
    $('#' + $('.submit-edit-form').data('toggle')).find('#button_' + item_id).remove();
    button_text = '<span id="button_' + item_id + '" class="tooltip-error">';
    out = "<span id='" + item_id + "' class='single_error'>";

    for (let key in data.error) {
      if (($(validation_container).data('id') != undefined && $(validation_container).data('id').search(new RegExp(key, 'i')) != -1) || ($(item_label).attr('for') != undefined && $(item_label).attr('for').search(new RegExp(key, 'i')) != -1)) {
        button_text += '<strong>' + ($(item_label).html() || 'Error') + ':</strong><br>' + data.error[key] + '<br>';
        out += "<strong>" + ($(item_label).html() || 'Error') + ":</strong> " + data.error[key] + "</br>";
      }
    }

    $('#' + $('.submit-edit-form').data('toggle')).append(button_text + '</span>');
    out += "</span>";
    return out;
  }

  function remove_submit_button_errors(item = null) {
    var item_id = '';
    let item_label = $(item).find('label').first();
    if (item != null && $(item).data('id') != undefined) item_id = $(item).data('id') + "_error";
    else if (item != null && $(item_label).attr('for') != undefined) item_id = $(item_label).attr('for') + "_error";

    if (item == null) {
      $('.submit-edit-form').removeClass('alert');
      $('#' + $('.submit-edit-form').data('toggle') + ' .tooltip-error').remove();
    } else {
      $('#' + $('.submit-edit-form').data('toggle')).find('#button_' + item_id).remove();
      if ($('#' + $('.submit-edit-form').data('toggle') + ' .tooltip-error').length == 0) {
        $('.submit-edit-form').removeClass('alert');
      }
    }
  }

};

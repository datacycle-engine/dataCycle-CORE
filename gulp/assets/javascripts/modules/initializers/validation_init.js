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

  if ($('.editor').length > 0) {
    var form_data = "";
    setTimeout(function () {
      form_data = $('.editor').closest('form').serialize();
    }, 500);
    $(window).on("beforeunload", function () {
      update_editor_values();
      var new_form_data = $('.editor').closest('form').serialize();
      if (form_data != new_form_data) return 'Wollen Sie die Seite wirklich verlassen ohne zu speichern?';
    });
  }

  // Validation

  if ($('#edit-form form').html() != undefined) {
    var form = document.querySelector('#edit-form form');
    $('.submit-edit-form button').on('click', function (ev) {
      ev.preventDefault();
      $(form).trigger('submit');
    });
    var promises = [];

    $(form).on("focusout", '.validation-container', function (ev) {
      setTimeout(function () {
        if ($(this).find(':focus').addBack(':focus').length == 0) {
          update_editor_values();
          check_items_and_validate(form, this);
          catch_promises(form, false);
        }
      }.bind(this), 50);
    });
    form.onsubmit = function () {
      submit_creative_work_form(form);
      return false;
    };
  }

  if ($('.new-item form').html() != undefined) {
    var forms = $('.new-item form');

    $(document).on('open.zf.reveal', '.new-item', function (e) {
      $(this).find('form').on('submit', function (e) {
        e.preventDefault();
        if (check_fields(this)) this.submit();
      }.bind(this));

      $(this).find('form input[type=text]').each(function (e) {
        $(this).on('change', function () {
          $(this).closest('form').find('input[type=submit]').removeAttr('disabled');
          $(this).closest('.validation-container').find('.single_error').remove();
          check_field(this);
        });
      });
    }.bind(this));

    $(document).on('closed.zf.reveal', '.new-item', function (e) {
      $(this).find('form').off('submit');
      $(this).find('form input[type=text]').each(function (e) {
        $(this).off('change');
      });
    }.bind(this));

    $(forms).each(function () {
      $(this).on('submit', function (e) {
        e.preventDefault();
        if (check_fields(this)) this.submit();
      }.bind(this));

      $(this).find('input[type=text]').each(function (e) {
        $(this).on('change', function () {
          $(this).closest('form').find('input[type=submit]').removeAttr('disabled');
          $(this).closest('.validation-container').find('.single_error').remove();
          check_field(this);
        });
      });
    });
  }

  function catch_promises(form, submit) {
    $.when.apply($, promises).then(function () {
      var isValid = true;
      for (var i = 0; i < arguments.length; i++) {
        if (arguments[i][0] != undefined && arguments[i][0].error != undefined && arguments[i][0].error.length > 0) {
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
          first_error_offset = $('.single_error').first().offset().top - 100;
        }

        container.animate({
          scrollTop: first_error_offset
        }, 500);
      }
    });
  }

  function check_fields(form) {
    var isValid = true;
    $(form).find('input[type=text]:not(.no-validation)').each(function (e) {
      if (check_field(this) == false) isValid = false;
    });
    return isValid;
  }

  function check_field(field) {
    if ($(field).val().length == 0) {
      var data = {};
      data.error = ["Feld darf nicht leer sein"];
      $(field).closest('.validation-container').append(render_error_msg(data, field));
      return false;
    }
    remove_submit_button_errors(field);
    return true;
  }

  function submit_creative_work_form(form) {
    //get quill-js values
    update_editor_values();

    $('#validation_errors').html('');

    var items = [];

    $(form).find('.validation-container').each(function () {
      check_items_and_validate(form, this);
      items.push(this);
    });
    catch_promises(form, true);
  }

  function check_items_and_validate(form, validation_container) {
    var $itemsToValidate = $(validation_container).find('[data-validate]');
    if ($itemsToValidate.length > 0) {
      var items;

      if ($itemsToValidate.first().data('validate') == "text") items = $itemsToValidate;
      else if ($itemsToValidate.first().data('validate') == "classification") items = $(validation_container).find('input[type="hidden"]');
      else if ($itemsToValidate.first().data('validate') == "daterange") items = $(validation_container).find('input[data-validate="daterange"]');

      validate_single_item(form, items);
    }
  }

  function update_editor_values() {
    if ($('.quill-editor').html() != undefined) {
      $('.quill-editor').each(function () {
        set_fe_editor_values(this);
      });
    }
  }

  function set_fe_editor_values(editor) {
    var hidden_field_id = $(editor).attr('data-hidden-field-id');
    var hidden_field = document.querySelector('input#' + hidden_field_id);
    var text = $(editor).find('.ql-editor').html();
    if (text != undefined) hidden_field.value = text.replace("<p><br></p>", "");
  }

  function validate_single_item(form, item) {
    //reset errors
    $(item).closest('.validation-container').find('.single_error').remove();
    $(item).closest('.validation-container').removeClass('has-error');

    var uuid = $(form).find('input#uuid').val();

    var formdata = $(item).serializeArray();

    is_creative_work = new RegExp('^' + 'creative_work', 'i');
    is_person = new RegExp('^' + 'person', 'i');
    is_place = new RegExp('^' + 'place', 'i');

    if (formdata.length > 0 && is_creative_work.test(formdata[0].name)) {
      var validation_url = /validatecreativework/;
    } else if (formdata.length > 0 && is_person.test(formdata[0].name)) {
      var validation_url = /validateperson/;
    } else if (formdata.length > 0 && is_place.test(formdata[0].name)) {
      var validation_url = /validateplace/;
    } else {
      return false;
    }

    var url = validation_url + uuid;

    promises.push($.ajax({
      type: "POST",
      url: url,
      data: $.param(formdata)
    }).done(function (data) {
      if (data != undefined && data.error.length > 0) {
        $(item).closest('.validation-container').append(render_error_msg(data, item));
        $(item).closest('.validation-container').addClass('has-error');
      } else {
        remove_submit_button_errors(item);
      }
    }));
  }

  function render_error_msg(data, item) {
    var out = '';
    var item_id = '';
    var button_text = '';
    $('.submit button').addClass('alert');

    if (item != null && $(item).attr('id') != undefined) item_id = $(item).attr('id') + "_error";
    else if (item != null && $(item).closest('.form-element').find('label').first().attr('for') != undefined) item_id = $(item).closest('.form-element').find('label').first().attr('for') + "_error";

    item_label = (item != null) ? $(item).closest('.form-element').find('label').first().html() + ": " : "";
    $('#' + $('.submit button').data('toggle')).find('#button_' + item_id).remove();
    button_text = '<span id="button_' + item_id + '" class="tooltip-error">';
    out = "<span id='" + item_id + "' class='single_error'>";
    $.each(data.error, function (key, val) {
      button_text += '<strong>' + item_label + '</strong><br>' + val + '<br>';
      out += "<strong>" + item_label + "</strong>" + val + "</br>";
    });
    $('#' + $('.submit button').data('toggle')).append(button_text + '</span>');
    out += "</span>";
    return out;
  }

  function remove_submit_button_errors(item = null) {
    var item_id = '';
    if (item != null && $(item).attr('id') != undefined) item_id = $(item).attr('id') + "_error";
    else if (item != null && $(item).closest('.form-element').find('label').first().attr('for') != undefined) item_id = $(item).closest('.form-element').find('label').first().attr('for') + "_error";

    if (item == null) {
      $('.submit button').removeClass('alert');
      $('#' + $('.submit button').data('toggle') + ' .tooltip-error').remove();
    } else {
      $('#' + $('.submit button').data('toggle')).find('#button_' + item_id).remove();
      if ($('#' + $('.submit button').data('toggle') + ' .tooltip-error').length == 0) {
        $('.submit button').removeClass('alert');
      }
    }
  }

};

// Add Validation to Form Elements
module.exports.initialize = function () {

  if ($('#edit-form form').html() != undefined) {
    var form = document.querySelector('#edit-form form');
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
      if (isValid && submit) form.submit();
      else if (submit) {
        var first_error_offset = $('.single_error').first().offset().top;
        $(window).scrollTop(first_error_offset - 100);
      }
    });
  }

  function check_fields(form) {
    var isValid = true;
    $(form).find('input[type=text]').each(function (e) {
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
    hidden_field.value = text.replace("<p><br></p>", "");
  }

  function validate_single_item(form, item) {
    //reset errors
    $(item).closest('.validation-container').find('.single_error').remove();
    $(item).closest('.validation-container').removeClass('has-error');

    var uuid = $(form).find('input#uuid').val();

    var formdata = $(item).serializeArray();

    is_creative_work = new RegExp('^' + 'creative_work', 'i');
    is_person = new RegExp('^' + 'person', 'i');

    if (is_creative_work.test(formdata[0].name)) {
      var validation_url = /validatecreativework/;
    } else if (is_person.test(formdata[0].name)) {
      var validation_url = /validateperson/;
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
      }
    }));
  }

  function render_error_msg(data, item) {
    var out = '';
    var item_id = '';
    if (item != null && $(item).attr('id') != undefined) item_id = "id='" + $(item).attr('id') + "_error'";
    else if (item != null && $(item).closest('.form-element').find('label').first().attr('for') != undefined) item_id = "id='" + $(item).closest('.form-element').find('label').first().attr('for') + "_error'";

    item_label = (item != null) ? $(item).closest('.form-element').find('label').first().html() + ": " : "";
    out = "<span " + item_id + "class='single_error'>";
    $.each(data.error, function (key, val) {
      out += "<strong>" + item_label + "</strong>" + val + "</br>";
    });
    out += "</span>";
    return out;
  }

};
// Add Validation to Form Elements
module.exports.initialize = function () {

  if ($('#edit-form form').html() != undefined) {
    var form = document.querySelector('#edit-form form');

    $(form).find('.validation-container').on("focusout", function (ev) {
      setTimeout(function () {
        if ($(this).find(':focus').addBack(':focus').length == 0) {
          check_items_and_validate(form, this);
        }
      }.bind(this), 50);

    });
    form.onsubmit = function () {
      return submit_creative_work_form(form);
    };
  }

  function submit_creative_work_form(form) {
    //get quill-js values
    if ($('.quill-editor').html() != undefined) {
      $('.quill-editor').each(function () {
        set_fe_editor_values(this);
      });
    }

    var isValid = validate_complete_form(form);

    if (isValid == true) {
      form.submit();
    } else {
      return false;
    }
  }

  function check_items_and_validate(form, validation_container) {
    var $itemsToValidate = $(validation_container).find('[data-validate]');
    if ($itemsToValidate.length > 0) {
      var items;

      if ($itemsToValidate.first().data('validate') == "text") items = $itemsToValidate;
      else if ($itemsToValidate.first().data('validate') == "classification") items = $(validation_container).find('input[type="hidden"]');
      else if ($itemsToValidate.first().data('validate') == "daterange") items = $(validation_container).find('input[data-validate="daterange"]');

      return validate_single_item(form, items);
    }
  }

  function set_fe_editor_values(editor) {
    var hidden_field_id = $(editor).attr('data-hidden-field-id');
    var hidden_field = document.querySelector('input#' + hidden_field_id);
    hidden_field.value = $(editor).find('.ql-editor').html();
  }

  function validate_complete_form(form) {
    $('#validation_errors').html('');

    var isValid = true;

    $(form).find('.validation-container').each(function () {
      if (check_items_and_validate(form, this) == false) isValid = false;
    });
    return isValid;
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

    isValid = true;

    $.ajax({
      type: "POST",
      url: url,
      data: $.param(formdata), // serializes the form's elements.
      async: false,
      success: function (data) {
        if (data.error.length > 0) {
          $(item).closest('.validation-container').append(render_error_msg(data, item));
          $(item).closest('.validation-container').addClass('has-error');
          isValid = false;
        }
      }
    });

    return isValid;
  }

  function render_error_msg(data, item) {
    var out = '';
    var item_id = '';
    if (item != null && $(item).attr('id') != undefined) item_id = "id='" + $(item).attr('id') + "_error'";
    else if (item != null && $(item).closest('.form-element').find('label').first().attr('for') != undefined) item_id = "id='" + $(item).closest('.form-element').find('label').first().attr('for') + "_error'";

    item_label = (item != null) ? $(item).closest('.form-element').find('label').first().html() + ": " : "";
    $.each(data.error, function (key, val) {
      out += "<span " + item_id + "class='single_error'><strong>" + item_label + "</strong>" + val + "</span>";
    });
    return out;
  }

};
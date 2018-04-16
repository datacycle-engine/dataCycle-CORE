var ConfirmationModal = require('./../components/confirmation_modal');

// Datalist
module.exports.initialize = function () {

  $('.ajax-datalist').each((idx, element) => {
    let list = $(element).prop('list');
    let list_id = $(element).attr('list');
    $(list).html('');

    $(element).on('input', (event) => {
      event.preventDefault();
      $.get('/' + list_id + '/search', {
        q: $(event.currentTarget).val()
      }, data => {
        if (eval('typeof ' + list_id + ' === "function"')) {
          eval(list_id)(element, list, data);
        } else default_success(element, list, data);
      });
    });
  });

  let default_success = function (input_field, list, data) {
    $(list).html('');

    data.forEach(element => {
      if (element != undefined && element.name != undefined && element.id != undefined) {
        $(list).append('<option data-id="' + element.id + '" value="' + element.name + '">');
      }
    });
  }

  let users = function (input_field, list, data) {
    $(list).html('');
    data.forEach(element => {
      if (element != undefined && element.email != undefined) {
        $(list).append('<option data-familyname="' + element.family_name + '" data-givenname="' + element.given_name + '" value="' + element.email + '">');
      }
    });

    if (filter_ci(list, $(input_field).val()).length) {
      let user = filter_ci(list, $(input_field).val());
      $(input_field).siblings('input[id$=given_name]').first().val(user.data('givenname')).prop('readonly', true);
      $(input_field).siblings('input[id$=family_name]').first().val(user.data('familyname')).prop('readonly', true);
    } else {
      $(input_field).siblings('input[id$=given_name]').first().prop('readonly', false);
      $(input_field).siblings('input[id$=family_name]').first().prop('readonly', false);
    }
  }

  let search_history = function (input_field, list, data) {
    default_success(input_field, list, data);
    let form = $(input_field).closest('form');

    if (filter_ci(list, $(input_field).val()).length) {
      let option_id = filter_ci(list, $(input_field).val()).data('id');
      form.find('input[name="stored_filter[id]"]').remove();
      form.append('<input type="hidden" id="stored_filter_id" name="stored_filter[id]" value="' + option_id + '">');
      form.find('input[type="submit"]').prop('value', form.find('input[type="submit"]').data('update'));
      form.off('submit', append_stored_filter_data);
      form.off('submit', show_confirmation).on('submit', show_confirmation);
    } else {
      form.find('input[name="stored_filter[id]"]').remove();
      form.find('input[type="submit"]').prop('value', form.find('input[type="submit"]').data('save'));
      form.off('submit', show_confirmation);
      form.off('submit', append_stored_filter_data).on('submit', append_stored_filter_data);
    }
  }

  let filter_ci = function (list, value) {
    return $(list).find('option').filter((idx, elem) => $(elem).val().toLowerCase() == value.toLowerCase());
  }

  let show_confirmation = function (event) {
    event.preventDefault();
    let confirmationModal = new ConfirmationModal('Filterparameter aktualisieren?', 'success', true, () => {
      append_stored_filter_data(event);
    }, () => $(event.currentTarget).find('input[type="submit"]').prop('disabled', ''));
  }

  let append_stored_filter_data = function (event) {
    event.preventDefault();
    let form = $('#search-form');
    $(form).prop('action', $(event.currentTarget).prop('action'));
    $(form).prop('method', $(event.currentTarget).prop('method'));
    $(form).append($(event.currentTarget).find('input[type=hidden]').clone());
    $(form).append('<input type="hidden" name="stored_filter[name]" value="' + $(event.currentTarget).find('#stored_filter_name').val() + '">');
    $(form).append('<input type="hidden" name="stored_filter[system]" value="' + $(event.currentTarget).find('#stored_filter_system').is(':checked') + '">');
    form.submit();
  }

};

// import ConfirmationModal from './../components/confirmation_modal';
import DataList from './../components/data_list';

export default function () {
  // var field_requests = {};

  // let default_success = function (input_field, list, data) {
  //   $(list).html('');

  //   data.forEach(element => {
  //     if (element != undefined && element.name != undefined && element.id != undefined) {
  //       $(list).append('<option data-id="' + element.id + '" value="' + element.name + '">');
  //     }
  //   });
  // };

  // let users = function (input_field, list, data) {
  //   $(list).html('');
  //   data.forEach(element => {
  //     if (element != undefined && element.email != undefined) {
  //       $(list).append(
  //         '<option data-familyname="' +
  //           element.family_name +
  //           '" data-givenname="' +
  //           element.given_name +
  //           '" data-id="' +
  //           element.id +
  //           '" value="' +
  //           element.email +
  //           '">'
  //       );
  //     }
  //   });
  //   let form = $(input_field).closest('form');

  //   if (filter_ci(list, $(input_field).val()).length) {
  //     let user = filter_ci(list, $(input_field).val());
  //     form.find('input[name="data_link[receiver][id]"]').remove();
  //     form.append(
  //       '<input type="hidden" id="' +
  //         $(input_field).prop('id').replace('email', 'id') +
  //         '" name="data_link[receiver][id]" value="' +
  //         user.data('id') +
  //         '">'
  //     );
  //     $(input_field)
  //       .closest('form')
  //       .find('input[id$=given_name]')
  //       .first()
  //       .val(user.data('givenname'))
  //       .prop('readonly', true);
  //     $(input_field)
  //       .closest('form')
  //       .find('input[id$=family_name]')
  //       .first()
  //       .val(user.data('familyname'))
  //       .prop('readonly', true);
  //   } else {
  //     form.find('input[name="data_link[receiver][id]"]').remove();
  //     $(input_field).closest('form').find('input[id$=given_name]').first().prop('readonly', false);
  //     $(input_field).closest('form').find('input[id$=family_name]').first().prop('readonly', false);
  //   }
  // };

  // let search_history = function (input_field, list, data) {
  //   default_success(input_field, list, data);
  //   let form = $(input_field).closest('form');

  //   console.log('search_history');

  //   if (filter_ci(list, $(input_field).val()).length) {
  //     let option_id = filter_ci(list, $(input_field).val()).data('id');
  //     form.find('input[name="stored_filter[id]"]').remove();
  //     form.append('<input type="hidden" id="stored_filter_id" name="stored_filter[id]" value="' + option_id + '">');
  //     form.find('button[type="submit"]').text(form.find('button[type="submit"]').data('update'));
  //     form.off('submit', append_stored_filter_data);
  //     form.off('submit', show_confirmation).on('submit', show_confirmation);
  //   } else {
  //     form.find('input[name="stored_filter[id]"]').remove();
  //     form.find('button[type="submit"]').text(form.find('button[type="submit"]').data('save'));
  //     form.off('submit', show_confirmation);
  //     form.off('submit', append_stored_filter_data).on('submit', append_stored_filter_data);
  //   }
  // };

  // let filter_ci = function (list, value) {
  //   return $(list)
  //     .find('option')
  //     .filter((idx, elem) => $(elem).val().toLowerCase() == value.toLowerCase());
  // };

  // let show_confirmation = function (event) {
  //   event.preventDefault();
  //   new ConfirmationModal({
  //     text:
  //       'Filterparameter aktualisieren?<br /><br />Warnung: Beeinflusst auch gespeicherte Suchen, die diese Suche verwenden.',
  //     confirmationClass: 'success',
  //     cancelable: true,
  //     confirmationCallback: () => {
  //       append_stored_filter_data(event);
  //     },
  //     cancelCallback: () => {
  //       console.log('cancel datalist');
  //       Rails.enableElement(event.currentTarget);
  //     }
  //   });
  // };

  // let append_stored_filter_data = function (event) {
  //   event.preventDefault();

  //   let form = $('#search-form');
  //   $(form).prop('action', $(event.currentTarget).prop('action'));
  //   $(form).prop('method', $(event.currentTarget).prop('method'));
  //   $(form).append($(event.currentTarget).find('input[type=hidden]').clone());
  //   if ($(event.currentTarget).find('#stored_filter_name').length)
  //     $(form).append(
  //       '<input type="hidden" name="stored_filter[name]" value="' +
  //         $(event.currentTarget).find('#stored_filter_name').val() +
  //         '">'
  //     );
  //   if ($(event.currentTarget).find('#stored_filter_system').length)
  //     $(form).append(
  //       '<input type="hidden" name="stored_filter[system]" value="' +
  //         $(event.currentTarget).find('#stored_filter_system').is(':checked') +
  //         '">'
  //     );
  //   if ($(event.currentTarget).find('#add-items-to-watch-list-select').length)
  //     $(form).append(
  //       '<input type="hidden" name="watch_list_id" value="' +
  //         $(event.currentTarget).find('#add-items-to-watch-list-select').val() +
  //         '">'
  //     );
  //   form.submit();
  // };

  let init = (container = document) => {
    container.querySelectorAll('.ajax-datalist').forEach(item => {
      new DataList(item);
    });

    // $(container)
    //   .find('.ajax-datalist')
    //   .each((idx, element) => {
    //     new DataList(element);

    // $(list).html('');
    // let field_id = $(element).prop('id');
    // field_requests[field_id] = [];

    // $(element).on('input', event => {
    //   event.preventDefault();
    //   field_requests[field_id].forEach(request => {
    //     request.abort();
    //     field_requests[field_id] = field_requests[field_id].filter(r => r != request);
    //   });
    //   field_requests[field_id].push(
    //     $.get(
    //       DataCycle.engingePath + '/' + list_id + '/search',
    //       {
    //         q: $(event.currentTarget).val()
    //       },
    //       data => {
    //         if (eval('typeof ' + list_id + ' === "function"')) {
    //           eval(list_id)(element, list, data);
    //         } else default_success(element, list, data);
    //       }
    //     )
    //   );
    // });
    // });
  };

  init();

  // $('#add-items-to-watch-list-form').on('submit', append_stored_filter_data);

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();

    init(event.target);
  });
}

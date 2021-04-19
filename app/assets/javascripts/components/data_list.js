class DataList {
  constructor(element) {
    this.element = element;
    this.list = this.element.list;
    this.listId = this.element.getAttribute('list');
    this.fieldId = this.element.id;
    this.form = this.element.closest('form');
    this.requests = [];

    this.setup();
  }
  setup() {
    this.resetList();
    this.element.addEventListener('input', this.onInput.bind(this));
  }
  resetList() {
    this.list.innerHTML = '';
  }
  abortRunningRequests() {
    this.requests.forEach(request => {
      request.abort();
      _.pull(this.requests, request);
    });
  }
  callSuccessMethod(data) {
    this.resetList();

    if (typeof this[`${this.listId}_callback_method`] === 'function') {
      this[`${this.listId}_callback_method`](data);
    } else this.default_callback_method(data);
  }
  onInput(event) {
    event.preventDefault();

    this.abortRunningRequests();

    this.requests.push(
      DataCycle.httpRequest({
        type: 'GET',
        url: `${DataCycle.enginePath}/${this.listId}/search`,
        data: {
          q: this.element.value
        }
      }).done(this.callSuccessMethod.bind(this))
    );
  }
  default_callback_method(data) {
    data.forEach(element => {
      if (element && element.name && element.id)
        this.list.innerHTML += `<option data-id="${element.id}" value="${element.name}">`;
    });
  }
  users_callback_method(data) {
    data.forEach(element => {
      if (element && element.name && element.id)
        this.list.innerHTML += `<option data-familyname="${element.family_name}" data-givenname="${element.given_name}" data-id="${element.id}" value="${element.email}">`;
    });

    console.log('users');

    if (this.selectedOptions().length) {
      let user = filter_ci(list, $(input_field).val());
      form.find('input[name="data_link[receiver][id]"]').remove();
      form.append(
        '<input type="hidden" id="' +
          $(input_field).prop('id').replace('email', 'id') +
          '" name="data_link[receiver][id]" value="' +
          user.data('id') +
          '">'
      );
      $(input_field)
        .closest('form')
        .find('input[id$=given_name]')
        .first()
        .val(user.data('givenname'))
        .prop('readonly', true);
      $(input_field)
        .closest('form')
        .find('input[id$=family_name]')
        .first()
        .val(user.data('familyname'))
        .prop('readonly', true);
    } else {
      form.find('input[name="data_link[receiver][id]"]').remove();
      $(input_field).closest('form').find('input[id$=given_name]').first().prop('readonly', false);
      $(input_field).closest('form').find('input[id$=family_name]').first().prop('readonly', false);
    }
  }
  search_history_callback_method(data) {
    this.default_callback_method(data);

    console.log('search_history');

    if (this.selectedOptions().length) {
      let option_id = filter_ci(list, $(input_field).val()).data('id');
      form.find('input[name="stored_filter[id]"]').remove();
      form.append('<input type="hidden" id="stored_filter_id" name="stored_filter[id]" value="' + option_id + '">');
      form.find('button[type="submit"]').text(form.find('button[type="submit"]').data('update'));
      form.off('submit', append_stored_filter_data);
      form.off('submit', show_confirmation).on('submit', show_confirmation);
    } else {
      form.find('input[name="stored_filter[id]"]').remove();
      form.find('button[type="submit"]').text(form.find('button[type="submit"]').data('save'));
      form.off('submit', show_confirmation);
      form.off('submit', append_stored_filter_data).on('submit', append_stored_filter_data);
    }
  }
  selectedOptions() {
    console.log(this.list.children);
    return Array.from(this.list.children).filter(elem => {
      console.log(elem);
      return elem.value.toLowerCase() == this.element.value.toLowerCase();
    });

    // $(list)
    // .find('option')
    // .filter((idx, elem) => $(elem).val().toLowerCase() == value.toLowerCase());
  }
}

export default DataList;

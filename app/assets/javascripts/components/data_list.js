import ConfirmationModal from './confirmation_modal';

class DataList {
  constructor(element) {
    this.element = element;
    this.list = this.element.list;
    this.listId = this.element.getAttribute('list');
    this.fieldId = this.element.id;
    this.form = this.element.closest('form');
    this.searchForm = document.getElementById('search-form');
    this.collectionForm = document.getElementById('add-items-to-watch-list-form');
    this.requests = [];
    this.eventListeners = {
      onInput: this.onInput.bind(this),
      appendStoredFilterData: this.appendStoredFilterData.bind(this),
      showConfirmation: this.showConfirmation.bind(this)
    };

    this.setup();
  }
  setup() {
    this.resetList();

    this.element.addEventListener('input', this.eventListeners.onInput);
    if (this.collectionForm) this.collectionForm.addEventListener('submit', this.eventListeners.appendStoredFilterData);
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
        this.list.insertAdjacentHTML('beforeend', `<option data-id="${element.id}" value="${element.name}">`);
    });
  }
  users_callback_method(data) {
    data.forEach(element => {
      if (element && element.name && element.id)
        this.list.insertAdjacentHTML(
          'beforeend',
          `<option data-familyname="${element.family_name}" data-givenname="${element.given_name}" data-id="${element.id}" value="${element.email}">`
        );
    });

    console.log('users');

    if (this.selectedOption()) {
      let user = filter_ci(list, $(input_field).val());
      this.form.find('input[name="data_link[receiver][id]"]').remove();
      this.form.append(
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
      this.form.find('input[name="data_link[receiver][id]"]').remove();
      $(input_field).closest('form').find('input[id$=given_name]').first().prop('readonly', false);
      $(input_field).closest('form').find('input[id$=family_name]').first().prop('readonly', false);
    }
  }
  search_history_callback_method(data) {
    this.default_callback_method(data);

    const selectedOption = this.selectedOption();
    const submitButton = this.form.querySelector('button[type="submit"]');
    const storedFilterInput = this.form.querySelector('input[name="stored_filter[id]"]');

    if (selectedOption) {
      if (!storedFilterInput)
        this.form.insertAdjacentHTML(
          'beforeend',
          `<input type="hidden" id="stored_filter_id" name="stored_filter[id]" value="${selectedOption.dataset.id}">`
        );
      else storedFilterInput.value = selectedOption.dataset.id;

      submitButton.innerText = submitButton.dataset.update;
      this.form.removeEventListener('submit', this.eventListeners.appendStoredFilterData);
      this.form.removeEventListener('submit', this.eventListeners.showConfirmation);
      this.form.addEventListener('submit', this.eventListeners.showConfirmation);
    } else {
      if (storedFilterInput) storedFilterInput.remove();

      submitButton.innerText = submitButton.dataset.save;
      this.form.removeEventListener('submit', this.eventListeners.showConfirmation);
      this.form.removeEventListener('submit', this.eventListeners.appendStoredFilterData);
      this.form.addEventListener('submit', this.eventListeners.appendStoredFilterData);
    }
  }
  selectedOption() {
    return Array.from(this.list.children).find(elem => {
      return elem.value.toLowerCase() == this.element.value.toLowerCase();
    });
  }
  showConfirmation(event) {
    event.preventDefault();

    new ConfirmationModal({
      text:
        'Filterparameter aktualisieren?<br /><br />Warnung: Beeinflusst auch gespeicherte Suchen, die diese Suche verwenden.',
      confirmationClass: 'success',
      cancelable: true,
      confirmationCallback: this.eventListeners.appendStoredFilterData,
      cancelCallback: () => {
        Rails.enableElement(event.target);
      }
    });
  }
  appendStoredFilterData(event = null) {
    if (event) event.preventDefault();

    this.searchForm.setAttribute('action', this.form.getAttribute('action'));
    this.searchForm.setAttribute('method', this.form.getAttribute('method'));
    this.form.querySelectorAll('input[type="hidden"]').forEach(node => {
      this.searchForm.appendChild(node.cloneNode());
    });

    if (this.form.querySelector('#stored_filter_name'))
      this.searchForm.insertAdjacentHTML(
        'beforeend',
        `<input type="hidden" name="stored_filter[name]" value="${
          this.form.querySelector('#stored_filter_name').value
        }">`
      );

    if (this.form.querySelector('#stored_filter_system'))
      this.searchForm.insertAdjacentHTML(
        'beforeend',
        `<input type="hidden" name="stored_filter[system]" value="${
          this.form.querySelector('#stored_filter_system').checked
        }">`
      );

    if (this.form.querySelector('#add-items-to-watch-list-select'))
      this.searchForm.insertAdjacentHTML(
        'beforeend',
        `<input type="hidden" name="watch_list_id" value="${
          this.form.querySelector('#add-items-to-watch-list-select').value
        }">`
      );

    this.searchForm.submit();
  }
}

export default DataList;

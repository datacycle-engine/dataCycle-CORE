import ConfirmationModal from './confirmation_modal';
import pull from 'lodash/pull';

class DataList {
  constructor(element) {
    this.element = element;
    this.list = this.element.list;
    this.listId = this.element.getAttribute('list');
    this.fieldId = this.element.id;
    this.form = this.element.closest('form');
    this.searchForm = document.getElementById('search-form');
    this.collectionForm = document.getElementById('add-items-to-watch-list-form');
    this.activeRequest;
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
  callSuccessMethod(data) {
    this.resetList();

    if (typeof this[`${this.listId}_callback_method`] === 'function') {
      this[`${this.listId}_callback_method`](data);
    } else this.default_callback_method(data);
  }
  onInput(event) {
    event.preventDefault();

    const promise = DataCycle.httpRequest({
      type: 'GET',
      url: `/${this.listId}/search`,
      data: {
        q: this.element.value
      }
    });

    this.activeRequest = promise;

    promise.then(data => {
      if (this.activeRequest != promise) return;

      this.callSuccessMethod(data);
    });
  }
  default_callback_method(data) {
    data.forEach(element => {
      if (element && element.name && element.id)
        this.list.insertAdjacentHTML('beforeend', `<option data-id="${element.id}" value="${element.name}">`);
    });
  }
  users_callback_method(data) {
    data.forEach(element => {
      if (element && element.email && element.id)
        this.list.insertAdjacentHTML(
          'beforeend',
          `<option data-familyname="${element.family_name}" data-givenname="${element.given_name}" data-id="${element.id}" value="${element.email}">`
        );
    });

    const selectedOption = this.selectedOption();
    const userIdInput = this.form.querySelector('input[name="data_link[receiver][id]"]');
    const givenNameField = this.form.querySelector('input[id$=given_name]');
    const familyNameField = this.form.querySelector('input[id$=family_name]');

    if (selectedOption) {
      if (!userIdInput)
        this.form.insertAdjacentHTML(
          'beforeend',
          `<input type="hidden" id="${this.element.id.replace('email', 'id')}" name="data_link[receiver][id]" value="${
            selectedOption.dataset.id
          }">`
        );
      else userIdInput.value = selectedOption.dataset.id;

      if (givenNameField) {
        givenNameField.setAttribute('readonly', true);
        givenNameField.value = selectedOption.dataset.givenname;
      }
      if (familyNameField) {
        familyNameField.setAttribute('readonly', true);
        familyNameField.value = selectedOption.dataset.familyname;
      }
    } else {
      if (userIdInput) userIdInput.remove();
      if (givenNameField) {
        givenNameField.removeAttribute('readonly');
        givenNameField.value = '';
      }
      if (familyNameField) {
        familyNameField.removeAttribute('readonly');
        familyNameField.value = '';
      }
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
  async showConfirmation(event) {
    event.preventDefault();

    new ConfirmationModal({
      text: await I18n.translate('frontend.update_stored_filter'),
      confirmationClass: 'success',
      cancelable: true,
      confirmationCallback: () => {
        this.eventListeners.appendStoredFilterData(event);
      },
      cancelCallback: () => {
        DataCycle.enableElement(event.target);
      }
    });
  }
  appendStoredFilterData(event) {
    event.preventDefault();

    this.searchForm.setAttribute('action', event.target.getAttribute('action'));
    this.searchForm.setAttribute('method', event.target.getAttribute('method'));
    event.target.querySelectorAll(':scope input[type="hidden"]').forEach(node => {
      this.searchForm.appendChild(node.cloneNode());
    });

    if (event.target.querySelector('#stored_filter_name'))
      this.searchForm.insertAdjacentHTML(
        'beforeend',
        `<input type="hidden" name="stored_filter[name]" value="${
          event.target.querySelector('#stored_filter_name').value
        }">`
      );

    if (event.target.querySelector('#stored_filter_system'))
      this.searchForm.insertAdjacentHTML(
        'beforeend',
        `<input type="hidden" name="stored_filter[system]" value="${
          event.target.querySelector('#stored_filter_system').checked
        }">`
      );

    if (event.target.querySelector('#add-items-to-watch-list-select'))
      this.searchForm.insertAdjacentHTML(
        'beforeend',
        `<input type="hidden" name="watch_list_id" value="${
          event.target.querySelector('#add-items-to-watch-list-select').value
        }">`
      );

    this.searchForm.submit();
  }
}

export default DataList;

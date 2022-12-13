import debounce from 'lodash/debounce';
import ObserverHelpers from '../helpers/observer_helpers';

class StoredSearchesFilter {
  constructor(inputField) {
    this.inputField = inputField;
    this.inputField.classList.add('dcjs-stored-searches-filter');
    this.url = this.inputField.dataset.url;
    this.dropdownTrigger = this.inputField.closest('.search-favorites-short');
    this.dropdownList = this.inputField.closest('ul');
    this.listContainer = this.dropdownList.querySelector('.search-favorites-list');
    this.changeObserver = new MutationObserver(this._checkForVisibility.bind(this));
    this.currentRequest;

    this.setup();
  }
  setup() {
    this.inputField.addEventListener('keydown', this.preventEnterSubmit.bind(this));
    this.inputField.addEventListener('change', this.preventDefault.bind(this));
    this.inputField.addEventListener('input', debounce(this.filterStoredSearches.bind(this), 300));
    this.changeObserver.observe(this.dropdownTrigger, ObserverHelpers.changedClassConfig);

    this.focusInputField();
  }
  filterStoredSearches(event) {
    event.preventDefault();
    event.stopImmediatePropagation();

    this.listContainer.classList.add('list-loading');

    const promise = DataCycle.httpRequest({
      url: this.url,
      data: {
        q: this.inputField.value,
        partial: 'saved_searches_dropdown_list'
      },
      dataType: 'json',
      contentType: 'application/json'
    });

    this.currentRequest = promise;

    promise
      .then(data => {
        if (this.currentRequest == promise) this.listContainer.innerHTML = data.html;
      })
      .finally(() => {
        if (this.currentRequest == promise) this.listContainer.classList.remove('list-loading');
      });
  }
  _checkForVisibility(mutations) {
    for (const mutation of mutations) {
      if (mutation.type !== 'attributes') continue;

      if (mutation.target.classList.contains('active') && (!mutation.oldValue || !mutation.oldValue.includes('active')))
        this.focusInputField();
    }
  }
  focusInputField(_event = null) {
    this.inputField.focus();
    this.inputField.select();
  }
  preventEnterSubmit(event) {
    if (event.keyCode === 13) this.preventDefault(event);
  }
  preventDefault(event) {
    event.preventDefault();
    event.stopImmediatePropagation();
  }
}

export default StoredSearchesFilter;

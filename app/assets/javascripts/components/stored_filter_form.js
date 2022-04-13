import loadingIcon from '../templates/loadingIcon';

class StoredFilterForm {
  constructor(form) {
    this.form = form;
    this.idSelector = this.form.querySelector('.update-search-id-selector');

    this.setup();
  }
  setup() {
    $(this.idSelector).on('change', this.reloadFormData.bind(this));
  }
  reloadFormData(event) {
    event.preventDefault();
    event.stopPropagation();

    console.log('change', event.target.value);
  }
}

export default StoredFilterForm;

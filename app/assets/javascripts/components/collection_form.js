class CollectionForm {
  constructor(form) {
    this.form = form;
    this.formSubmit = this.form.querySelector('.buttons [type="submit"]');
    this.searchFormPart = this.form.querySelector('.search-form-data');
    this.searchForm = document.getElementById('search-form');

    this.setup();
  }
  setup() {
    this.form.classList.add('dcjs-collection-form');

    if (this.searchFormPart && this.searchForm)
      this.form.addEventListener('submit', this.injectSearchFormData.bind(this));
  }
  injectSearchFormData(event) {
    event.preventDefault();
    event.stopPropagation();

    DataCycle.disableElement(this.formSubmit);

    const formData = new FormData(this.searchForm);
    this.searchFormPart.innerHTML = '';

    let formDataHtml = '';
    for (const [name, value] of Array.from(formData))
      formDataHtml += `<input type="hidden" name="${name}" value="${value}">`;

    this.searchFormPart.insertAdjacentHTML('beforeend', formDataHtml);

    this.form.submit();
  }
}

export default CollectionForm;

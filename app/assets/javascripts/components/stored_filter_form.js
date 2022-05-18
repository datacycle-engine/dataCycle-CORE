class StoredFilterForm {
  constructor(form) {
    this.form = form;
    this.idSelector = this.form.querySelector('.update-search-id-selector');
    this.formSubmit = this.form.querySelector('.buttons [type="submit"]');
    this.dynamicFormPart = this.form.querySelector('.dynamic-form-parts');
    this.searchFormPart = this.form.querySelector('.search-form-data');
    this.searchForm = document.getElementById('search-form');

    this.setup();
  }
  setup() {
    $(this.idSelector).on('change', this.reloadFormData.bind(this));
    if (this.searchFormPart && this.searchForm)
      this.form.addEventListener('submit', this.injectSearchFormData.bind(this));
  }
  reloadFormData(_event) {
    DataCycle.disableElement(this.formSubmit, this.formSubmit.innerHTML);
    this.idSelector.disabled = true;
    this.dynamicFormPart.classList.add('dynamic-parts-loading');
    this.dynamicFormPart.classList.remove('dc-fd-initialized');

    DataCycle.httpRequest({
      url: '/search_history/render_update_form',
      data: {
        stored_filter: {
          id: this.idSelector.value
        }
      },
      dataType: 'json',
      contentType: 'application/json'
    })
      .then(data => {
        this.dynamicFormPart.innerHTML = $(data.html).find('.dynamic-form-parts').html();

        $(this.dynamicFormPart).trigger('dc:html:changed').trigger('dc:html:initialized');
      })
      .finally(() => {
        this.idSelector.disabled = false;
        this.dynamicFormPart.classList.remove('dynamic-parts-loading');
        DataCycle.enableElement(this.formSubmit);
      });
  }
  injectSearchFormData(event) {
    event.preventDefault();
    event.stopPropagation();

    DataCycle.disableElement(this.formSubmit);

    const formData = new FormData(this.searchForm);
    this.searchFormPart.innerHTML = '';

    let formDataHtml = '';
    for (const [name, value] of formData) formDataHtml += `<input type="hidden" name="${name}" value="${value}">`;

    this.searchFormPart.insertAdjacentHTML('beforeend', formDataHtml);

    this.form.submit();
  }
}

export default StoredFilterForm;

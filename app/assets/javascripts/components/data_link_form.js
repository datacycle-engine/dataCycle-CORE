class DataLinkForm {
  constructor(form) {
    this.form = form;
    this.idSelector = this.form.querySelector('.data-link-receiver-selector');
    this.formSubmit = this.form.querySelectorAll('.buttons [type="submit"]');
    this.dynamicFormPart = this.form.querySelector('.dynamic-form-parts');

    this.setup();
  }
  setup() {
    $(this.idSelector).on('change', this.reloadFormData.bind(this));
  }
  reloadFormData(_event) {
    for (const submit of this.formSubmit) DataCycle.disableElement(submit, submit.innerHTML);

    this.idSelector.disabled = true;
    this.dynamicFormPart.classList.add('dynamic-parts-loading');
    this.dynamicFormPart.classList.remove('dc-fd-initialized');

    DataCycle.httpRequest({
      url: '/data_links/render_update_form',
      data: {
        data_link: {
          receiver: {
            id: this.idSelector.value
          }
        }
      },
      dataType: 'json',
      contentType: 'application/json'
    })
      .then(data => {
        this.dynamicFormPart.innerHTML = $(data.html).find('.dynamic-form-parts').addBack('.dynamic-form-parts').html();
      })
      .finally(() => {
        this.idSelector.disabled = false;
        this.dynamicFormPart.classList.remove('dynamic-parts-loading');
        for (const submit of this.formSubmit) DataCycle.enableElement(submit);
      });
  }
}

export default DataLinkForm;

import QuillHelpers from '../../helpers/quill_helpers';
import DomElementHelpers from '../../helpers/dom_element_helpers';

class ClassificationEditForm {
  constructor(item) {
    this.item = item;
    this.dcClassificationEditForm = true;
    this.liElement = this.item.closest('li');
    this.container = document.getElementById('classification-administration');
    this.submitButton = this.item.querySelector('.submit-button');

    this.setup();
  }
  setup() {
    this.item.addEventListener('submit', this.submitForm.bind(this));
    this.item.addEventListener('reset', this.resetForm.bind(this));
    for (const link of this.item.querySelectorAll('.ca-translation-link'))
      link.addEventListener('click', this.changeLocale.bind(this));
  }
  changeLocale(event) {
    event.preventDefault();
    event.stopPropagation();

    const currentTarget = event.currentTarget;
    const locale = currentTarget.dataset.locale;

    this.item.querySelector('.list-items a.active').classList.remove('active');
    this.item.querySelector(`.list-items [data-locale="${locale}"]`).classList.add('active');
    for (const input of this.item.querySelectorAll('.ca-input > .active')) input.classList.remove('active');
    for (const input of this.item.querySelectorAll(`.ca-input > .${locale}`)) input.classList.add('active');
  }
  resetForm(_event) {
    this.liElement.classList.remove('active');
  }
  submitForm(event) {
    event.preventDefault();
    event.stopPropagation();

    DataCycle.disableElement(this.item);
    QuillHelpers.updateEditors(this.item);

    const formData = DomElementHelpers.getFormData(this.item);

    const promise = DataCycle.httpRequest({
      type: formData.get('_method') || 'POST',
      url: this.item.action,
      data: formData,
      enctype: 'multipart/form-data',
      dataType: 'json',
      processData: false,
      contentType: false,
      cache: false
    });

    promise
      .then(data => {
        if (data && data.html) this.liElement.insertAdjacentHTML('afterend', data.html);

        this.liElement.remove();

        for (const li of this.container.querySelectorAll('li.active')) li.classList.remove('active');
      })
      .finally(() => {
        DataCycle.enableElement(this.item);
      });
  }
}

export default ClassificationEditForm;

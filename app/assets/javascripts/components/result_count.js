import DomElementHelper from '../helpers/dom_element_helpers';

class ResultCount {
  constructor(element) {
    this.countContainer = element;
    this.form = document.getElementById('search-form');
    this.url = this.form && this.form.action;
    this.additionalFormParams = DomElementHelper.parseDataAttribute(
      this.countContainer.dataset.additionalFormParameters
    );

    this.loadCount();
  }
  loadCount() {
    if (!this.form || !this.url) return;

    const formData = new FormData(this.form);
    formData.set('count_only', true);

    for (const [key, value] of Object.entries(this.additionalFormParams)) formData.set(key, value);

    this.countContainer.classList.add('loading');

    DataCycle.httpRequest({
      url: this.url,
      method: 'POST',
      data: formData,
      processData: false,
      contentType: false,
      dataType: 'json'
    })
      .then(data => {
        this.countContainer.innerHTML = data.html;
        this.countContainer.classList.remove('loading');
      })
      .catch(() => {
        console.warn('could not load count');
      });
  }
}

export default ResultCount;

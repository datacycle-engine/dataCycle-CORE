import DomElementHelper from '../helpers/dom_element_helpers';

class QualityScore {
  constructor(element) {
    element.dcQualityScore = true;
    this.element = element;
    this.qualityScoreText = this.element.querySelector('.quality-score-text');
    this.container = this.element.closest('.dc-quality-score');
    this.contentId = this.element.dataset.qualityScoreContentId;
    this.template = this.element.dataset.qualityScoreTemplate;
    this.attributeKey = this.element.dataset.key;
    this.element.qualityScore = this;
    this.locale = this.element.dataset.locale;

    this.setup();
  }
  setup() {
    $(this.container).on('change', this.loadScore.bind(this));
  }
  loadScore() {
    this.element.classList.add('score-loading');
    this.qualityScoreText.innerHTML = '-';
    const formData = DomElementHelper.getFormData(this.container);
    const url = '/things/quality_score';

    if (this.template) formData.set('template_name', this.template);
    if (this.attributeKey) formData.set('attribute_key', this.attributeKey);
    if (this.contentId) formData.set('id', this.contentId);
    if (this.locale) formData.set('locale', this.locale);

    DataCycle.httpRequest({
      type: 'POST',
      url: url,
      enctype: 'multipart/form-data',
      data: formData,
      dataType: 'json',
      processData: false,
      contentType: false,
      cache: false
    })
      .then(data => {
        if (!data || !data.hasOwnProperty('value')) return;

        const score = Math.round(data.value * 100);

        if (data && data.hasOwnProperty('value')) this.qualityScoreText.innerHTML = score;

        this.container.classList.remove('medium-score', 'high-score');
        if (score > 66) this.container.classList.add('high-score');
        else if (score > 33) this.container.classList.add('medium-score');
      })
      .catch(_e => {
        this.container.classList.remove('medium-score', 'high-score');
        this.qualityScoreText.innerHTML = '-';
      })
      .finally(() => {
        this.element.classList.remove('score-loading');
      });
  }
}

export default QualityScore;

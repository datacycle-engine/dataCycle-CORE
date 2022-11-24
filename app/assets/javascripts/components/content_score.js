import DomElementHelper from '../helpers/dom_element_helpers';

class ContentScore {
  constructor(element) {
    element.dcContentScore = true;
    this.element = element;
    this.contentScoreText = this.element.querySelector('.content-score-text');
    this.container = this.element.closest(
      '.form-element, .detail-type, #edit-form, .detail-header, .content-object-item'
    );
    this.contentId = this.element.dataset.contentScoreContentId;
    this.contentEmbedded = DomElementHelper.parseDataAttribute(this.element.dataset.contentScoreEmbedded);
    this.template = this.element.dataset.contentScoreTemplate;
    this.attributeKey = this.element.dataset.key;
    this.element.contentScore = this;
    this.locale = this.element.dataset.locale;

    this.setup();
  }
  setup() {
    if (this.container) this.container.classList.add('dc-content-score');
    $(this.container).on('change', this.loadScore.bind(this)); // not yet working with native 'change' event
  }
  loadScore() {
    if (!this.container) return;

    this.element.classList.add('score-loading');
    this.contentScoreText.innerHTML = '-';

    const formData = DomElementHelper.getFormData(this.container, 'thing[', this.contentEmbedded);
    const url = '/things/content_score';

    if (this.template) formData.set('template_name', this.template);
    if (this.attributeKey) formData.set('attribute_key', this.attributeKey);
    if (this.contentId) formData.set('id', this.contentId);
    if (this.locale) formData.set('locale', this.locale);

    DataCycle.httpRequest({
      method: 'POST',
      url: url,
      enctype: 'multipart/form-data',
      data: formData,
      dataType: 'json',
      processData: false,
      contentType: false,
      cache: false
    })
      .then(this.setNewScore.bind(this))
      .catch(_e => {
        this.container.classList.remove('medium-score', 'high-score');
        this.contentScoreText.innerHTML = '';
      })
      .finally(() => {
        this.element.classList.remove('score-loading');
      });
  }
  setNewScore(data) {
    if (!data || !data.hasOwnProperty('value')) return;

    const score = Math.round(data.value * 100);

    if (data && data.hasOwnProperty('value')) this.contentScoreText.innerHTML = score;

    this.container.classList.remove('medium-score', 'high-score');
    this.element.classList.remove('medium-score', 'high-score');

    if (score > 66) {
      this.container.classList.add('high-score');
      this.element.classList.add('high-score');
    } else if (score > 33) {
      this.container.classList.add('medium-score');
      this.element.classList.add('medium-score');
    }
  }
}

export default ContentScore;

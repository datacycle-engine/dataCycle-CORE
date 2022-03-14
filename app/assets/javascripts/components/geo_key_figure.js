class GeoKeyFigure {
  constructor(element) {
    this.$element = $(element);
    this.url = this.$element.prop('href');
    this.$formElement = this.$element.closest('.form-element');
    this.$triggerAllButton = this.$element.closest('.content-object-item').find('.geo-key-figure-button-all');
    this.key = this.$element.data('key');
    this.fullKey = this.$element.data('fullKey');
    this.local = this.$element.data('local');
    this.partIdPath = this.$element.data('partIdPath');
    this.label = this.$formElement.data('label');
    this.locale = this.$formElement.closest('form').find(':hidden[name="locale"]').val() || '';

    this.setup();
  }
  setup() {
    if (!this.partIdPath || !this.key) {
      console.warn('GeoKeyFigure: missing parameter');
      return;
    }

    this.$element.on('click', this._computeKeyFigure.bind(this));
    this.$triggerAllButton.on('click', this._computeKeyFigure.bind(this));
  }
  partSelectorString() {
    return (this.partSelector = '.form-element' + this.partIdPath.map(v => '[data-key*="[' + v + ']"]').join(''));
  }
  getValues() {
    return $(this.partSelectorString())
      .find(':input')
      .serializeArray()
      .map(v => v && v.value);
  }
  _computeKeyFigure(event) {
    event.preventDefault();
    event.stopPropagation();

    if (this.$element.hasClass('disabled')) return;

    DataCycle.disableElement(this.$element);

    if (this.local) {
      this._computeByLocal();
    } else {
      this.sendRequest();
    }
  }
  async _computeByLocal() {
    await $(this.partSelectorString())
      .find(DataCycle.config.EditorSelectors.join(', '))
      .triggerHandler('dc:geoKeyFigure:compute', {
        attributeKey: this.key,
        callback: this.setNewValue.bind(this)
      });

    DataCycle.enableElement(this.$element);
  }
  sendRequest() {
    const ids = this.getValues();

    if (!ids || !ids.length) return DataCycle.enableElement(this.$element);

    const fullUrl = `${this.url}?key=${this.key}&${ids.map(v => 'part_ids[]=' + v).join('&')}`;

    DataCycle.httpRequest({ url: fullUrl })
      .then(data => {
        if (data) this.setNewValue(data.newValue);
      })
      .finally(() => {
        DataCycle.enableElement(this.$element);
      });
  }
  setNewValue(value) {
    if (!value && value !== false) return;

    this.$formElement.find(DataCycle.config.EditorSelectors.join(', ')).trigger('dc:import:data', {
      value: value,
      locale: this.locale
    });
  }
}

export default GeoKeyFigure;

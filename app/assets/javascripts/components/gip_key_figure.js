class GipKeyFigure {
  constructor(element) {
    this.$element = $(element);
    this.url = this.$element.prop('href');
    this.$formElement = this.$element.closest('.form-element');
    this.key = this.$element.data('key');
    this.partIdPath = this.$element.data('partIdPath');
    this.label = this.$formElement.data('label');
    this.locale = this.$formElement.closest('form').find(':hidden[name="locale"]').val() || '';

    this.setup();
  }
  setup() {
    if (!this.partIdPath || !this.key) {
      console.warn('GipKeyFigure: missing parameter');
      return;
    }

    this.$element.on('click', this.sendRequest.bind(this));
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
  sendRequest(event) {
    event.preventDefault();
    event.stopPropagation();

    Rails.disableElement(this.$element.get(0));

    const ids = this.getValues();

    if (ids && ids.length) {
      const fullUrl = `${this.url}?key=${this.key}&${ids.map(v => 'part_ids[]=' + v)}`;

      DataCycle.httpRequest(fullUrl)
        .then(data => {
          if (data && data.newValue) this.setNewValue(data.newValue);
        })
        .then(this.reEnableButon.bind(this), this.reEnableButon.bind(this));
    }
  }
  reEnableButon() {
    Rails.enableElement(this.$element.get(0));
  }
  setNewValue(value) {
    this.$formElement.find(DataCycle.editorSelectors.join(', ')).trigger('dc:import:data', {
      label: this.label,
      value: value,
      locale: this.locale
    });
  }
}

export default GipKeyFigure;

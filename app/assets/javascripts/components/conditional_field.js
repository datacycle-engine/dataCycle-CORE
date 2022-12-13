class ConditionalField {
  constructor(element) {
    this.$element = $(element);
    this.$options = this.$element.find('.conditional-field-selector > label > :radio');
    this.$content = this.$element.find('.conditional-field-content');

    this.setup();
  }
  setup() {
    this.$element[0].classList.add('dcjs-conditional-field');
    this.$options.on('click', this.toggleVisibleFields.bind(this));
    this.$element.on('dc:conditionalField:refresh', this.setVisibility.bind(this));
  }
  toggleVisibleFields(event) {
    event.stopPropagation();

    this.$content.removeClass('active').find(':input').prop('disabled', true);

    this.$element
      .find('.conditional-' + $(event.currentTarget).val() + '-content')
      .addClass('active')
      .find(':input')
      .prop('disabled', false);
  }
  setVisibility(event, data) {
    event.preventDefault();
    event.stopPropagation();

    const visibilityClass = data && data.value ? 'true' : 'false';
    this.$options.filter(`[value="${visibilityClass}"]`).click();
  }
}

export default ConditionalField;

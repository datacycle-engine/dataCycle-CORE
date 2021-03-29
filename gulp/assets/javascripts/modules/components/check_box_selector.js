class CheckBoxSelector {
  constructor(element) {
    this.$element = $(element);
    this.$inputFields = this.$element.find('> li > :checkbox');
  }
  init() {
    this.initEventHandlers();
  }
  initEventHandlers() {
    this.$element.closest('.form-element').on('dc:field:reset', this.reset.bind(this));
    this.$element.on('dc:import:data', this.import.bind(this));
  }
  reset(_event) {
    this.$inputFields.each((_, item) => $(item).prop('checked', false));
    this.$element.closest('.form-element').children(':hidden').remove();
  }
  import(_event, data) {
    if (!data.value || !data.value.length) return;

    this.$inputFields.each((_, item) => {
      this.setInputValue(item, data.value);
    });
  }
  setInputValue(item, value) {
    $(item).prop('checked', value !== undefined && value.includes($(item).val()));
  }
}

module.exports = CheckBoxSelector;

import domElementHelpers from '../helpers/dom_element_helpers';

class CheckBoxSelector {
  constructor(element) {
    this.$element = $(element);
    this.$inputFields = this.$element.find('> li > :checkbox');
    this.htmlClass = 'dc-check-box-selector';
  }
  init() {
    this.$element.addClass(this.htmlClass);
    this.initEventHandlers();
  }
  initEventHandlers() {
    this.$element.closest('.form-element').on('dc:field:reset', this.reset.bind(this));
    this.$element.on('dc:import:data', this.import.bind(this)).addClass('dc-import-data');
  }
  reset(_event) {
    this.$inputFields.each((_, item) => $(item).prop('checked', false));
    this.$element.closest('.form-element').children(':hidden').remove();
  }
  async import(event, data) {
    if (!data.value || !data.value.length) return;

    const target = event.currentTarget;

    if (data.force) this.setAllValues(data.value);
    else {
      domElementHelpers.renderImportConfirmationModal(target, data.sourceId, () => {
        this.setAllValues(data.value);
      });
    }
  }
  setAllValues(value) {
    this.$inputFields.each((_, item) => {
      this.setInputValue(item, value);
    });
  }
  setInputValue(item, value) {
    $(item).prop('checked', value !== undefined && value.includes($(item).val()));
  }
}

export default CheckBoxSelector;

import ConfirmationModal from './confirmation_modal';

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
  async import(event, data) {
    if (!data.value || !data.value.length) return;

    const label = event.currentTarget.closest('.form-element').getElementsByClassName('attribute-label-text')[0];
    const labelText = label && label.innerText;

    new ConfirmationModal({
      text: await I18n.translate('frontend.override_warning', { data: labelText }),
      confirmationText: await I18n.translate('common.yes'),
      cancelText: await I18n.translate('common.no'),
      confirmationClass: 'success',
      cancelable: true,
      confirmationCallback: () => {
        this.$inputFields.each((_, item) => {
          this.setInputValue(item, data.value);
        });
      }
    });
  }
  setInputValue(item, value) {
    $(item).prop('checked', value !== undefined && value.includes($(item).val()));
  }
}

export default CheckBoxSelector;

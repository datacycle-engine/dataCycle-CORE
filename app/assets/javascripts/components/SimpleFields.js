import ConfirmationModal from './confirmation_modal';

class SimpleFields {
  constructor(container) {
    this.container = container;

    this.setup();
  }
  setup() {
    this.addEventHandlers('string', '.form-element.string:not(.text_editor) > input[type="text"]');
    this.addEventHandlers('number', '.form-element.number > input[type="number"]');
    this.addEventHandlers('checkbox', '.form-element.boolean input[type="checkbox"]');

    this.watchForNewField(
      'string',
      e =>
        e.classList.contains('form-element') && e.classList.contains('string') && !e.classList.contains('text_editor'),
      '> input[type="text"]'
    );
    this.watchForNewField(
      'number',
      e => e.classList.contains('form-element') && e.classList.contains('number'),
      '> input[type="number"]'
    );
    this.watchForNewField(
      'checkbox',
      e => e.classList.contains('form-element') && e.classList.contains('boolean'),
      'input[type="checkbox"]'
    );
  }
  watchForNewField(type, condition, subSelect) {
    DataCycle.newContent.callbacks.push([
      e => condition(e),
      e => $(e).find(subSelect).on('dc:import:data', this[`${type}EventHandler`].bind(this))
    ]);
  }
  addEventHandlers(type, selector) {
    const elements = this.container.querySelectorAll(selector);

    console.log('addEventHandlers', selector, elements);

    for (let i = 0; i < elements.length; ++i) {
      $(elements[i]).on('dc:import:data', this[`${type}EventHandler`].bind(this));
    }
  }
  async stringEventHandler(event, data) {
    if ($(event.target).val().length === 0 || (data && data.force)) {
      $(event.target).val(data.value).trigger('input');
    } else {
      const label = event.currentTarget.closest('.form-element').getElementsByClassName('attribute-label-text')[0];
      const labelText = label && label.innerText;

      new ConfirmationModal({
        text: await I18n.translate('frontend.override_warning', { data: labelText }),
        confirmationText: await I18n.translate('common.yes'),
        cancelText: await I18n.translate('common.no'),
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: function () {
          $(event.target).val(data.value).trigger('input');
        }
      });
    }
  }
  async numberEventHandler(event, data) {
    if ($(event.target).val().length === 0 || (data && data.force)) {
      $(event.target).val(data.value).trigger('input');
    } else {
      const label = event.currentTarget.closest('.form-element').getElementsByClassName('attribute-label-text')[0];
      const labelText = label && label.innerText;

      new ConfirmationModal({
        text: await I18n.translate('frontend.override_warning', { data: labelText }),
        confirmationText: await I18n.translate('common.yes'),
        cancelText: await I18n.translate('common.no'),
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: function () {
          $(event.target).val(data.value).trigger('input');
        }
      });
    }
  }
  async checkboxEventHandler(event, data) {
    if (data && data.force) {
      $(event.target).prop('checked', data.value);
    } else {
      const label = event.currentTarget.closest('.form-element').getElementsByClassName('attribute-label-text')[0];
      const labelText = label && label.innerText;

      new ConfirmationModal({
        text: await I18n.translate('frontend.override_warning', { data: labelText }),
        confirmationText: await I18n.translate('common.yes'),
        cancelText: await I18n.translate('common.no'),
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: function () {
          $(event.target).prop('checked', data.value);
        }
      });
    }
  }
}

export default SimpleFields;

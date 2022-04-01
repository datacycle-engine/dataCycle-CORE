import domElementHelpers from '../helpers/dom_element_helpers';

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
    DataCycle.htmlObserver.addCallbacks.push([
      e => condition(e),
      e => $(e).find(subSelect).on('dc:import:data', this[`${type}EventHandler`].bind(this)).addClass('dc-import-data')
    ]);
  }
  addEventHandlers(type, selector) {
    const elements = this.container.querySelectorAll(selector);

    for (let i = 0; i < elements.length; ++i) {
      $(elements[i]).on('dc:import:data', this[`${type}EventHandler`].bind(this)).addClass('dc-import-data');
    }
  }
  stringEventHandler(event, data) {
    const target = event.currentTarget;

    if ($(target).val().length === 0 || (data && data.force)) {
      $(target).val(data.value).trigger('input');
    } else {
      domElementHelpers.renderImportConfirmationModal(target, data.sourceId, () => {
        $(target).val(data.value).trigger('input');
      });
    }
  }
  async numberEventHandler(event, data) {
    const target = event.currentTarget;

    if ($(target).val().length === 0 || (data && data.force)) {
      $(target).val(data.value).trigger('input');
    } else {
      domElementHelpers.renderImportConfirmationModal(target, data.sourceId, () => {
        $(target).val(data.value).trigger('input');
      });
    }
  }
  async checkboxEventHandler(event, data) {
    const target = event.currentTarget;

    if (data && data.force) {
      $(target).prop('checked', data.value.toString() == target.value);
    } else {
      domElementHelpers.renderImportConfirmationModal(target, data.sourceId, () => {
        $(target).prop('checked', data.value.toString() == target.value);
      });
    }
  }
}

export default SimpleFields;

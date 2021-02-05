const Validator = require('./validator');

class BulkUpdateValidator extends Validator {
  constructor(formElement) {
    super(formElement);

    this.uuid = this.form.find(':hidden#uuid').val();

    this.setup();
  }
  setup() {
    this.initActionCable();
    this.form.on('click', '.bulk-update-type :checkbox:checked', this.deselectSiblings.bind(this));
    this.form.on('change', '.editor > .form-element', this.checkBulkUpdateType.bind(this));
  }
  initActionCable() {
    window.actionCable.subscriptions.create(
      {
        channel: 'DataCycleCore::WatchListBulkUpdateChannel',
        watch_list_id: this.uuid
      },
      {
        received: data => {
          if (!this.submitButton.prop('disabled')) this.disable();
          if (data.progress !== undefined) {
            let progress = Math.round((data.progress * 100) / data.items);
            this.submitButton.find('.progress-value').text(progress + '%');
            this.submitButton.find('.progress-bar > .progress-filled').css('width', 'calc(' + progress + '% - 1rem)');
          }
          if (data.redirect_path !== undefined) {
            window.location.href = data.redirect_path;
          }
        }
      }
    );
  }
  checkBulkUpdateType(event) {
    const bulkUpdateTypes = this.bulkUpdateTypes(event.currentTarget);

    if (
      $(event.currentTarget)
        .find(':input')
        .serializeArray()
        .some(elem => elem.value && elem.value.length)
    ) {
      if (!bulkUpdateTypes.filter(':checked').length)
        bulkUpdateTypes.filter('[value="override"]').prop('checked', true);
    } else bulkUpdateTypes.prop('checked', false);
  }
  bulkUpdateTypes(item) {
    return $(item)
      .siblings('.bulk-update-type[data-attribute-key="' + $(item).data('key') + '"]')
      .find(':checkbox');
  }
  deselectSiblings(event) {
    $(event.currentTarget).siblings(':checkbox').prop('checked', false);
  }
  validateItem(validationContainer) {
    if (
      !$(validationContainer).hasClass('agbs') &&
      !this.bulkUpdateTypes(validationContainer).filter(':checked').length
    )
      return;

    super.validateItem(validationContainer);
  }
}

module.exports = BulkUpdateValidator;

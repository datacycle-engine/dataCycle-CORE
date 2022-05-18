import Validator from './validator';

class BulkUpdateValidator extends Validator {
  constructor(formElement) {
    super(formElement);

    this.uuid = this.$form.find(':hidden#uuid').val();

    this.setup();
  }
  setup() {
    this.initActionCable();
    this.$form.on('click', '.bulk-update-type :checkbox:checked', this.deselectSiblings.bind(this));
    this.$form.on('change', '.bulk-update-type :checkbox', this.changeActiveClass.bind(this));
    this.$form.on(
      'change',
      '.editor > .form-element, .editor > .translatable-attribute-container > .translatable-attribute > .form-element',
      this.checkBulkUpdateType.bind(this)
    );
  }
  initActionCable() {
    window.actionCable.subscriptions.create(
      {
        channel: 'DataCycleCore::WatchListBulkUpdateChannel',
        watch_list_id: this.uuid
      },
      {
        received: data => {
          if (!this.$submitButton.prop('disabled')) this.disable();
          if (data.progress !== undefined) {
            let progress = Math.round((data.progress * 100) / data.items);
            this.$submitButton.find('.progress-value').text(progress + '%');
            this.$submitButton.find('.progress-bar > .progress-filled').css('width', 'calc(' + progress + '% - 1rem)');
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
        bulkUpdateTypes.filter('[value="override"]').prop('checked', true).change();
    } else bulkUpdateTypes.prop('checked', false).change();
  }
  bulkUpdateTypes(item) {
    return $(item)
      .siblings(`.bulk-update-type[data-attribute-key="${$(item).data('key')}"]`)
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
      return Promise.resolve({ valid: true });

    return super.validateItem(validationContainer);
  }
  changeActiveClass(event) {
    const currentFormElement = event.currentTarget.parentNode.nextElementSibling;
    currentFormElement.classList.remove('bulk-edit-add', 'bulk-edit-remove', 'bulk-edit-override');

    if (event.currentTarget.checked) {
      currentFormElement.classList.add(`bulk-edit-${event.currentTarget.value}`);
    }
  }
}

export default BulkUpdateValidator;

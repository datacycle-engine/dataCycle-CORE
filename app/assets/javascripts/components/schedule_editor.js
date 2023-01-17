class ScheduleEditor {
  constructor(editor) {
    this.editor = editor;
    this.editor.addClass('dcjs-schedule-editor');
    this.minInput = this.editor.find('.daterange .form-element.start input.flatpickr-input[type="hidden"]');
    this.maxInput = this.editor.find('.rrules .form-element.until input.flatpickr-input[type="hidden"]');

    this.init();
  }
  init() {
    this.editor.find('.rrule-type-selector').on('change', this.updateVisibleRrules.bind(this));
    this.editor.find('.fullday input[type="checkbox"]').on('change', this.updateDateTimeEditors.bind(this));
    this.minInput.on('change', this.updateUntilEditor.bind(this));
    this.minInput.on('change', this.updateSpecialDateEditors.bind(this));
    this.maxInput.on('change', this.updateSpecialDateEditors.bind(this));
  }
  updateVisibleRrules(event) {
    let selectedOption = $(event.currentTarget).find('option:selected');
    this.editor
      .find('.rrules')
      .removeClass('single_occurrence daily weekly monthly yearly')
      .addClass(selectedOption.data('type'));
  }
  updateDateTimeEditors(event) {
    event.preventDefault();

    this.editor
      .find('.form-element.start .flatpickr-input[type="text"], .form-element.end .flatpickr-input[type="text"]')
      .trigger('dc:flatpickr:reInit', { enableTime: !$(event.currentTarget).prop('checked') });
  }
  updateUntilEditor(event) {
    this.maxInput.get(0)._flatpickr.set('minDate', $(event.currentTarget).val());
  }
  updateSpecialDateEditors(event) {
    event.preventDefault();

    let mode = $(event.currentTarget).closest('.form-element').hasClass('start') ? 'minDate' : 'maxDate';

    this.editor
      .find(
        '.special-dates .rdate .flatpickr-input[type="hidden"], .special-dates .exdate .flatpickr-input[type="hidden"]'
      )
      .each((_i, item) => {
        item._flatpickr.set(mode, $(event.currentTarget).val());
      });
  }
}

export default ScheduleEditor;

class ScheduleEditor {
  constructor(editor) {
    this.editor = editor;

    this.init();
  }
  init() {
    this.editor.find('.rrule-type-selector').on('change', this.updateVisibleRrules.bind(this));
    this.editor.find('.fullday input[type="checkbox"]').on('change', this.updateDateTimeEditors.bind(this));
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
      .find('.form-element.start .flatpickr-input, .form-element.end .flatpickr-input')
      .trigger('dc:date:destroy');

    this.editor
      .find('.schedule-range')
      .trigger('dc:date:initialize', { enableTime: !$(event.currentTarget).prop('checked') });
  }
}

module.exports = ScheduleEditor;

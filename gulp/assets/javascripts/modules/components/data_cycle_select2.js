class DataCycleSelect2 {
  constructor(element) {
    this.$element = $(element);
    this.query = {};
    this.endpoint = this.$element.data('endpoint');
    this.config = element.dataset;
    this.defaultoptions = {
      allowClear: true,
      minimumInputLength: 2,
      width: '100%',
      dropdownParent: this.$element.parent()
    };
    this.select2Object = null;

    this.setup();
  }
  setup() {
    this.initSelect2();
    this.initEventHandlers();
  }
  initSelect2() {
    this.select2Object = this.$element.select2(this.defaultoptions);
  }
  initEventHandlers() {
    this.$element.closest('form').on('reset', this.reset);
    this.$element.on('dc:import:data', this.import);
  }
  reset(_event) {
    this.$element.val(null).trigger('change', { type: 'reset' });
  }
  import(event, data) {}
}

module.exports = AjaxQueue;

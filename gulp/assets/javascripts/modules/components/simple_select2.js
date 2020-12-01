var BasicSelect2 = require('./basic_select2');

class SimpleSelect2 extends BasicSelect2 {
  constructor(element) {
    super(element);

    this.defaultOptions = Object.assign(this.defaultOptions, {
      width: '100%'
    });
  }
  initSelect2() {
    this.select2Object = this.$element.select2(this.defaultoptions);
  }
  import(event, data) {}
}

module.exports = SimpleSelect2;

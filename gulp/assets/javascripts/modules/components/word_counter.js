// Word Counter Module
class Counter {
  constructor(selector = '') {
    this.parent_elem = $(selector);
    this.container;
    this.wrapper_elem = this.parent_elem.closest('.form-element').first();
    this.validations = this.parent_elem.data('validations');
    this.warnings = this.parent_elem.data('warnings');
  }
  start() {
    this.setContainer();
    var text = this.getText();
    if (text.length == 0) $(this.container).hide();
    this.addEventHandlers();
    this.update();
  }
  setContainer() {
    if (this.parent_elem.parent().find('.counter').length == 0) this.wrapper_elem.append('<div class="counter"></div>');
    this.container = this.wrapper_elem.find('.counter')[0];
  }
  addEventHandlers() {
    this.parent_elem.closest('form').on('reset', this.resetCounter.bind(this));
    this.parent_elem.on('input', this.update.bind(this));
  }
  resetCounter() {
    this.parent_elem.val('');
    this.update();
  }
  getText() {
    return this.parent_elem.val();
  }
  countWords(text) {
    return text.trim().replace(/\n/g, '').length > 0
      ? text
          .trim()
          .replace(/\n/g, '')
          .split(/\s+/).length
      : 0;
  }
  countChars(text) {
    return text.trim().replace(/\n/g, '').length > 0 ? text.trim().replace(/\n/g, '').length : 0;
  }
  calculate() {
    var text = this.getText();
    var length = this.countChars(text);
    if (this.warnings !== undefined && this.warnings.max !== undefined && length > 0 && length > this.warnings.max)
      $(this.container).addClass('warning');
    else if (this.warnings !== undefined && this.warnings.min && length > 0 && length < this.warnings.min)
      $(this.container).addClass('warning');
    else $(this.container).removeClass('warning');
    return {
      words: this.countWords(text),
      chars: this.countChars(text)
    };
  }
  update() {
    var length = this.calculate();
    var chars = length.chars;
    var words = length.words;
    var char_label = 'Zeichen';
    var word_label = words == 1 ? 'Wort' : 'Wörter';
    if (chars == 0) $(this.container).fadeOut('fast');
    else $(this.container).fadeIn('fast');
    var counter_string = words + ' ' + word_label + ' / ' + chars + ' ' + char_label;
    if (this.warnings !== undefined && this.warnings.max !== undefined && chars > 0 && chars > this.warnings.max) {
      var rest = this.warnings.max - chars;
      counter_string += ' (noch max. ' + (rest > 0 ? rest : 0) + ' ' + char_label + ')';
    } else if (
      this.warnings !== undefined &&
      this.warnings.min !== undefined &&
      chars > 0 &&
      chars < this.warnings.min
    ) {
      var rest = this.warnings.min - chars;
      counter_string += ' (noch min. ' + (rest > 0 ? rest : 0) + ' ' + char_label + ')';
    }
    $(this.container).html(counter_string);
  }
}

module.exports = Counter;

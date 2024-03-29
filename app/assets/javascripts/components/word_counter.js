class Counter {
  constructor(selector) {
    selector.classList.add('dcjs-counter');
    this.parentElem = $(selector);
    this.container;
    this.wrapperElem = this.parentElem.closest('.form-element').first();
    this.validations = this.parentElem.data('validations');
    this.warnings = this.parentElem.data('warnings');
  }
  start() {
    this.setContainer();
    var text = this.getText();
    if (text.length == 0) $(this.container).hide();
    this.addEventHandlers();
    this.update();
  }
  setContainer() {
    if (this.parentElem.parent().find('.counter').length == 0) this.wrapperElem.append('<div class="counter"></div>');
    this.container = this.wrapperElem.find('.counter')[0];
  }
  addEventHandlers() {
    this.parentElem.closest('form').on('reset', this.resetCounter.bind(this));
    this.parentElem.on('input', this.update.bind(this));
  }
  resetCounter() {
    this.parentElem.val('');
    this.update();
  }
  getText() {
    return this.parentElem.val();
  }
  countWords(text) {
    return text.trim().replace(/\n/g, '').length > 0 ? text.trim().replace(/\n/g, '').split(/\s+/).length : 0;
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
  async update() {
    var length = this.calculate();
    var chars = length.chars;
    var words = length.words;
    var charLabel =
      chars == 1
        ? await I18n.translate('frontend.word_counter.chars.one')
        : await I18n.translate('frontend.word_counter.chars.other');
    var wordLabel =
      words == 1
        ? await I18n.translate('frontend.word_counter.word.one')
        : await I18n.translate('frontend.word_counter.word.other');
    if (chars == 0) $(this.container).fadeOut('fast');
    else $(this.container).fadeIn('fast');
    var counterString = `${words} ${wordLabel} / ${chars} ${charLabel}`;
    if (this.warnings !== undefined && this.warnings.max !== undefined && chars > 0 && chars > this.warnings.max) {
      var rest = this.warnings.max - chars;
      counterString += ` ${await I18n.translate('frontend.word_counter.max', {
        data: rest > 0 ? rest : 0,
        label: charLabel
      })}`;
    } else if (
      this.warnings !== undefined &&
      this.warnings.min !== undefined &&
      chars > 0 &&
      chars < this.warnings.min
    ) {
      var rest = this.warnings.min - chars;
      counterString += ` ${await I18n.translate('frontend.word_counter.min', {
        data: rest > 0 ? rest : 0,
        label: charLabel
      })}`;
    }

    $(this.container).html(counterString);
  }
}

export default Counter;

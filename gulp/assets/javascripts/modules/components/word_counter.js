// Word Counter Module
var Counter = function (selector = '') {
  this.parent_elem = $(selector);
  this.wrapper_elem = this.parent_elem.closest('.form-element').first();

  this.container = this.setContainer();
  this.min = this.parent_elem.data('minlength');
  this.max = this.parent_elem.data('maxlength');
  this.setup();
  this.update();
};

Counter.prototype.setup = function () {
  var text = this.getText();
  if (text.length == 0) $(this.container).hide();
  this.addEventHandlers();
};

Counter.prototype.setContainer = function () {
  if (this.parent_elem.parent().find('.counter').length == 0) this.wrapper_elem.append('<div class="counter"></div>');
  return this.wrapper_elem.find('.counter')[0];
};

Counter.prototype.addEventHandlers = function () {
  this.parent_elem.on('input', this.update.bind(this));
};

Counter.prototype.getText = function () {
  return this.parent_elem.val();
};

Counter.prototype.countWords = function (text) {
  return text.trim().replace(/\n/g, '').length > 0 ? text.trim().replace(/\n/g, '').split(/\s+/).length : 0;
};

Counter.prototype.countChars = function (text) {
  return text.trim().replace(/\n/g, '').length > 0 ? text.trim().replace(/\n/g, '').length : 0;
};

Counter.prototype.calculate = function () {
  var text = this.getText();
  var length = this.countChars(text);

  if (this.max !== undefined && length > this.max) $(this.container).addClass('error');
  else if (this.min !== undefined && length < this.min) $(this.container).addClass('error');
  else $(this.container).removeClass('error');

  return {
    words: this.countWords(text),
    chars: this.countChars(text)
  };
};

Counter.prototype.update = function () {
  var length = this.calculate();
  var chars = length.chars;
  var words = length.words;
  var char_label = "Zeichen";
  var word_label = words == 1 ? "Wort" : "Wörter";

  if (chars == 0) $(this.container).fadeOut('fast');
  else $(this.container).fadeIn('fast');

  var counter_string = words + ' ' + word_label + ' / ' + chars + ' ' + char_label;
  if (this.max !== undefined && chars > this.max) {
    var rest = this.max - chars;
    counter_string += ' (noch max. ' + (rest > 0 ? rest : 0) + ' ' + char_label + ')';
  } else if (this.min !== undefined && chars < this.min) {
    var rest = this.min - chars;
    counter_string += ' (noch min. ' + (rest > 0 ? rest : 0) + ' ' + char_label + ')';
  }

  $(this.container).html(counter_string);
};
module.exports = Counter;

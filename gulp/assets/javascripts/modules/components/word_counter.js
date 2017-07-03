// Word Counter Module
var Counter = function ($selector) {
  this.$parent = $selector;
  this.$wrapper = this.$parent.closest('.form-element').first();
  this.$container = this.setContainer();
  this.$parent.on('input', this.update.bind(this));
  this.update();
};

Counter.prototype.setContainer = function () {
  if (this.$parent.find('.counter').length == 0) this.$wrapper.append('<div class="counter"></div>');
  return this.$wrapper.find('.counter')[0];
};
Counter.prototype.countWords = function (text) {
  return text.trim().length > 0 ? text.trim().split(/\s+/).length : 0;
};
Counter.prototype.countChars = function (text) {
  return text.length > 0 ? text.length : 0;
};

Counter.prototype.calculate = function () {
  var text = this.$parent.val();

  return {
    words: this.countWords(text),
    chars: this.countChars(text)
  };
};

Counter.prototype.update = function () {
  if (!$(this.$container).is(":visible")) $(this.$container).fadeIn('fast');

  var length = this.calculate();
  var chars = length.chars;
  var words = length.words;
  var char_label = "Zeichen";
  var word_label = words == 1 ? "Wort" : "Wörter";

  if (length.chars == 0) $(this.$container).fadeOut('fast');

  $(this.$container).html(words + ' ' + word_label + ' / ' + chars + ' ' + char_label);
};
module.exports = Counter;
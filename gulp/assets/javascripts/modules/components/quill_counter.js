// QuillJS Word Counter Module
var Counter = function (quill, options) {
  this.quill = quill;
  this.options = options;
  this.limit = parseInt(this.options.limit) || 0;
  this.unit = this.options.unit || "zeichen";
  this.container = this.setContainer();
  quill.on('text-change', this.update.bind(this));
  this.setup();
  this.update();
};

Counter.prototype.setContainer = function () {
  var parentElement = this.quill.container.parentElement;
  if (parentElement.querySelector('#counter') == null) parentElement.insertAdjacentHTML('beforeend', '<div id="counter"></div>');
  return parentElement.querySelector('#counter');
};
Counter.prototype.setup = function () {
  var text = this.quill.getText();
  if (text.length == 0) $(this.container).hide();
};
Counter.prototype.countWords = function (text) {
  return text.trim().length > 0 ? text.trim().split(/\s+/).length : 0;
};
Counter.prototype.countChars = function (text) {
  return text.length - 1 > 0 ? text.length - 1 : 0;
};

Counter.prototype.calculate = function () {
  var text = this.quill.getText();
  var length, length_words, length_chars = 0;

  if (this.options.unit === "wörter") length = this.countWords(text);
  else if (this.options.unit === "zeichen") length = this.countChars(text);

  if (this.limit > 0 && length > this.limit) this.quill.deleteText(this.quill.getLength() - 2, 1);

  text = this.quill.getText();

  return {
    words: this.countWords(text),
    chars: this.countChars(text)
  };
};

Counter.prototype.update = function () {
  var length = this.calculate();
  var chars = length.chars;
  var words = length.words;
  var limit_label = this.options.unit;
  if (this.options.unit === "wörter") limit_label = this.limit == 1 ? "Wort" : "Wörter";
  else if (this.options.unit === "zeichen") limit_label = "Zeichen";
  var char_label = "Zeichen";
  var word_label = words == 1 ? "Wort" : "Wörter";

  if (length.chars == 0) $(this.container).fadeOut('fast');
  else $(this.container).fadeIn('fast');

  this.container.innerHTML = words + ' ' + word_label + ' / ' + chars + ' ' + char_label;
};
module.exports = Counter;
// QuillJS Word Counter Module
var Counter = function (quill, options) {
  this.quill = quill;
  this.options = options;
  this.max = parseInt(this.options.max) || 0;
  this.unit = this.options.unit || "zeichen";
  this.container = this.setContainer();
  quill.on('text-change', this.update.bind(this));
  this.setup();
  this.update();
};

Counter.prototype.setContainer = function () {
  var parentElement = this.quill.container.parentElement;
  if (parentElement.querySelector('.counter') == null) parentElement.insertAdjacentHTML('beforeend', '<div class="counter"></div>');
  return parentElement.querySelector('.counter');
};
Counter.prototype.setup = function () {
  var text = this.quill.getText();
  if (text.length == 0) $(this.container).hide();
};
Counter.prototype.countWords = function (text) {
  return text.trim().replace(/\n/g, '').length > 0 ? text.trim().replace(/\n/g, '').split(/\s+/).length : 0;
};
Counter.prototype.countChars = function (text) {
  return text.trim().replace(/\n/g, '').length > 0 ? text.trim().replace(/\n/g, '').length : 0;
};

Counter.prototype.calculate = function () {
  var text = this.quill.getText();
  var length, length_words, length_chars = 0;

  if (this.options.unit === "wörter") length = this.countWords(text);
  else if (this.options.unit === "zeichen") length = this.countChars(text);

  if (this.max > 0 && length > this.max) $(this.container).addClass('max-reached');
  // this.quill.deleteText(this.quill.getLength() - 2, 1);
  // } else if (this.max > 0 && length == this.max) $(this.container).addClass('max-reached');
  else $(this.container).removeClass('max-reached');

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
  var char_label = "Zeichen";
  var word_label = words == 1 ? "Wort" : "Wörter";

  if (length.chars == 0) $(this.container).fadeOut('fast');
  else $(this.container).fadeIn('fast');

  var counter_string = words + ' ' + word_label + ' / ' + chars + ' ' + char_label;
  if (this.max !== 0) {
    var rest = this.max - chars;
    counter_string += ' (noch max. ' + (rest > 0 ? rest : 0) + ' ' + char_label + ')';
  }

  this.container.innerHTML = counter_string;
};
module.exports = Counter;

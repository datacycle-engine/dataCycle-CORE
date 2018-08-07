var Counter = require('./word_counter');

// QuillJS Word Counter Module
var QuillCounter = function (quill, options) {
  this.quill = quill;
  this.options = options;

  Counter.call(this, quill.container);
};

QuillCounter.prototype = Object.create(Counter.prototype);
QuillCounter.prototype.constructor = QuillCounter;

QuillCounter.prototype.addEventHandlers = function () {
  this.quill.on('text-change', this.update.bind(this));
};

QuillCounter.prototype.getText = function () {
  return this.quill.getText();
};

QuillCounter.prototype.setContainer = function () {
  var parentElement = this.quill.container.parentElement;
  if (parentElement.querySelector('.counter') == null) parentElement.insertAdjacentHTML('beforeend', '<div class="counter"></div>');
  return parentElement.querySelector('.counter');
};

module.exports = QuillCounter;

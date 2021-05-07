import Counter from './word_counter';

class QuillCounter extends Counter {
  constructor(quill, _options) {
    super(quill.container);
    this.quill = quill;

    this.start();
  }
  addEventHandlers() {
    this.quill.on('text-change', this.update.bind(this));
  }
  getText() {
    return this.quill.getText();
  }
  setContainer() {
    let parentElement = this.quill.container.parentElement;
    if (parentElement.querySelector('.counter') == null)
      parentElement.insertAdjacentHTML('beforeend', '<div class="counter"></div>');
    this.container = parentElement.querySelector('.counter');
  }
}

export default QuillCounter;

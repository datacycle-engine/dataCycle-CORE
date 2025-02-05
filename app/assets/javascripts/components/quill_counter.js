import Counter from "./word_counter";

class QuillCounter extends Counter {
	constructor(quill, _options) {
		super(quill.container);
		this.quill = quill;
		this.wrapperElem = this.quill.container.parentElement;

		this.start();
	}
	addEventHandlers() {
		this.quill.on("text-change", this.update.bind(this));
	}
	getText() {
		return this.quill.getText();
	}
}

export default QuillCounter;

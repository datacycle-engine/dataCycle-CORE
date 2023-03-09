const QuillHelpers = {
	updateEditors(container = document, triggerChangeEvent = false) {
		if (container instanceof $) container = container[0];
		if (!container) return;

		const editors = Array.from(container.querySelectorAll(".quill-editor"));
		if (container.matches(".quill-editor")) editors.push(container);

		for (const editor of editors) {
			const hiddenField = document.getElementById(editor.dataset.hiddenFieldId);
			const textField = editor.querySelector(".ql-editor");

			if (!(hiddenField && textField)) continue;

			const text = this.normalizeText(textField.innerHTML);

			if (text !== hiddenField.value) {
				hiddenField.value = text;
				if (triggerChangeEvent) $(hiddenField).trigger("change");
			}
		}
	},
	normalizeText(text) {
		let normalizedText = text
			.replaceAll(/(<p>\s*(<br>)*\s*<\/p>)*$/gi, "")
			.replaceAll(/^(<p>\s*(<br>)*\s*<\/p>)*/gi, "")
			.replaceAll(/(\s*&nbsp;\s*)+/gi, "&nbsp;");

		if (normalizedText !== text) return this.normalizeText(normalizedText);

		return normalizedText;
	},
};

Object.freeze(QuillHelpers);

export default QuillHelpers;

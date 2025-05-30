const QuillHelpers = {
	updateEditors(container = document, triggerChangeEvent = false) {
		let newContainer = container;
		if (newContainer instanceof $) newContainer = newContainer[0];
		if (!newContainer) return;

		const editors = Array.from(newContainer.querySelectorAll(".quill-editor"));
		if (newContainer.matches(".quill-editor")) editors.push(newContainer);

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
		const normalizedText = text
			.replaceAll(/(<p>\s*(<br>)*\s*<\/p>)*$/gi, "")
			.replaceAll(/^(<p>\s*(<br>)*\s*<\/p>)*/gi, "")
			.replaceAll(/(\s*&nbsp;\s*)+/gi, "&nbsp;")
			.replaceAll(/\s?dcjs-\w*/gi, "") // Remove classes starting with "dcjs-"
			.replaceAll(/\s?data-dc-tooltip-id="\w*"/gi, ""); // Remove data-dc-tooltip-id

		console.log("normalizeText", text, text, normalizedText);

		if (normalizedText !== text) return this.normalizeText(normalizedText);

		return normalizedText;
	},
};

Object.freeze(QuillHelpers);

export default QuillHelpers;

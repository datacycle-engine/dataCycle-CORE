// import TextEditor from '../components/text_editor';
const TextEditorLoader = () => import("../components/text_editor");

import AiLector from "../components/ai_lector/ai_lector";
import InlineTranslator from "../components/inline_translator";

function initTextEditor(item) {
	TextEditorLoader()
		.then((mod) => new mod.default(item))
		.catch((e) => console.error("Error loading module:", e));
}

export default function () {
	DataCycle.registerAddCallback(
		".quill-editor:not(.ql-container)",
		"text-editor",
		initTextEditor.bind(this),
	);

	DataCycle.registerAddCallback(
		".translate-inline-button",
		"inline-translator",
		(e) => new InlineTranslator(e),
	);

	DataCycle.registerAddCallback(".ai-lector-dropdown", "ai-lector", () => {
		if (!DataCycle.globals.aiLector)
			DataCycle.globals.aiLector = new AiLector();
	});
}

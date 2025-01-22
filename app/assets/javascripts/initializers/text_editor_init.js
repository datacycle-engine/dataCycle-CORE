// import TextEditor from '../components/text_editor';
const TextEditorLoader = () => import("../components/text_editor");
import InlineTranslator from "../components/inline_translator";
import TextEnhanceTips from "../components/ai_lector/ai_lector_tips";

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

	DataCycle.registerAddCallback(
		".ai-lector-tips-button",
		"ai-lector-tips",
		(e) => new TextEnhanceTips(e),
	);
}

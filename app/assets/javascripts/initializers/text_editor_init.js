// import TextEditor from '../components/text_editor';
const TextEditorLoader = () => import('../components/text_editor');
import InlineTranslator from '../components/inline_translator';

function initTextEditor(item) {
  item.classList.add('dcjs-text-editor');
  TextEditorLoader()
    .then(mod => new mod.default(item))
    .catch(e => console.error('Error loading module:', e));
}

export default function () {
  DataCycle.initNewElements('.quill-editor:not(.ql-container):not(.dcjs-text-editor)', initTextEditor.bind(this));

  DataCycle.initNewElements('.translate-inline-button:not(.dcjs-inline-translator)', e => new InlineTranslator(e));
}

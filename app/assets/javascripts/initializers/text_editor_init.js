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
  for (const element of document.querySelectorAll('.quill-editor:not(.ql-container)')) initTextEditor(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e =>
      e.classList.contains('quill-editor') &&
      !e.classList.contains('ql-container') &&
      !e.classList.contains('dcjs-text-editor'),
    e => initTextEditor(e)
  ]);

  for (const element of document.querySelectorAll('.translate-inline-button')) new InlineTranslator(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('translate-inline-button') && !e.classList.contains('dcjs-inline-translator'),
    e => new InlineTranslator(e)
  ]);
}

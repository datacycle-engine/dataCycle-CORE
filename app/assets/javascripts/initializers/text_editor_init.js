import TextEditor from '../components/text_editor';
import InlineTranslator from '../components/inline_translator';

export default function () {
  const textEditors = [];

  for (const element of document.querySelectorAll('.quill-editor:not(.ql-container)'))
    textEditors.push(new TextEditor(element));

  DataCycle.htmlObserver.addCallbacks.push([
    e =>
      e.classList.contains('quill-editor') &&
      !e.classList.contains('ql-container') &&
      !e.hasOwnProperty('dcTextEditor'),
    e => textEditors.push(new TextEditor(e))
  ]);

  for (const element of document.querySelectorAll('.translate-inline-button'))
    textEditors.push(new InlineTranslator(element));

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('translate-inline-button') && !e.hasOwnProperty('dcInlineTranslator'),
    e => textEditors.push(new InlineTranslator(e))
  ]);
}

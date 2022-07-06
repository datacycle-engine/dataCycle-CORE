import TextEditor from '../components/text_editor';

export default function () {
  const textEditors = [];

  for (const element of document.querySelectorAll('.quill-editor:not(.ql-container)'))
    textEditors.push(new TextEditor(element));

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('quill-editor') && !e.classList.contains('ql-container'),
    e => textEditors.push(new TextEditor(e))
  ]);
}

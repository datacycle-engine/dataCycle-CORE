import TextEditor from '../components/text_editor';

export default function () {
  const textEditors = [];

  function init(container = document) {
    $(container)
      .find('.quill-editor')
      .each(async (_, node) => {
        textEditors.push(new TextEditor(node));
      });
  }

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    init(event.target);
  });

  init();
}

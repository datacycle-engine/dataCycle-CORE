import ImageEditor from '../components/image_editor';

export default function () {
  init();

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();

    init(event.currentTarget);
  });

  function init(element = document) {
    $(element)
      .find('.image-editor-reveal')
      .each((_, elem) => {
        new ImageEditor(elem);
      });
  }
}

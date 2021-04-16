import GipKeyFigure from '../components/gip_key_figure';

export default function () {
  init();

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();

    init(event.currentTarget);
  });

  function init(element = document) {
    $(element)
      .find('.gip-key-figure-button')
      .each((_, elem) => {
        new GipKeyFigure(elem);
      });
  }
}

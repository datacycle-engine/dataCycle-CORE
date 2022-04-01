import GeoKeyFigure from '../components/geo_key_figure';

export default function () {
  init();

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();

    init(event.currentTarget);
  });

  function init(element = document) {
    $(element)
      .find('.geo-key-figure-button')
      .each((_, elem) => {
        new GeoKeyFigure(elem);
      });
  }
}

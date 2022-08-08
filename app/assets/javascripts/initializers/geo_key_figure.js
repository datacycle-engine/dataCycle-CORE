import GeoKeyFigure from '../components/geo_key_figure';

export default function () {
  for (const element of document.querySelectorAll('.geo-key-figure-button')) new GeoKeyFigure(element);

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('geo-key-figure-button'),
    e => new GeoKeyFigure(e)
  ]);
}

import GeoKeyFigure from '../components/geo_key_figure';

export default function () {
  DataCycle.initNewElements('.geo-key-figure-button:not(.dcjs-geo-key-figure)', e => new GeoKeyFigure(e));
}

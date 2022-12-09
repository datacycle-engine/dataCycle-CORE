import TourSprungEditor from './../components/tour_sprung_editor';
import MapLibreGlViewer from './../components/maplibre_gl_viewer';
import MapLibreGlEditor from './../components/maplibre_gl_editor';
import MapLibreGlDashboard from './../components/maplibre_gl_dashboard';

const mapEditors = {
  TourSprung: TourSprungEditor,
  MapLibreGl: MapLibreGlEditor
};

export default function () {
  for (const element of document.querySelectorAll('.geographic-map')) initMap(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('geographic-map') && !e.classList.contains('dcjs-map'),
    e => initMap(e)
  ]);
}

function initMap(item) {
  item.classList.add('dcjs-map');
  if ($(item).hasClass('editor')) {
    const editor = $(item).data('map-options').editor;

    if (mapEditors.hasOwnProperty(editor) && mapEditors[editor].isAllowedType($(item).data('type')))
      return new mapEditors[editor](item).setup();
    else return new MapLibreGlEditor(item).setup();
  } else if ($(item).hasClass('dashboard')) {
    return new MapLibreGlDashboard(item).setup();
  } else {
    return new MapLibreGlViewer(item).setup();
  }
}

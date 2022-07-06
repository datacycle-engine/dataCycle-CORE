import OpenLayersViewer from './../components/open_layers_viewer';
import OpenLayersEditor from './../components/open_layers_editor';
import TourSprungEditor from './../components/tour_sprung_editor';

const mapEditors = {
  OpenLayers: OpenLayersEditor,
  TourSprung: TourSprungEditor
};

export default function () {
  for (const element of document.querySelectorAll('.geographic-map')) initMap(element);
  DataCycle.htmlObserver.addCallbacks.push([e => e.classList.contains('geographic-map'), e => initMap(e)]);
}

function initMap(item) {
  if ($(item).hasClass('editor')) {
    const editor = $(item).data('map-options').editor;

    if (mapEditors.hasOwnProperty(editor) && mapEditors[editor].isAllowedType($(item).data('type')))
      return new mapEditors[editor](item).setup();
    else return new OpenLayersEditor(item).setup();
  } else {
    return new OpenLayersViewer(item).setup();
  }
}

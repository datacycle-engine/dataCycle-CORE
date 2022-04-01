import OpenLayersViewer from './../components/open_layers_viewer';
import OpenLayersEditor from './../components/open_layers_editor';
import TourSprungEditor from './../components/tour_sprung_editor';

const mapEditors = {
  OpenLayers: OpenLayersEditor,
  TourSprung: TourSprungEditor
};

export default function () {
  if ($('.geographic-map').length) {
    $('.geographic-map').each((_, item) => {
      initMap(item);
    });
  }
  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    $(event.target)
      .find('.geographic-map')
      .each((_, item) => {
        initMap(item);
      });
  });
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

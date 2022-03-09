import pick from 'lodash/pick';
import isEmpty from 'lodash/isEmpty';

import maplibregl from 'maplibre-gl/dist/maplibre-gl';

class MapLibreGlEditor {
  constructor(container) {
    console.log('constructor');

    // this.additionalValuesOverlay = this.$container.data('additionalValuesOverlay');

    // this.wktFormat = new this.ol.format.WKT();// TODO:
  }
  configureMap() {
    this.configureEditor();
    // this.setZoomMethod();
    // this.setIcons();

    // this.drawFeatures();
    // this.drawAdditionalFeatures();
    // this.initEventHandlers();
    // this._disableScrollingOnMapOverlays();
    // this.initMouseWheelZoom();
    // this.updateMapPosition();
  }

  configureEditor() {
    this.map.addControl(new maplibregl.NavigationControl(), 'top-left');
    this.map.addControl(new maplibregl.FullscreenControl(), 'top-right');
    if (!isEmpty(this.additionalValuesOverlay))
      this.map.gl.addControl(new AdditionalValuesFilterControl(this), 'bottom-left');

    // this.extendEditorInterface();

    // this.editorGui = new this.extendedEditorInterface().addTo(this.map);

    // const waypointLayerDefinition = this.editorGui.editor.getLayerDefinitions().find(v => v.type == 'symbol');
    // const waypointLayerId = waypointLayerDefinition && waypointLayerDefinition.id;
    // if (waypointLayerId)
    //   this.map.gl.setLayoutProperty(waypointLayerId, 'icon-size', [
    //     'case',
    //     ['==', ['get', 'icon'], 'end'],
    //     0.8,
    //     ['==', ['get', 'icon'], 'start'],
    //     0.6,
    //     0
    //   ]);

    // this.editorGui.editor.outline.width = 0;
    // Object.assign(this.editorGui.editor.line, this.lineStyle());
    // Object.assign(this.editorGui.editor.dashedLine, this.lineStyle());
  }
}

export default MapLibreGlEditor;

// import pick from 'lodash/pick';
import isEmpty from 'lodash/isEmpty';
import MapLibreGlViewer from './maplibre_gl_viewer';

import maplibregl from 'maplibre-gl/dist/maplibre-gl';
import MapboxDraw from '@mapbox/mapbox-gl-draw';
import AdditionalValuesFilterControl from './map_controls/mapbox_additional_values_filter_control';
import UploadGpxControl from './map_controls/maplibre_upload_gpx_control';

class MapLibreGlEditor extends MapLibreGlViewer {
  constructor(container) {
    super(container);

    this.uploadable = this.$container.data('allowUpload');
    this.translateInteraction;
    this.modifyInteraction;
    this.drawableInteraction;
    this.drawing = false;
    this.draw;
    this.precision = 5;
    this.$geoCodeButton = $('.geocode-address-button').first();
    this.$mapEditContainer = this.$parentContainer.siblings('.map-edit').first();
    this.$mapInfoContainer = this.$parentContainer.siblings('.map-info').first();
    this.$uploadButton = this.$mapEditContainer.children('.upload-gpx-button').first();
    this.$uploadInput = this.$mapEditContainer.children('.upload-gpx-input').first();
    this.$latitudeField = this.$mapInfoContainer.find('.latitude input').first();
    this.$longitudeField = this.$mapInfoContainer.find('.longitude input').first();
    this.$elevationField = this.$mapInfoContainer.find('.elevation input').first();
    this.$locationField = this.$parentContainer.siblings('input.location-data:hidden').first();

    // this.additionalValuesOverlay = this.$container.data('additionalValuesOverlay');

    // this.wktFormat = new this.ol.format.WKT();// TODO:
  }
  static isAllowedType(type) {
    return true;
  }
  configureMap() {
    super.configureMap();
    this.configureEditor();

    // this.initAdditionalControls();
    // this.initMapActions();
    // if (this.uploadable) this.initUploadActions();
  }
  initFeatures() {
    if (!this.feature && this.value) this.feature = this.value;
    this.drawAdditionalFeatures();
  }

  configureEditor() {
    this.initAdditionalControls();

    if (this.feature) this.initEditFeature();
    // if (!isEmpty(this.additionalValuesOverlay))
    //   this.map.addControl(new AdditionalValuesFilterControl(this), 'bottom-left'); // TODO: locally override called methods if neccessary
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
  // initEventHandlers() {
  //   //TODO: check toursprung-editor for different handlers
  //   this.$container.on('dc:import:data', this.importData.bind(this)).addClass('dc-import-data');
  // }

  initAdditionalControls() {
    this.initDrawControl();
    if (this.uploadable) this.map.addControl(new UploadGpxControl(this), 'top-left');
  }
  initDrawControl() {
    this.draw = new MapboxDraw({
      displayControlsDefault: false,
      controls: {
        trash: true
      },
      defaultMode: this.getMapDrawMode(),
      styles: this.getMapDrawStyle()
    });
    this.map.addControl(this.draw);

    this.map.on('draw.create', event => {
      this.feature = event.features[0];
      // this.setCoordinates(); // TODO: for points
      this.setHiddenFieldValue(this.feature);
      // this.initGeometryEditActions(); // TODO: do we need this for point?
    });

    // TODO:
    this.map.on('draw.delete', event => {
      this.removeFeature();
    });

    // TODO:
    this.map.on('draw.update', event => {
      this.feature = event.features[0];
      // this.setCoordinates(); // TODO: for points
      this.setHiddenFieldValue(this.feature);
      // this.initGeometryEditActions(); // TODO: do we need this for point?
    });
  }
  getMapDrawMode() {
    // TODO: if already then select mode
    if (this.feature) {
      return 'simple_select';
    }
    return this.isPoint() ? 'draw_point' : 'draw_line_string';
  }
  getMapDrawStyle() {
    return this.isPoint() ? this._getDrawPointStyle() : this._getDrawLineStyle();
  }
  initEditFeature() {
    const featureIds = this.draw.add(this.feature);
    this.draw.changeMode('direct_select', { featureId: featureIds[0] });
  }
  // async importData(event, data) {
  //   if (!this.value || (data && data.force)) {
  //     this.setUploadedFeature(data.value);
  //   } else {
  //     const target = event.currentTarget;

  //     domElementHelpers.renderImportConfirmationModal(target, data.sourceId, () => this.setUploadedFeature(data.value));
  //   }
  // }
  // initMapActions() {
  //   this.initMapEditActions();
  // }
  // initMapEditActions() {
  //   if (this.feature) this.initGeometryEditActions();

  //   if (!this.feature) this.initMapDrawableActions();

  //   this.initSnapableAction();

  //   if (this.$geoCodeButton) this.$geoCodeButton.on('click', this.geoCodeAddress.bind(this));

  //   this.$latitudeField.on('change', this.updateMapMarker.bind(this));
  //   this.$longitudeField.on('change', this.updateMapMarker.bind(this));
  // }
  // initMapDrawableActions() {
  //   this.drawing = true;
  //   this.drawableInteraction = new this.ol.interaction.Draw({
  //     source: this.source,
  //     type: this.type,
  //     style: this.highlightStyleFunction.bind(this)
  //   });
  //   this.map.addInteraction(this.drawableInteraction);

  //   this.drawableInteraction.on('drawend', event => {
  //     this.feature = event.feature;
  //     this.feature.setStyle();
  //     this.disableDrawableFeature();
  //     this.setCoordinates();
  //     this.setHiddenFieldValue(this.getGeoJsonFromFeature());
  //     this.initGeometryEditActions();
  //   });
  // }
  // initGeometryEditActions() {
  //   // TODO: change to ModifyableActions for Point after ol update to 6.5 using method in
  //   // https://openlayers.org/en/latest/examples/modify-icon.html
  //   if (this.type === 'Point') this.initTranslatableActions();
  //   else this.initModifyableActions();
  // }
  // disableDrawableFeature() {
  //   this.map.removeInteraction(this.drawableInteraction);
  //   this.drawing = false;
  //   this.drawableInteraction = undefined;
  // }
  // initSnapableAction() {
  //   let snap = new this.ol.interaction.Snap({
  //     source: this.source
  //   });
  //   this.map.addInteraction(snap);
  // }
  // initTranslatableActions() {
  //   this.translateInteraction = new this.ol.interaction.Translate({
  //     features: new this.ol.collection([this.feature]),
  //     hitTolerance: 1
  //   });

  //   this.map.addInteraction(this.translateInteraction);

  //   this.translateInteraction.on('translateend', () => {
  //     if (this.feature) {
  //       this.setCoordinates();
  //       this.setHiddenFieldValue(this.getGeoJsonFromFeature());
  //       this.map.getView().animate({ duration: 300, center: this.feature.getGeometry().getCoordinates() });
  //     }
  //   });
  // }
  // initModifyableActions() {
  //   this.modifyInteraction = new this.ol.interaction.Modify({
  //     source: this.source,
  //     style: this.styleFunction.bind(this)
  //   });

  //   this.map.addInteraction(this.modifyInteraction);

  //   this.modifyInteraction.on('modifyend', () => {
  //     if (this.feature) {
  //       this.setHiddenFieldValue(this.getGeoJsonFromFeature());
  //     }
  //   });
  // }
  // geoCodeAddress(event) {
  //   event.preventDefault();

  //   if (this.$geoCodeButton.hasClass('disabled')) return;

  //   this.$geoCodeButton.append(' <i class="fa fa-spinner fa-spin fa-fw"></i>');
  //   this.$geoCodeButton.addClass('disabled');

  //   let addressKey = this.$geoCodeButton.data('address-key');
  //   let locale = this.$geoCodeButton.data('locale');
  //   let address = {
  //     locale: locale
  //   };

  //   $('.form-element.object.' + addressKey)
  //     .find('.form-element')
  //     .find('input')
  //     .each((_index, elem) => {
  //       address[elem.name.getAttributeKey()] = elem.value;
  //     });

  //   const promise = DataCycle.httpRequest({
  //     url: '/things/geocode_address',
  //     dataType: 'json',
  //     data: address
  //   });

  //   promise
  //     .then(data => {
  //       if (data.error) {
  //         new ConfirmationModal({
  //           text: data.error
  //         });
  //       } else if (data && data.length == 2) {
  //         this.setGeocodedValue(data);
  //       }
  //     })
  //     .catch((_jqxhr, textStatus, error) => {
  //       console.error(textStatus + ', ' + error);
  //     })
  //     .finally(() => {
  //       this.$geoCodeButton.find('i.fa').remove();
  //       this.$geoCodeButton.removeClass('disabled');
  //     });

  //   return promise;
  // }
  // setGeocodedValue(data) {
  //   if (!this.feature) {
  //     this.feature = new this.ol.Feature();
  //     this.source.addFeature(this.feature);
  //     this.initTranslatableActions();
  //   }

  //   this.feature.setGeometry(new this.ol.geom.Point(data).transform('EPSG:4326', 'EPSG:3857'));
  //   this.disableDrawableFeature();
  //   this.setNewCoordinates();
  // }
  // relayUploadClick(event) {
  //   event.preventDefault();

  //   if (this.$uploadInput) {
  //     this.$uploadInput.click();
  //   }
  // }
  // async handleUploadFile(evt) {
  //   let file = evt.target.files[0] || null;
  //   if (!file) {
  //     new ConfirmationModal({
  //       text: await I18n.translate('frontend.gpx.file_missing')
  //     });
  //   } else {
  //     const reader = new FileReader();
  //     reader.onload = (_gpxFile => {
  //       return async e => {
  //         let xmlString = e.target.result;
  //         let parser = new DOMParser();
  //         let xmlDoc = parser.parseFromString(xmlString, 'text/xml');
  //         let geoJSON = gpx(xmlDoc);
  //         let featureGeometry = {
  //           type: 'MultiLineString',
  //           coordinates: []
  //         };
  //         if (geoJSON && geoJSON.features && geoJSON.features.length) {
  //           geoJSON.features.forEach(feature => {
  //             if (feature.geometry.type.includes('MultiLineString'))
  //               featureGeometry.coordinates.push(...feature.geometry.coordinates);
  //             else if (feature.geometry.type.includes('LineString'))
  //               featureGeometry.coordinates.push(feature.geometry.coordinates);
  //           });
  //         }

  //         if (!featureGeometry.coordinates || !featureGeometry.coordinates.length) {
  //           new ConfirmationModal({
  //             text: await I18n.translate('frontend.gpx.empty'),
  //             confirmationText: 'Ok'
  //           });
  //         } else {
  //           this.setUploadedFeature(featureGeometry);
  //         }
  //         this.$uploadInput.val('');
  //       };
  //     })(file);
  //     reader.readAsText(file);
  //   }
  //   DataCycle.enableElement(this.$uploadButton);
  // }
  // geoJsonToWkt(geoJson) {
  //   const wkt = wkx.Geometry.parseGeoJSON(geoJson).toEwkt();
  //   return wkt;

  //   // if (this._coordinatesEmpty(geometry && geometry.coordinates)) return;

  //   // if (geometry.type.startsWith('LineString')) {
  //   //   geometry.type = 'Multi' + geometry.type;
  //   //   geometry.coordinates = [geometry.coordinates];
  //   // }

  //   // if (geometry.type.includes('LineString')) geometry.coordinates = this.addZCoordinate(geometry.coordinates);

  //   // return this.wktFormat.writeGeometry(this.geoJsonFormat.readGeometry(geometry));
  // }
  // addZCoordinate(coords) {
  //   for (let i = 0; i < coords.length; i++) {
  //     if (Array.isArray(coords[i]) && coords[i].length == 2 && !Array.isArray(coords[i][0])) coords[i].push(0.0);
  //     else if (Array.isArray(coords[i])) coords[i] = this.addZCoordinate(coords[i]);
  //   }

  //   return coords;
  // }
  setUploadedFeature(geoJson) {
    this.updateFeature(geoJson);
  }
  updateFeature(geoJson) {
    if (this.feature) this.draw.deleteAll();

    this.feature = geoJson;
    this.initEditFeature();
    this.setNewCoordinates();
  }
  // TODO:
  // updateMapMarker(_event) {
  //   let valid = true;
  //   const coords = this.getGeoJsonFromInputs().coordinates;
  //   coords.forEach(element => {
  //     valid = valid && !isNaN(element);
  //   });

  //   if (valid && this.feature) {
  //     this.feature.setGeometry(new this.ol.geom.Point(coords).transform('EPSG:4326', 'EPSG:3857'));
  //   } else if (valid && !this.feature) {
  //     this.feature = new this.ol.Feature({
  //       geometry: new this.ol.geom.Point(coords).transform('EPSG:4326', 'EPSG:3857')
  //     });

  //     this.source.addFeature(this.feature);
  //     this.disableDrawableFeature();
  //     this.initTranslatableActions();
  //   } else {
  //     if (this.feature) {
  //       this.map.removeInteraction(this.translateInteraction);
  //       this.translateInteraction = undefined;
  //       this.source.removeFeature(this.feature);
  //       this.feature = undefined;
  //     }
  //     if (!this.drawableInteraction) this.initMapDrawableActions();
  //   }

  //   this.setNewCoordinates();
  // }
  // TODO:
  removeFeature(event) {
    // console.log(event);
    // event.preventDefault(); // TODO: do we need this when calling programatically?
    if (event) event.preventDefault();

    if (this.feature) {
      // this.source.removeFeature(this.feature); // TODO: remove from map when calling programatically
      this.feature = undefined;
    }

    this.resetCoordinates();
    this.resetHiddenFieldValue();
    this.draw.changeMode(this.getMapDrawMode());
  }
  // TODO:
  // initUploadActions() {
  //   if (this.$uploadButton) this.$uploadButton.on('click', this.relayUploadClick.bind(this));
  //   if (this.$uploadInput) this.$uploadInput.on('change', this.handleUploadFile.bind(this));
  // }
  // shortenCoordinates(coords) {
  //   for (let i = 0; i < coords.length; i++) {
  //     if (Array.isArray(coords[i])) coords[i] = this.shortenCoordinates(coords[i]);
  //     else coords[i] = Number(coords[i].toFixed(this.precision));
  //   }

  //   return coords;
  // }
  // getFeatureLatLon() {
  //   let coords = this.feature.getGeometry().clone().transform('EPSG:3857', 'EPSG:4326').getCoordinates();

  //   return this.shortenCoordinates(coords);
  // }
  setNewCoordinates() {
    this.setCoordinates();
    this.setHiddenFieldValue(this.feature);
    if (this.feature) this.updateMapPosition();
  }
  // TODO:
  setCoordinates() {
    if (!this.feature || !this.isPoint()) return;

    const latLon = this.getFeatureLatLon();
    this.$latitudeField.val(latLon[1]);
    this.$longitudeField.val(latLon[0]);
  }
  // TODO:
  resetCoordinates() {
    if (!this.isPoint()) return;

    this.$latitudeField.val('');
    this.$longitudeField.val('');
  }
  // getGeoJsonFromInputs() {
  //   return {
  //     type: this.type,
  //     coordinates: [parseFloat(this.$longitudeField.val()), parseFloat(this.$latitudeField.val())]
  //   };
  // }
  // getGeoJsonFromFeature() {
  //   if (!this.feature) return;

  //   return {
  //     type: this.type,
  //     coordinates: this.getFeatureLatLon()
  //   };
  // }
  // _coordinatesEmpty(coords) {
  //   if (isEmpty(coords)) return true;

  //   if (Array.isArray(coords) && coords.some(c => Array.isArray(c)))
  //     return coords.every(c => this._coordinatesEmpty(c));

  //   return false;
  // }
  setHiddenFieldValue(geoJson) {
    this.value = geoJson;

    if (geoJson.geometry.type.startsWith('LineString')) {
      geoJson.geometry.type = 'Multi' + geoJson.geometry.type;
      geoJson.geometry.coordinates = [geoJson.geometry.coordinates];
    }

    this.$locationField.val(JSON.stringify(geoJson));
  }
  resetHiddenFieldValue() {
    this.value = null;
    this.$locationField.val('');
  }
  _getDrawPointStyle() {
    return [
      {
        id: 'gl-draw-point-highlight',
        type: 'circle',
        filter: ['all', ['==', '$type', 'Point'], ['==', 'meta', 'feature'], ['==', 'active', 'true']],
        paint: {
          'circle-radius': 7,
          'circle-color': this.definedColors.default,
          'circle-stroke-width': 4,
          'circle-stroke-color': this.definedColors.white
        }
      },
      {
        id: 'gl-draw-point',
        type: 'circle',
        filter: ['all', ['==', '$type', 'Point'], ['==', 'meta', 'feature'], ['==', 'active', 'false']],
        paint: {
          'circle-radius': 5,
          'circle-color': this.definedColors.default,
          'circle-stroke-width': 4,
          'circle-stroke-color': this.definedColors.white
        }
      }
    ];
  }
  _getDrawLineStyle() {
    return [
      {
        id: 'gl-draw-line',
        type: 'line',
        filter: ['all', ['==', '$type', 'LineString'], ['!=', 'mode', 'static']],
        layout: {
          'line-cap': 'round',
          'line-join': 'round'
        },
        paint: {
          'line-color': this.definedColors.default,
          'line-dasharray': [0.2, 2],
          'line-width': 5
        }
      },
      {
        id: 'gl-draw-polygon-midpoint-halo',
        type: 'circle',
        filter: ['all', ['==', '$type', 'Point'], ['==', 'meta', 'midpoint']],
        paint: {
          'circle-radius': 5,
          'circle-color': this.definedColors.white
        }
      },
      {
        id: 'gl-draw-polygon-midpoint',
        type: 'circle',
        filter: ['all', ['==', '$type', 'Point'], ['==', 'meta', 'midpoint']],
        paint: {
          'circle-radius': 3,
          'circle-color': this.definedColors.default
        }
      },
      {
        id: 'gl-draw-polygon-and-line-vertex-halo-active',
        type: 'circle',
        filter: ['all', ['==', 'meta', 'vertex'], ['==', '$type', 'Point'], ['!=', 'mode', 'static']],
        paint: {
          'circle-radius': 7,
          'circle-color': this.definedColors.white
        }
      },
      {
        id: 'gl-draw-polygon-and-line-vertex-active',
        type: 'circle',
        filter: ['all', ['==', 'meta', 'vertex'], ['==', '$type', 'Point'], ['!=', 'mode', 'static']],
        paint: {
          'circle-radius': 5,
          'circle-color': this.definedColors.default
        }
      }
    ];
  }
}

export default MapLibreGlEditor;

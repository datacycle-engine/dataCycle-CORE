import MapLibreGlViewer from './maplibre_gl_viewer';
import MapboxDraw from '@mapbox/mapbox-gl-draw';
import UploadGpxControl from './map_controls/maplibre_upload_gpx_control';
import domElementHelpers from '../helpers/dom_element_helpers';
// import AdditionalValuesFilterControl from './map_controls/mapbox_additional_values_filter_control';

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
  }
  static isAllowedType(_type) {
    return true;
  }
  configureMap() {
    super.configureMap();
    this.initEventHandlers();
  }
  initFeatures() {
    if (!this.feature && this.value) this.feature = this.value;
    // to ensure additional features are drawn last, the editor is initiallized here
    this.configureEditor();
    this.drawAdditionalFeatures();
  }
  configureEditor() {
    this.initAdditionalControls();

    if (this.feature) this.initEditFeature();

    // if (!isEmpty(this.additionalValuesOverlay))
    //   this.map.addControl(new AdditionalValuesFilterControl(this), 'bottom-left'); // TODO: locally override called methods if neccessary
  }
  initEventHandlers() {
    this.$container.on('dc:import:data', this.importData.bind(this)).addClass('dc-import-data');
    this.$latitudeField.on('change', this.updateMapMarker.bind(this));
    this.$longitudeField.on('change', this.updateMapMarker.bind(this));
    if (this.$geoCodeButton) this.$geoCodeButton.on('click', this.geoCodeAddress.bind(this));
  }

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

    this.initDrawEventHandlers();
  }
  initDrawEventHandlers() {
    this.map.on('draw.create', event => {
      this.feature = event.features[0];
      this.setCoordinates();
      this.setHiddenFieldValue(this.feature);
    });

    this.map.on('draw.delete', _event => {
      this.removeFeature();
    });

    this.map.on('draw.update', event => {
      this.feature = event.features[0];
      this.setCoordinates();
      this.setHiddenFieldValue(this.feature);
    });
  }
  getMapDrawMode() {
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
    if (this.isLineString()) this.draw.changeMode('direct_select', { featureId: featureIds[0] });
    if (this.isPoint()) this.draw.changeMode('simple_select', { featureIds: featureIds });
  }
  async importData(event, data) {
    if (!this.value || (data && data.force)) {
      this.setUploadedFeature(data.value);
    } else {
      const target = event.currentTarget;

      domElementHelpers.renderImportConfirmationModal(target, data.sourceId, () => this.setUploadedFeature(data.value));
    }
  }
  geoCodeAddress(event) {
    event.preventDefault();

    if (this.$geoCodeButton.hasClass('disabled')) return;

    this.$geoCodeButton.append(' <i class="fa fa-spinner fa-spin fa-fw"></i>');
    this.$geoCodeButton.addClass('disabled');

    let addressKey = this.$geoCodeButton.data('address-key');
    let locale = this.$geoCodeButton.data('locale');
    let address = {
      locale: locale
    };

    $('.form-element.object.' + addressKey)
      .find('.form-element')
      .find('input')
      .each((_index, elem) => {
        address[elem.name.attributeNameFromKey()] = elem.value;
      });

    const promise = DataCycle.httpRequest({
      url: '/things/geocode_address',
      dataType: 'json',
      data: address
    });

    promise
      .then(data => {
        if (data.error) {
          new ConfirmationModal({
            text: data.error
          });
        } else if (data && data.length == 2) {
          this.setGeocodedValue(data);
        }
      })
      .catch((_jqxhr, textStatus, error) => {
        console.error(textStatus + ', ' + error);
      })
      .finally(() => {
        this.$geoCodeButton.find('i.fa').remove();
        this.$geoCodeButton.removeClass('disabled');
      });

    return promise;
  }
  setGeocodedValue(data) {
    if (!this.feature) {
      this.updateFeature(this.getGeoJsonFromCoordinates(data, 'Point'));
    } else {
      this.feature.geometry.coordinates = data;
      this.updateFeature(this.feature);
      this.setNewCoordinates();
    }
  }
  setUploadedFeature(geometry) {
    this.updateFeature(this.getGeoJsonFromGeometry(geometry));
  }
  updateFeature(geoJson) {
    if (this.feature) this.draw.deleteAll();

    this.feature = geoJson;
    this.initEditFeature();
    this.setNewCoordinates();
  }
  updateMapMarker(_event) {
    let valid = true;
    const geoJson = this.getGeoJsonFromInputs();
    const coords = geoJson.geometry.coordinates;
    coords.forEach((element, index) => {
      // TODO: catch error and show some warning "Uncaught Error: Invalid LngLat latitude value: must be between -90 and 90"
      valid =
        valid &&
        !isNaN(element) &&
        ((index == 0 && element >= -180.0 && element <= 180.0) || (index == 1 && element >= -90.0 && element <= 90.0));
    });

    if (valid) {
      this.updateFeature(geoJson);
    } else {
      if (this.feature) {
        this.draw.trash();
      }
    }
  }
  removeFeature() {
    if (this.feature) {
      this.feature = undefined;
    }

    this.resetCoordinates();
    this.resetHiddenFieldValue();
    this.draw.changeMode(this.getMapDrawMode());
  }
  shortenCoordinates(coords) {
    for (let i = 0; i < coords.length; i++) {
      if (Array.isArray(coords[i])) coords[i] = this.shortenCoordinates(coords[i]);
      else coords[i] = Number(coords[i].toFixed(this.precision));
    }

    return coords;
  }
  getFeatureLatLon() {
    let coords = this.feature.geometry.coordinates;

    return this.shortenCoordinates(coords);
  }
  setNewCoordinates() {
    this.setCoordinates();
    this.setHiddenFieldValue(this.feature);
    if (this.feature) this.updateMapPosition();
  }
  setCoordinates() {
    if (!this.feature || !this.isPoint()) return;

    const latLon = this.getFeatureLatLon();
    this.$latitudeField.val(latLon[1]);
    this.$longitudeField.val(latLon[0]);
  }
  resetCoordinates() {
    if (!this.isPoint()) return;

    this.$latitudeField.val('');
    this.$longitudeField.val('');
  }
  getGeoJsonFromInputs() {
    return this.getGeoJsonFromCoordinates(
      [parseFloat(this.$longitudeField.val()), parseFloat(this.$latitudeField.val())],
      this.type
    );
  }
  getGeoJsonFromGeometry(geometry) {
    return this.getGeoJsonFromCoordinates(geometry.coordinates, geometry.type);
  }
  getGeoJsonFromCoordinates(coords, type) {
    return {
      type: 'Feature',
      properties: {},
      geometry: {
        type: type,
        coordinates: coords
      }
    };
  }
  setHiddenFieldValue(geoJson) {
    this.value = geoJson;

    if (geoJson && geoJson.geometry && geoJson.geometry.type && geoJson.geometry.type.startsWith('LineString')) {
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

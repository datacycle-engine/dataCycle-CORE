import OpenLayersViewer from './open_layers_viewer';
import { gpx } from '@tmcw/togeojson';
import ConfirmationModal from './confirmation_modal';

class OpenLayersEditor extends OpenLayersViewer {
  constructor(container) {
    super(container);

    this.uploadable = this.$container.data('allowUpload');
    this.translateInteraction;
    this.drawableInteraction;
    this.drawing = false;
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
  setup() {
    this.setZoomMethod();
    this.initFeatures();
    this.initEventHandlers();
    this.initMouseWheelZoom();

    this.initMap().then(() => {
      this.initMapHoverActions();
      this.initMapActions();
      if (this.uploadable) this.initUploadActions();
      this.updateMapPosition();
    });
  }
  initEventHandlers() {
    this.$container.on('dc:import:data', this.importData.bind(this));
  }
  importData(_event, data) {
    if (
      ((!this.$elevationField.val() || this.$elevationField.val().length == 0) &&
        this.$locationField.val().length == 0) ||
      (data && data.force)
    ) {
      this.$elevationField.val(data.value.elevation);
      this.$latitudeField.val(data.value.y).trigger('change');
      this.$longitudeField.val(data.value.x).trigger('change');
    } else {
      new ConfirmationModal({
        text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
        confirmationText: 'Ja',
        cancelText: 'Nein',
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: function () {
          this.$elevationField.val(data.value.elevation);
          this.$latitudeField.val(data.value.y).trigger('change');
          this.$longitudeField.val(data.value.x).trigger('change');
        }.bind(this)
      });
    }
  }
  initMapActions() {
    if (this.type.includes('Point')) this.initMapEditActions();
  }
  initMapEditActions() {
    if (this.feature) this.initTranslatableActions();

    if (!this.feature && this.type == 'Point') this.initMapDrawableActions();

    let snap = new this.ol.interaction.Snap({
      source: this.source
    });
    this.map.addInteraction(snap);

    if (this.$geoCodeButton) this.$geoCodeButton.on('click', this.geoCodeAddress.bind(this));

    this.$latitudeField.on('change', this.updateMapMarker.bind(this));
    this.$longitudeField.on('change', this.updateMapMarker.bind(this));
  }
  initMapDrawableActions() {
    this.drawing = true;
    this.drawableInteraction = new this.ol.interaction.Draw({
      source: this.source,
      type: this.type,
      style: this.highlightStyleFunction.bind(this)
    });
    this.map.addInteraction(this.drawableInteraction);

    this.drawableInteraction.on('drawend', event => {
      this.feature = event.feature;
      this.feature.setStyle();
      this.disableDrawableFeature();
      this.setCoordinates();
      this.setHiddenFieldValue(this.getGeoJsonFromFeature());
      this.initTranslatableActions();
    });
  }
  disableDrawableFeature() {
    this.map.removeInteraction(this.drawableInteraction);
    this.drawing = false;
    this.drawableInteraction = undefined;
  }
  initTranslatableActions() {
    this.translateInteraction = new this.ol.interaction.Translate({
      features: new this.ol.collection([this.feature]),
      hitTolerance: 1
    });

    this.map.addInteraction(this.translateInteraction);

    this.translateInteraction.on('translateend', () => {
      if (this.feature) {
        this.setCoordinates();
        this.setHiddenFieldValue(this.getGeoJsonFromFeature());
        this.map.getView().animate({ duration: 300, center: this.feature.getGeometry().getCoordinates() });
      }
    });
  }
  geoCodeAddress(event) {
    event.preventDefault();

    if (this.$geoCodeButton.hasClass('disabled')) return;

    this.$geoCodeButton.append(' <i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i>');
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
        address[elem.name.getKey()] = elem.value;
      });

    DataCycle.httpRequest({
      url: `${DataCycle.config.EnginePath}/things/geocode_address`,
      dataType: 'json',
      data: address
    })
      .done(data => {
        if (data.error) {
          new ConfirmationModal({
            text: data.error
          });
        } else if (data && data.length == 2) {
          this.setGeocodedValue(data);
        }
      })
      .fail((_jqxhr, textStatus, error) => {
        console.error(textStatus + ', ' + error);
      })
      .always(() => {
        this.$geoCodeButton.find('i.fa').remove();
        this.$geoCodeButton.removeClass('disabled');
      });
  }
  setGeocodedValue(data) {
    if (!this.feature) {
      this.feature = new this.ol.Feature();
      this.source.addFeature(this.feature);
      this.initTranslatableActions();
    }

    this.feature.setGeometry(new this.ol.geom.Point(data).transform('EPSG:4326', 'EPSG:3857'));
    this.disableDrawableFeature();
    this.setNewCoordinates();
  }
  relayUploadClick(event) {
    event.preventDefault();

    if (this.$uploadInput) {
      this.$uploadInput.click();
    }
  }
  handleUploadFile(evt) {
    let file = evt.target.files[0] || null;
    if (!file) {
      new ConfirmationModal({
        text: 'Datei nicht gefunden!'
      });
    } else {
      const reader = new FileReader();
      reader.onload = (_gpxFile => {
        return e => {
          let xmlString = e.target.result;
          let parser = new DOMParser();
          let xmlDoc = parser.parseFromString(xmlString, 'text/xml');
          let geoJSON = gpx(xmlDoc);
          let features = {
            type: 'MultiLineString',
            coordinates: []
          };
          if (geoJSON && geoJSON.features && geoJSON.features.length) {
            geoJSON.features.forEach(feature => {
              if (feature.geometry.type.includes('MultiLineString'))
                features.coordinates.push(...feature.geometry.coordinates);
              else if (feature.geometry.type.includes('LineString'))
                features.coordinates.push(feature.geometry.coordinates);
            });
          }

          if (!features.coordinates || !features.coordinates.length) {
            new ConfirmationModal({
              text: 'Die GPX-Datei beinhaltet keinen Track.',
              confirmationText: 'Ok'
            });
          } else {
            this.setUploadedFeature(features);
          }
          this.$uploadInput.val('');
        };
      })(file);
      reader.readAsText(file);
    }
    DataCycle.enableElement(this.$uploadButton);
  }
  geoJsonToWkt(geometry) {
    if (!geometry || !geometry.coordinates || !geometry.coordinates.length) return;

    if (geometry.type.startsWith('LineString')) {
      geometry.type = 'Multi' + geometry.type;
      geometry.coordinates = [geometry.coordinates];
    }

    if (geometry.type.includes('LineString')) geometry.coordinates = this.addZCoordinate(geometry.coordinates);

    return this.wktFormat.writeGeometry(this.geoJsonFormat.readGeometry(geometry));
  }
  addZCoordinate(coords) {
    for (let i = 0; i < coords.length; i++) {
      if (Array.isArray(coords[i]) && coords[i].length == 2 && !Array.isArray(coords[i][0])) coords[i].push(0.0);
      else if (Array.isArray(coords[i])) coords[i] = this.addZCoordinate(coords[i]);
    }

    return coords;
  }
  setUploadedFeature(geometry) {
    this.setHiddenFieldValue(geometry);
    this.updateFeature(geometry);
  }
  updateFeature(newGeometry) {
    if (this.feature) this.source.removeFeature(this.feature);

    this.feature = this.featureFromGeoJSON({
      type: 'Feature',
      geometry: newGeometry
    });

    this.source.addFeature(this.feature);
    this.updateMapPosition();
  }
  updateMapMarker(_event) {
    let valid = true;
    const coords = this.getGeoJsonFromInputs().coordinates;
    coords.forEach(element => {
      valid = valid && !isNaN(element);
    });

    if (valid && this.feature) {
      this.feature.setGeometry(new this.ol.geom.Point(coords).transform('EPSG:4326', 'EPSG:3857'));
    } else if (valid && !this.feature) {
      this.feature = new this.ol.Feature({
        geometry: new this.ol.geom.Point(coords).transform('EPSG:4326', 'EPSG:3857')
      });

      this.source.addFeature(this.feature);
      this.disableDrawableFeature();
      this.initTranslatableActions();
    } else {
      if (this.feature) {
        this.map.removeInteraction(this.translateInteraction);
        this.translateInteraction = undefined;
        this.source.removeFeature(this.feature);
        this.feature = undefined;
      }
      if (!this.drawableInteraction) this.initMapDrawableActions();
    }

    this.setNewCoordinates();
  }
  initUploadActions() {
    if (this.$uploadButton) this.$uploadButton.on('click', this.relayUploadClick.bind(this));
    if (this.$uploadInput) this.$uploadInput.on('change', this.handleUploadFile.bind(this));
  }
  shortenCoordinates(coords) {
    for (let i = 0; i < coords.length; i++) {
      if (Array.isArray(coords[i])) coords[i] = this.shortenCoordinates(coords[i]);
      else coords[i] = Number(coords[i].toFixed(this.precision));
    }

    return coords;
  }
  getFeatureLatLon() {
    let coords = this.feature.getGeometry().clone().transform('EPSG:3857', 'EPSG:4326').getCoordinates();

    return this.shortenCoordinates(coords);
  }
  setNewCoordinates() {
    this.setCoordinates();
    this.setHiddenFieldValue(this.getGeoJsonFromFeature());

    if (this.feature)
      this.map.getView().animate({ duration: 300, center: this.feature.getGeometry().getCoordinates() });
  }
  setCoordinates() {
    if (!this.feature || this.type != 'Point') return;

    const latLon = this.getFeatureLatLon();
    this.$latitudeField.val(latLon[1]);
    this.$longitudeField.val(latLon[0]);
  }
  getGeoJsonFromInputs() {
    return {
      type: this.type,
      coordinates: [parseFloat(this.$longitudeField.val()), parseFloat(this.$latitudeField.val())]
    };
  }
  getGeoJsonFromFeature() {
    if (!this.feature) return;

    return {
      type: this.type,
      coordinates: this.getFeatureLatLon()
    };
  }
  setHiddenFieldValue(geoJSON) {
    this.$locationField.val(this.geoJsonToWkt(geoJSON));
  }
}

export default OpenLayersEditor;

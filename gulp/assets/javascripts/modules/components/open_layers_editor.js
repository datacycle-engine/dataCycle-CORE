var OpenLayersViewer = require('./open_layers_viewer');
var togeojson = require('@tmcw/togeojson');
var ConfirmationModal = require('./confirmation_modal');
var wkx = require('wkx');

class OpenLayersEditor extends OpenLayersViewer {
  constructor(container) {
    super(container);

    this.uploadable = this.$container.data('allowUpload');
    this.modify;
    this.modifying = false;
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
    if (this.feature) this.initModifyableActions();

    if (!this.feature && this.type == 'Point') this.initMapDrawableActions();

    let snap = new this.ol.interaction.Snap({
      source: this.source
    });
    this.map.addInteraction(snap);

    this.map.on('pointerdrag', _event => {
      if (this.modifying && this.feature) this.setCoordinates();
    });

    if (this.$geoCodeButton) this.$geoCodeButton.on('click', this.geoCodeAddress.bind(this));

    this.$latitudeField.on('change', this.updateMapMarker.bind(this));
    this.$longitudeField.on('change', this.updateMapMarker.bind(this));
  }
  initMapDrawableActions() {
    this.draw = new this.ol.interaction.Draw({
      source: this.source,
      type: this.type
    });
    this.map.addInteraction(this.draw);

    this.draw.on('drawend', event => {
      this.feature = event.feature;
      this.feature.setStyle();
      this.disableDrawableFeature();
      this.setCoordinates();
      this.setHiddenFieldValue(this.getGeoJsonFromFeature());
      this.initModifyableActions();
    });
  }
  disableDrawableFeature() {
    this.map.removeInteraction(this.draw);
    this.draw = undefined;
  }
  initModifyableActions() {
    const features = new this.ol.collection([this.feature]);
    this.modify = new this.ol.interaction.Modify({
      features: features
    });
    this.map.addInteraction(this.modify);

    this.modify.on('modifystart', () => {
      this.modifying = true;
    });

    this.modify.on('modifyend', () => {
      this.modifying = false;

      if (this.feature) this.setHiddenFieldValue(this.getGeoJsonFromFeature());
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

    $.getJSON('/things/geocode_address/', address)
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
      this.initModifyableActions();
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
          let geoJSON = togeojson.gpx(xmlDoc);
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
    $.rails.enableElement(this.$uploadButton);
  }
  geoJsonToWkt(geometry) {
    if (!geometry || !geometry.coordinates || !geometry.coordinates.length) return;

    if (geometry.type.startsWith('LineString')) {
      geometry.type = 'Multi' + geometry.type;
      geometry.coordinates = [geometry.coordinates];
    }

    if (geometry.type.includes('LineString')) geometry.coordinates = this.addZCoordinate(geometry.coordinates);

    return wkx.Geometry.parseGeoJSON(geometry).toWkt();
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
      this.initModifyableActions();
    } else {
      if (this.feature) {
        this.map.removeInteraction(this.modify);
        this.modify = undefined;
        this.source.removeFeature(this.feature);
        this.feature = undefined;
      }
      if (!this.draw) this.initMapDrawableActions();
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

    if (this.feature) this.map.getView().setCenter(this.feature.getGeometry().getCoordinates());
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

module.exports = OpenLayersEditor;

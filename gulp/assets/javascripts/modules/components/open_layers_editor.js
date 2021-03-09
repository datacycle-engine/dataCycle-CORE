var OpenLayersViewer = require('./open_layers_viewer');
var togeojson = require('@tmcw/togeojson');
var wkx = require('wkx');

class OpenLayersEditor extends OpenLayersViewer {
  constructor(container) {
    super(container);

    this.drawable = this.type == 'Point';
    this.source;
    this.map;
    this.modify;
    this.draw;
    this.modifying = false;
    this.geoCodeButton = $('.geocode-address-button');
    this.uploadButton = this.container.parent('.geographic').siblings('.map-edit').children('.upload-gpx-button');
    this.uploadInput = this.container.parent('.geographic').siblings('.map-edit').children('.upload-gpx-input');
    this.addressFields = this.container.parent('.geographic').siblings('.map-info');
  }
  setup() {
    this.setZoomMethod();
    this.initIconStyles();
    this.initFeatures();
    this.initEventHandlers();
    this.configureFeatures();
    this.configureLayerLines();
    this.initMouseWheelZoom();

    this.initMap().then(() => {
      this.initMapActions();
      this.initUploadActions();
      this.setDefaultPosition();
    });
  }
  initFeatures() {
    super.initFeatures();

    if (this.feature || this.featureBefore) this.drawable = false;
  }
  initEventHandlers() {
    this.container.on('dc:import:data', this.importData.bind(this));
  }
  importData(event, data) {
    let form_fields = $(event.target).parent('.geographic').siblings('.map-info').first();

    let elevationField = form_fields.find('.form-element.elevation > input');

    if (
      ((!elevationField.val() || elevationField.val().length == 0) &&
        $(event.target).parent('.geographic').siblings('input.location-data:hidden').first().val().length == 0) ||
      (data && data.force)
    ) {
      elevationField.val(data.value.elevation);
      form_fields.find('.form-element.latitude > input').val(data.value.y).trigger('change');
      form_fields.find('.form-element.longitude > input').val(data.value.x).trigger('change');
    } else {
      new ConfirmationModal({
        text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
        confirmationText: 'Ja',
        cancelText: 'Nein',
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: function () {
          elevationField.val(data.value.elevation);
          form_fields.find('.form-element.latitude > input').val(data.value.y).trigger('change');
          form_fields.find('.form-element.longitude > input').val(data.value.x).trigger('change');
        }.bind(this)
      });
    }
  }
  initMapActions() {
    this.map.on('pointermove', evt => {
      let hit = evt.map.hasFeatureAtPixel(evt.pixel);
      evt.map.getTargetElement().firstElementChild.style.cursor = evt.dragging ? 'grabbing' : hit ? 'pointer' : '';
    });

    if (this.type == 'Point') this.initMapEditActions();
  }
  initMapDrawableActions() {
    this.draw = new this.ol.interaction.Draw({
      source: this.source,
      type: 'Point'
    });
    this.map.addInteraction(this.draw);

    this.draw.on('drawend', event => {
      this.drawable = false;
      this.feature = event.feature;

      if (this.styles.icon.default !== undefined) this.feature.setStyle(this.styles.icon.default);

      this.disableDrawableFeature();
      this.setCoordinates();
      this.setHiddenFieldValue(this.getCoordinatesFromFeature());
    });
  }
  disableDrawableFeature() {
    this.map.removeInteraction(this.draw);
    this.draw = undefined;
  }
  initGeoCodingActions(event) {
    event.preventDefault();

    $(event.currentTarget).append(' <i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i>');

    let addressKey = $(event.currentTarget).data('address-key');
    let locale = $(event.currentTarget).data('locale');
    let address = {
      locale: locale
    };

    $('.form-element.object.' + addressKey)
      .find('.form-element')
      .find('input')
      .each((index, elem) => {
        address[elem.name.getKey()] = elem.value;
      });

    $.getJSON('/things/geocode_address/', address)
      .done(data => {
        if (data.error !== undefined) {
          new ConfirmationModal({
            text: data.error
          });
        } else if (data !== undefined && data.length == 2 && this.feature !== undefined) {
          this.feature.setGeometry(new this.ol.geom.Point(data).transform('EPSG:4326', 'EPSG:3857'));
          this.setNewCoordinates();
        } else if (data !== undefined && data.length == 2 && this.feature === undefined) {
          this.feature = new this.ol.Feature({
            geometry: new this.ol.geom.Point(data).transform('EPSG:4326', 'EPSG:3857')
          });
          if (this.styles.icon.default !== undefined) this.feature.setStyle(this.styles.icon.default);
          this.source.addFeature(this.feature);
          this.disableDrawableFeature();
          this.setNewCoordinates();
        }
      })
      .fail((jqxhr, textStatus, error) => {
        console.log(textStatus + ', ' + error);
      })
      .always(() => {
        $(event.currentTarget).find('i.fa').remove();
      });
  }
  relayUploadClick(event) {
    event.preventDefault();

    if (this.uploadInput) {
      this.uploadInput.click();
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
      reader.onload = (gpxFile => {
        return e => {
          let xmlString = e.target.result;
          let parser = new DOMParser();
          let xmlDoc = parser.parseFromString(xmlString, 'text/xml');
          let geojson = togeojson.gpx(xmlDoc);

          if (geojson.features.length > 1) {
            new ConfirmationModal({
              text: 'Die GPX-Datei beinhaltet mehr als einen Track. Nur der erste kann importiert werden.',
              confirmationText: 'Ersten importieren',
              cancelText: 'Abbrechen',
              confirmationClass: 'success',
              cancelable: true,
              confirmationCallback: function () {
                this.setUploadedFeature(geojson.features[0].geometry);
              }.bind(this)
            });
          } else {
            this.setUploadedFeature(geojson.features[0].geometry);
          }
          this.uploadInput.val('');
        };
      })(file);
      reader.readAsText(file);
    }
    $.rails.enableElement(this.uploadButton);
  }
  geoJsonGeometryToWkt(geometry) {
    return wkx.Geometry.parseGeoJSON(geometry).toWkt();
  }
  setUploadedFeature(geojsonGeometry) {
    this.setHiddenFieldValue(geojsonGeometry);
    this.updateFeature(this.geoJsonGeometryToWkt(geojsonGeometry));
  }
  updateFeature(newFeature) {
    this.feature = this.createFeaturefromWkt(newFeature);
    this.feature.setStyle(this.styles[this.type == 'Point' ? 'icon' : 'line'].default);

    this.source.clear();
    this.source.addFeature(this.feature);

    this.map.getView().fit(this.feature.getGeometry().getExtent(), { padding: [50, 50, 50, 50], maxZoom: 15 });
  }
  updateMapMarker(_event) {
    let valid = true;
    const coords = this.getCoordinatesFromInputs().coordinates;
    coords.forEach(element => {
      valid = valid && !isNaN(element);
    });

    if (valid && this.feature) {
      this.feature.setGeometry(new this.ol.geom.Point(coords).transform('EPSG:4326', 'EPSG:3857'));
    } else if (valid && !this.feature) {
      this.feature = new this.ol.Feature({
        geometry: new this.ol.geom.Point(coords).transform('EPSG:4326', 'EPSG:3857')
      });

      this.feature.setStyle(this.styles.icon.default);
      this.source.addFeature(this.feature);
      this.disableDrawableFeature();
    } else if (!this.draw) {
      this.source.clear();
      this.feature = undefined;
      this.initMapDrawableActions();
    }

    this.setNewCoordinates();
  }
  initMapEditActions() {
    this.modify = new this.ol.interaction.Modify({
      source: this.source
    });
    this.map.addInteraction(this.modify);
    if (this.drawable) this.initMapDrawableActions();

    let snap = new this.ol.interaction.Snap({
      source: this.source
    });
    this.map.addInteraction(snap);

    this.modify.on('modifystart', () => {
      this.modifying = true;
    });

    this.modify.on('modifyend', () => {
      this.modifying = false;

      if (this.feature) this.setHiddenFieldValue(this.getCoordinatesFromFeature());
    });

    this.map.on('pointerdrag', _event => {
      if (this.modifying && this.feature) this.setCoordinates();
    });

    if (this.geoCodeButton !== undefined) this.geoCodeButton.on('click', this.initGeoCodingActions.bind(this));

    this.addressFields.find('.longitude input, .latitude  input').on('change', this.updateMapMarker.bind(this));
  }
  initUploadActions() {
    if (this.uploadButton) this.uploadButton.on('click', this.relayUploadClick.bind(this));
    if (this.uploadInput) this.uploadInput.on('change', this.handleUploadFile.bind(this));
  }
  getFeatureLatLon() {
    let coords = this.feature.getGeometry().clone().transform('EPSG:3857', 'EPSG:4326').getCoordinates();

    if (Array.isArray(coords[0])) {
      for (let i = 0; i < coords.length; i++) {
        for (let j = 0; j < coords[i].length; j++) {
          coords[i][j] = Number(coords[i][j].toFixed(6));
        }
      }
    } else {
      for (let i = 0; i < coords.length; i++) {
        coords[i] = Number(coords[i].toFixed(6));
      }
    }

    return coords;
  }
  setNewCoordinates() {
    this.setCoordinates();
    this.setHiddenFieldValue(this.getCoordinatesFromFeature());

    if (this.feature) this.map.getView().setCenter(this.feature.getGeometry().getCoordinates());
  }
  setCoordinates() {
    if (!this.feature || this.type != 'Point') return;

    const latLon = this.getFeatureLatLon();
    this.addressFields.find('.longitude input').val(latLon[0]);
    this.addressFields.find('.latitude input').val(latLon[1]);
  }
  getCoordinatesFromInputs() {
    return {
      type: this.type,
      coordinates: [
        parseFloat(this.addressFields.find('.longitude input').val()),
        parseFloat(this.addressFields.find('.latitude input').val())
      ]
    };
  }
  getCoordinatesFromFeature() {
    if (!this.feature) return null;

    return {
      type: this.type,
      coordinates: this.getFeatureLatLon()
    };
  }
  setHiddenFieldValue(geoJSON) {
    if (!geoJSON || !geoJSON.coordinates || !geoJSON.coordinates.length) return;

    this.container.parent('.geographic').siblings('.location-data').first().val(this.geoJsonGeometryToWkt(geoJSON));
  }
}

module.exports = OpenLayersEditor;

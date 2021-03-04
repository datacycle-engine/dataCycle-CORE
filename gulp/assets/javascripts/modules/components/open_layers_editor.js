var OpenLayersViewer = require('./open_layers_viewer');
var togeojson = require('@tmcw/togeojson');
var wkx = require('wkx');

class OpenLayersEditor extends OpenLayersViewer {
  constructor(container) {
    super(container);

    this.drawable = true;
    this.source;
    this.map;
    this.modify;
    this.draw;
    this.modifying = false;
    this.geoCodeButton = $('.geocode-address-button');
    this.uploadButton = this.container.parent('.geographic').siblings('.map-edit').children('.upload-gpx-button');
    this.uploadInput = this.container.parent('.geographic').siblings('.map-edit').children('.upload-gpx-input');
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
  createFeaturefromWkt(wkt) {
    let format = new ol.format.WKT();

    return format.readFeature(wkt, {
      dataProjection: 'EPSG:4326',
      featureProjection: 'EPSG:3857'
    });
  }
  configureFeatures() {
    if (this.feature !== undefined) this.features.push(this.feature);
    if (this.featureOld !== undefined) this.features.push(this.featureOld);

    if (this.features.length > 0) {
      this.options = {
        features: this.features
      };
    }
  }
  configureLayerLines() {
    this.source = new ol.source.Vector(this.options);

    this.layerLines = new ol.layer.Vector({
      source: this.source,
      style: [
        new ol.style.Style({
          stroke: new ol.style.Stroke({
            color: '#c30000',
            width: 3
          }),
          image: new ol.style.Circle({
            radius: 3,
            fill: new ol.style.Fill({
              color: '#c30000'
            }),
            stroke: new ol.style.Stroke({
              color: '#c30000',
              width: 3
            })
          })
        })
      ]
    });
  }
  initMouseWheelZoom() {
    let oldFn = this.mouseWheelZoom.handleEvent;
    let self = this;

    this.mouseWheelZoom.handleEvent = function (e) {
      let type = e.type;
      if (type !== 'wheel') {
        return true;
      }

      if (!e.originalEvent.ctrlKey) {
        if (!$(e.map.getTargetElement().firstElementChild).find('.scroll-overlay').length) {
          $(e.map.getTargetElement().firstElementChild)
            .find('canvas')
            .after(
              '<div class="scroll-overlay" style="display: none;"><div class="scroll-overlay-text">Verwende Strg+Scrollen zum Zoomen der Karte</div></div>'
            );
        } else {
          $(e.map.getTargetElement().firstElementChild).find('.scroll-overlay').fadeIn(100);
        }

        window.clearTimeout(self.mouseZoomTimeout);
        self.mouseZoomTimeout = window.setTimeout(() => {
          $(e.map.getTargetElement().firstElementChild).find('.scroll-overlay').fadeOut(100);
        }, 1000);
        return true;
      } else {
        $(e.map.getTargetElement().firstElementChild).find('.scroll-overlay').fadeOut(100);
      }

      oldFn.call(this, e);
    };
  }
  initMapActions() {
    this.map.on('pointermove', evt => {
      let hit = evt.map.hasFeatureAtPixel(evt.pixel);
      evt.map.getTargetElement().firstElementChild.style.cursor = evt.dragging ? 'grabbing' : hit ? 'pointer' : '';
    });

    if (this.editable) this.initMapEditActions();
  }
  initMapDrawableActions() {
    this.draw = new ol.interaction.Draw({
      source: this.source,
      type: 'Point'
    });
    this.map.addInteraction(this.draw);

    this.draw.on('drawend', event => {
      this.drawable = false;
      this.feature = event.feature;
      if (this.iconStyle !== undefined) this.feature.setStyle(this.iconStyle);
      this.map.removeInteraction(this.draw);
      this.setCoordinates();
      this.setHiddenFieldValue(this.getPointWkt());
    });
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
          this.feature.setGeometry(new ol.geom.Point(data).transform('EPSG:4326', 'EPSG:3857'));
          this.setNewCoordinates();
        } else if (data !== undefined && data.length == 2 && this.feature === undefined) {
          this.feature = new ol.Feature({
            geometry: new ol.geom.Point(data).transform('EPSG:4326', 'EPSG:3857')
          });
          if (this.iconStyle !== undefined) this.feature.setStyle(this.iconStyle);
          this.source.addFeature(this.feature);
          this.map.removeInteraction(this.draw);
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
            var confirmationModal = new ConfirmationModal({
              text: 'Die GPX-Datei beinhaltet mehr als einen Track. Nur der erste kann importiert werden.',
              confirmationText: 'Ersten importieren',
              cancelText: 'Abbrechen',
              confirmationClass: 'success',
              cancelable: true,
              confirmationCallback: function () {
                this.setUploadedFeature(this.geoJsonGeometryToWkt(geojson.features[0].geometry));
              }.bind(this)
            });
          } else {
            this.setUploadedFeature(this.geoJsonGeometryToWkt(geojson.features[0].geometry));
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
  setUploadedFeature(wkt) {
    this.setHiddenFieldValue(wkt);
    this.updateFeature(wkt);
  }
  updateFeature(newFeature) {
    // draw line on map
    let format = new ol.format.WKT();
    this.feature = format.readFeature(newFeature, {
      dataProjection: 'EPSG:4326',
      featureProjection: 'EPSG:3857'
    });

    if (this.type == 'LineString' || this.type == 'MultiLineString') {
      this.feature.setStyle(this.defaultLineStyle);
    } else {
      this.feature.setStyle(this.iconStyle);
    }

    this.source.clear();
    this.source.addFeature(this.feature);

    this.map.getView().fit(this.feature.getGeometry().getExtent(), { padding: [50, 50, 50, 50] });
  }

  updateMapMarker(event) {
    let valid = true;
    let coords = this.getCoordinates();
    coords.forEach(element => {
      valid = valid && !isNaN(element);
    });

    if (valid && this.feature !== undefined) {
      this.feature.setGeometry(new ol.geom.Point(this.getCoordinates()).transform('EPSG:4326', 'EPSG:3857'));
      this.setNewCoordinates();
    } else if (valid && this.feature === undefined) {
      this.feature = new ol.Feature({
        geometry: new ol.geom.Point(this.getCoordinates()).transform('EPSG:4326', 'EPSG:3857')
      });
      if (this.iconStyle !== undefined) this.feature.setStyle(this.iconStyle);
      this.source.addFeature(this.feature);
      this.map.removeInteraction(this.draw);
      this.setNewCoordinates();
    }
  }
  initMapEditActions() {
    this.modify = new ol.interaction.Modify({
      source: this.source
    });
    this.map.addInteraction(this.modify);
    if (this.drawable) this.initMapDrawableActions();

    let snap = new ol.interaction.Snap({
      source: this.source
    });
    this.map.addInteraction(snap);

    this.modify.on('modifystart', () => {
      this.modifying = true;
    });

    this.modify.on('modifyend', () => {
      this.modifying = false;
      if (this.feature !== undefined) {
        this.setHiddenFieldValue(this.getPointWkt());
      }
    });

    this.map.on('pointerdrag', event => {
      if (this.modifying && this.feature !== undefined) {
        this.setCoordinates();
      }
    });

    if (this.geoCodeButton !== undefined) this.geoCodeButton.on('click', this.initGeoCodingActions.bind(this));

    this.container
      .parent('.geographic')
      .siblings('.map-info')
      .first()
      .find('.longitude input, .latitude  input')
      .on('change', this.updateMapMarker.bind(this));
  }
  initUploadActions() {
    if (this.uploadButton !== undefined) this.uploadButton.on('click', this.relayUploadClick.bind(this));
    if (this.uploadInput !== undefined) this.uploadInput.on('change', this.handleUploadFile.bind(this));
  }
  getLatLon(coords) {
    return ol.proj.transform(coords, 'EPSG:3857', 'EPSG:4326');
  }
  setNewCoordinates() {
    this.setCoordinates();
    this.setHiddenFieldValue(this.getPointWkt());
    this.map.getView().setCenter(this.feature.getGeometry().getCoordinates());
  }
  setCoordinates() {
    let coords = this.feature.getGeometry().getCoordinates();
    let latlon = this.getLatLon(coords);
    latlon[0] = Number(latlon[0].toFixed(5));
    latlon[1] = Number(latlon[1].toFixed(5));
    this.container.parent('.geographic').siblings('.map-info').first().find('.longitude input').val(latlon[0]);
    this.container.parent('.geographic').siblings('.map-info').first().find('.latitude input').val(latlon[1]);
  }
  getCoordinates() {
    return [
      parseFloat(this.container.parent('.geographic').siblings('.map-info').first().find('.longitude input').val()),
      parseFloat(this.container.parent('.geographic').siblings('.map-info').first().find('.latitude input').val())
    ];
  }
  getPointWkt() {
    let latlon = this.getCoordinates();
    return 'POINT (' + latlon[0] + ' ' + latlon[1] + ')';
  }
  setHiddenFieldValue(wkt) {
    this.container.parent('.geographic').siblings('.location-data').first().val(wkt);
  }
  setDefaultPosition() {
    if (
      (this.type == 'LineString' && (this.feature !== undefined || this.featureOld !== undefined)) ||
      (this.feature !== undefined && this.featureOld !== undefined)
    ) {
      let extent = new ol.extent.createEmpty();
      if (this.feature !== undefined) extent = new ol.extent.extend(extent, this.feature.getGeometry().getExtent());
      if (this.featureOld !== undefined)
        extent = new ol.extent.extend(extent, this.featureOld.getGeometry().getExtent());
      this.map.getView().fit(extent, { padding: [50, 50, 50, 50] });
    } else if (this.type == 'Point' && (this.feature !== undefined || this.featureOld !== undefined)) {
      this.map.getView().setCenter((this.feature || this.featureOld).getGeometry().getCoordinates());
    } else if (this.type == 'MultiLineString' && (this.feature !== undefined || this.featureOld !== undefined)) {
      let extent = new ol.extent.createEmpty();
      if (this.feature !== undefined) extent = new ol.extent.extend(extent, this.feature.getGeometry().getExtent());
      this.map.getView().fit(extent, { padding: [50, 50, 50, 50] });
    } else {
      if (
        this.defaultPosition !== undefined &&
        this.defaultPosition.longitude !== undefined &&
        this.defaultPosition.latitude !== undefined
      ) {
        let newCoords = new ol.geom.Point([this.defaultPosition.longitude, this.defaultPosition.latitude]).transform(
          'EPSG:4326',
          'EPSG:3857'
        );
        this.map.getView().setCenter(newCoords.getCoordinates());
      }
      if (this.defaultPosition !== undefined && this.defaultPosition.zoom !== undefined)
        this.map.getView().setZoom(this.defaultPosition.zoom);
    }
  }
}

module.exports = OpenLayersEditor;

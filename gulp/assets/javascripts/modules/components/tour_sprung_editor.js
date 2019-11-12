var ConfirmationModal = require('./confirmation_modal');
var ObjectHelpers = require('./../helpers/object_helpers');

class TourSprungEditor {
  constructor(container) {
    this.container = $(container);
    this.target = this.container.attr('id');
    this.value = this.container.data('value');
    this.beforeValue = this.container.data('before-position');
    this.afterValue = this.container.data('after-position');
    this.type = this.container.data('type');
    this.iconPaths = this.container.data('icon-paths');
    this.editable = this.container.parent('.geographic').hasClass('editable');
    this.mapOptions = this.container.data('map-options');
    this.defaultPosition = ObjectHelpers.select(this.mapOptions, ['latitude', 'longitude', 'zoom']);
    this.credentials = this.mapOptions.credentials;
    this.drawableEvent;
    this.marker;
    this.map;

    this.setup();
  }
  setup() {
    MTK.init({ apiKey: this.credentials.api_key });
    this.initMap();
    this.initEventHandlers();
  }
  initMap() {
    let defaultMapPosition = this.calculateCenter();
    let controls = [];

    if (this.editable && this.type == 'LineString') {
      let editor = this.configureEditor();
      if (editor !== undefined) controls.push(editor);
    }

    MTK.createMap(
      this.target,
      {
        map: {
          location: defaultMapPosition,
          mapType: 'terrain_v2',
          controls: controls
        }
      },
      this.configureMap.bind(this)
    );
  }
  initEventHandlers() {
    this.container.on('dc:import:data', this.importData.bind(this));

    this.container
      .parent('.geographic')
      .siblings('.map-info')
      .first()
      .find('.longitude input, .latitude  input')
      .on('change', this.updateMapMarker.bind(this));
  }
  importData(event, data) {
    let form_fields = this.container
      .parent('.geographic')
      .siblings('.map-info')
      .first();

    if (
      form_fields.find('.form-element.elevation > input').val().length == 0 &&
      this.container
        .parent('.geographic')
        .siblings('input.location-data:hidden')
        .first()
        .val().length == 0
    ) {
      form_fields.find('.form-element.elevation > input').val(data.value.elevation);
      form_fields
        .find('.form-element.latitude > input')
        .val(data.value.y)
        .trigger('change');
      form_fields
        .find('.form-element.longitude > input')
        .val(data.value.x)
        .trigger('change');
    } else {
      var confirmationModal = new ConfirmationModal({
        text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
        confirmationText: 'Ja',
        cancelText: 'Nein',
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: function() {
          form_fields.find('.form-element.elevation > input').val(data.value.elevation);
          form_fields
            .find('.form-element.latitude > input')
            .val(data.value.y)
            .trigger('change');
          form_fields
            .find('.form-element.longitude > input')
            .val(data.value.x)
            .trigger('change');
        }.bind(this)
      });
    }
  }
  getCoordinates() {
    return {
      lng: parseFloat(
        this.container
          .parent('.geographic')
          .siblings('.map-info')
          .first()
          .find('.longitude input')
          .val()
      ),
      lat: parseFloat(
        this.container
          .parent('.geographic')
          .siblings('.map-info')
          .first()
          .find('.latitude input')
          .val()
      )
    };
  }
  updateMapMarker(event) {
    let valid = true;
    let coords = this.getCoordinates();
    Object.keys(coords).forEach(element => {
      valid = valid && !isNaN(coords[element]);
    });

    if (valid && this.marker !== undefined) {
      this.marker.setLatLng(coords);
      this.map.leaflet.setView(this.marker.getLatLng());
      this.setHiddenFieldValue(coords);
    } else if (valid && this.marker === undefined) {
      this.drawMarker(coords);
      MTK.event.removeListener(this.drawableEvent);
      this.setHiddenFieldValue(coords);
    }
  }
  configureMap(map) {
    this.map = map;

    if (this.type == 'Point' && this.value[0].length > 0) this.drawInitialMarker();
    else if (this.type == 'Point') this.drawableMarker();
    else if (this.type == 'LineString' && this.editable) {
      if (this.value[0].length > 0) this.drawInitialRoute();

      MTK.event.addListener(this.map.editor, 'update', data => {
        this.setLengthFieldValue(data.distance);
        this.setHiddenFieldValue(data.routeVertices[0]);
      });
    } else if (this.type == 'LineString' && this.value[0].length > 0) this.drawInitialLineString();
  }
  drawableMarker() {
    this.drawableEvent = MTK.event.addListener(this.map, 'click', event => {
      event.preventDefault();

      MTK.event.removeListener(this.drawableEvent);
      this.drawableEvent = undefined;

      this.drawMarker(event.latlng);
      this.setCoordinates(event.latlng);
    });
  }
  drawInitialRoute() {
    let points = this.value.map(item => [item[1], item[0]]);
    this.map.editor.setSerializedData({ routeVertices: [points] });
    this.map.leaflet.fitBounds(points);
  }
  drawInitialLineString() {
    if (
      (this.afterValue !== undefined && this.afterValue[0] !== undefined) ||
      (this.beforeValue !== undefined && this.beforeValue[0] !== undefined)
    ) {
      let points = [];
      if (this.afterValue !== undefined && this.afterValue[0] !== undefined && this.afterValue[0].length > 0) {
        let afterPoints = this.afterValue.map(item => $P(item[1], item[0]));
        points.push(afterPoints);
        this.drawLineString(afterPoints, '#90c062');
      }
      if (this.beforeValue !== undefined && this.beforeValue[0] !== undefined && this.beforeValue[0].length > 0) {
        let beforePoints = this.beforeValue.map(item => $P(item[1], item[0]));
        points.push(beforePoints);
        this.drawLineString(beforePoints, '#cc4b37');
      }
      this.map.leaflet.fitBounds(points);
    } else {
      let points = this.value.map(item => $P(item[1], item[0]));
      this.drawLineString(points);
      this.map.leaflet.fitBounds(points);
    }
  }
  drawLineString(points, color = '#1779ba') {
    let lineString = new L.Polyline(points, { color: color }).addTo(this.map.leaflet);
    let startPoint = points.shift();
    let endPoint = points.pop();

    new L.Marker(startPoint, {
      draggable: false,
      icon: L.icon({
        iconUrl: '//static.maptoolkit.net/images/editor/v8/marker/start.png',
        iconSize: [30, 40],
        iconAnchor: [15, 40]
      })
    }).addTo(this.map.leaflet);
    if (endPoint !== startPoint)
      new L.Marker(endPoint, {
        draggable: false,
        icon: L.icon({
          iconUrl: '//static.maptoolkit.net/images/editor/v8/marker/end.png',
          iconSize: [30, 40],
          iconAnchor: [15, 40]
        })
      }).addTo(this.map.leaflet);
  }
  configureEditor() {
    if (this.type == 'LineString') {
      return new MTK.Control.Editor({
        undo: true,
        upload: true,
        poi: false,
        wikipedia: false,
        elevationProfile: false,
        icons: {
          start: {
            iconUrl: '//static.maptoolkit.net/images/editor/v8/marker/start.png',
            iconSize: [30, 40],
            iconAnchor: [15, 40]
          },
          end: {
            iconUrl: '//static.maptoolkit.net/images/editor/v8/marker/end.png',
            iconSize: [30, 40],
            iconAnchor: [15, 40]
          },
          vertex: {
            iconUrl: '//static.maptoolkit.net/images/editor/v8/marker/vertex.png',
            iconSize: [10, 16],
            iconAnchor: [5, 16]
          }
        }
      });
    }
  }
  calculateCenter() {
    if (
      this.defaultPosition !== undefined &&
      this.defaultPosition.longitude !== undefined &&
      this.defaultPosition.latitude !== undefined
    ) {
      return {
        center: $P(this.defaultPosition.latitude, this.defaultPosition.longitude),
        zoom: this.defaultPosition.zoom || 7
      };
    }
  }
  drawInitialMarker() {
    if (
      (this.afterValue !== undefined && this.afterValue[0] !== undefined) ||
      (this.beforeValue !== undefined && this.beforeValue[0] !== undefined)
    ) {
      let points = [];
      if (this.afterValue !== undefined && this.afterValue[0] !== undefined && this.afterValue[0].length > 0) {
        let afterPoints = { lat: this.afterValue[0][1], lng: this.afterValue[0][0] };
        points.push(afterPoints);
        this.drawMarker(afterPoints, this.iconPaths.after);
      }
      if (this.beforeValue !== undefined && this.beforeValue[0] !== undefined && this.beforeValue[0].length > 0) {
        let beforePoints = { lat: this.beforeValue[0][1], lng: this.beforeValue[0][0] };
        points.push(beforePoints);
        this.drawMarker(beforePoints, this.iconPaths.before);
      }
      this.map.leaflet.fitBounds(points);
    } else {
      let point = { lat: this.value[0][1], lng: this.value[0][0] };
      this.drawMarker(point);
      this.map.leaflet.setView(point);
    }
  }
  drawMarker(coords, iconPath = this.iconPaths.default) {
    this.marker = new L.Marker($P(coords.lat, coords.lng), {
      draggable: this.editable,
      icon: L.icon({
        iconUrl: iconPath,
        iconAnchor: [16, 32]
      })
    })
      .addTo(this.map.leaflet)
      .on('dragend', () => {
        this.map.leaflet.setView(this.marker.getLatLng());
        this.setCoordinates(this.marker.getLatLng());
      });
  }
  setCoordinates(coords) {
    coords.lat = Number(coords.lat.toFixed(5));
    coords.lng = Number(coords.lng.toFixed(5));
    this.container
      .parent('.geographic')
      .siblings('.map-info')
      .first()
      .find('.longitude input')
      .val(coords.lng);
    this.container
      .parent('.geographic')
      .siblings('.map-info')
      .first()
      .find('.latitude input')
      .val(coords.lat);
    this.setHiddenFieldValue(coords);
  }
  setHiddenFieldValue(coords) {
    if (coords === undefined)
      this.container
        .parent('.geographic')
        .siblings('.location-data')
        .first()
        .removeAttr('value');
    else {
      let parsedCoords = coords;
      if (Array.isArray(coords)) {
        parsedCoords = coords.map(item => Number(item[1].toFixed(5)) + ' ' + Number(item[0].toFixed(5)));
      } else {
        parsedCoords = [Number(coords.lng.toFixed(5)) + ' ' + Number(coords.lat.toFixed(5))];
      }

      this.container
        .parent('.geographic')
        .siblings('.location-data')
        .first()
        .val(this.type.toUpperCase() + ' (' + parsedCoords.join(', ') + ')');
    }
  }
  setLengthFieldValue(length) {
    if (length === undefined) length = 0;
    else length = Number(length.toFixed(0));

    this.container
      .closest('.geographic.form-element')
      .siblings('.form-element.length')
      .find(':input')
      .val(length);
  }
}

module.exports = TourSprungEditor;

var ConfirmationModal = require('./confirmation_modal');
var ObjectHelpers = require('./../helpers/object_helpers');
var wkx = require('wkx');

class TourSprungEditor {
  constructor(container) {
    this.container = $(container);
    this.target = this.container.attr('id');
    this.value = this.container.data('value');
    this.beforeValue = this.container.data('before-position');
    this.afterValue = this.container.data('after-position');
    this.markerPath = this.container.data('marker-path') || [];
    this.type = this.container.data('type');
    this.iconPaths = this.container.data('icon-paths');
    this.editable = this.container.parent('.geographic').hasClass('editable');
    this.mapOptions = this.container.data('map-options');
    this.routeDataField = this.container
      .closest('.form-element')
      .find(':hidden[name="thing[datahash][route_data]"]')
      .first();
    this.defaultPosition = ObjectHelpers.select(this.mapOptions, ['latitude', 'longitude', 'zoom']);
    this.credentials = this.mapOptions.credentials;
    this.drawableEvent;
    this.marker;
    this.routeMarkers = [];
    this.map;
    this.geoCodeButton = $('.geocode-address-button');

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
          controls: controls,
          options: {
            scrollWheelZoom: false,
            gestureHandling: true
          }
        }
      },
      this.configureMap.bind(this)
    );
  }
  initEventHandlers() {
    this.container.on('dc:import:data', this.importData.bind(this));

    if (this.geoCodeButton !== undefined) this.geoCodeButton.on('click', this.initGeoCodingActions.bind(this));

    this.container
      .parent('.geographic')
      .siblings('.map-info')
      .first()
      .find('.longitude input, .latitude  input')
      .on('change', this.updateMapMarker.bind(this));
  }
  importData(event, data) {
    let form_fields = this.container.parent('.geographic').siblings('.map-info').first();

    let elevationField = form_fields.find('.form-element.elevation > input');

    if (
      ((!elevationField.val() || elevationField.val().length == 0) &&
        this.container.parent('.geographic').siblings('input.location-data:hidden').first().val().length == 0) ||
      (data && data.force)
    ) {
      elevationField.val(data.value.elevation);
      form_fields.find('.form-element.latitude > input').val(data.value.y).trigger('change');
      form_fields.find('.form-element.longitude > input').val(data.value.x).trigger('change');
    } else {
      var confirmationModal = new ConfirmationModal({
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
  getCoordinates() {
    return {
      lng: parseFloat(
        this.container.parent('.geographic').siblings('.map-info').first().find('.longitude input').val()
      ),
      lat: parseFloat(this.container.parent('.geographic').siblings('.map-info').first().find('.latitude input').val())
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

    if (this.type == 'Point' && this.value.length > 0) this.drawInitialMarker();
    else if (this.type == 'Point') this.drawableMarker();
    else if (this.type == 'LineString' && this.editable) {
      if (this.value.length > 0) this.drawInitialRoute();

      if (this.markerPath !== undefined && this.markerPath.length) {
        this.addRouteMarkerEvents();
        this.drawRouteMarkers();
      }

      MTK.event.addListener(this.map.editor, 'update', data => {
        this.setRouteDataFieldValue(data);
        this.setHiddenFieldValue(data.routeVertices[0]);
      });
    } else if (this.type == 'LineString' && this.value.length > 0) {
      this.drawInitialLineString();

      if (this.markerPath !== undefined && this.markerPath.length) this.drawRouteMarkers(undefined, 'content-tiles');
    }
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
    if (this.routeDataField !== undefined) {
      let routeData = this.routeDataField.val();
      if (routeData !== undefined) routeData = JSON.parse(routeData);
      else routeData = {};
      this.map.editor.setSerializedData(routeData);
    } else {
      let points = this.value.map(item => [item[1], item[0]]);
      this.map.editor.setSerializedData({ routeVertices: [points] });
      this.map.leaflet.fitBounds(points, { padding: [50, 50] });
    }
  }
  drawInitialLineString() {
    if (
      (this.afterValue !== undefined && this.afterValue.length) ||
      (this.beforeValue !== undefined && this.beforeValue.length)
    ) {
      let lines = [];
      if (this.afterValue !== undefined && this.afterValue.length > 0) {
        lines.push(this.drawLineString(this.afterValue, { color: '#90c062', weight: 6 }));
      }
      if (this.beforeValue !== undefined && this.beforeValue.length > 0) {
        lines.push(this.drawLineString(this.beforeValue, { color: '#cc4b37' }));
      }
      let group = new L.featureGroup(lines);
      this.map.leaflet.fitBounds(group.getBounds(), { padding: [50, 50] });
    } else {
      let line = this.drawLineString(this.value);
      this.map.leaflet.fitBounds(line.getBounds(), { padding: [50, 50] });
    }
  }
  drawLineString(wkt, options = { color: '#1779ba' }) {
    let geojson = this.wktToGeoJson(wkt);
    let line = new L.geoJSON(geojson, options);
    line.addTo(this.map.leaflet);
    let startPoint = geojson.coordinates.shift();
    let endPoint = geojson.coordinates.pop();

    new L.Marker([startPoint[1], startPoint[0]], {
      draggable: false,
      icon: L.icon({
        iconUrl: '//static.maptoolkit.net/images/editor/v8/marker/start.png',
        iconSize: [30, 40],
        iconAnchor: [15, 40]
      })
    }).addTo(this.map.leaflet);
    if (endPoint !== startPoint)
      new L.Marker([endPoint[1], endPoint[0]], {
        draggable: false,
        icon: L.icon({
          iconUrl: '//static.maptoolkit.net/images/editor/v8/marker/end.png',
          iconSize: [30, 40],
          iconAnchor: [15, 40]
        })
      }).addTo(this.map.leaflet);
    return line;
  }
  addRouteMarkerEvents() {
    let identifier =
      '.form-element.linked[data-key*="thing[datahash]"]' +
      this.markerPath.map(p => '[data-key*="[' + p + ']"]').join('');

    $(document).on('change', identifier, event => {
      event.stopPropagation();
      this.drawRouteMarkers();
    });

    let embeddedIdentifiers = [];

    this.markerPath.forEach(v => {
      embeddedIdentifiers.push(
        (embeddedIdentifiers[embeddedIdentifiers.length - 1] || '') + '[data-key*="[' + v + ']"]'
      );
    });

    embeddedIdentifiers.forEach(v => {
      $(document).on(
        'dc:html:remove',
        '.embedded-object[data-key*="thing[datahash]"]' + v + ' > .content-object-item',
        event => {
          event.stopPropagation();
          this.drawRouteMarkers(event.currentTarget);
        }
      );
    });
  }
  drawRouteMarkers(except = undefined, parentClass = 'media-thumbs') {
    this.routeMarkers.forEach(m => m.remove());

    let markerIdentifier =
      '.' +
      parentClass +
      ' [data-location-for*="thing[datahash]"]' +
      this.markerPath.map(p => '[data-location-for*="[' + p + ']"]').join('');

    let markers = $(markerIdentifier);

    if (except !== undefined) markers = markers.not($(except).find(markerIdentifier));

    let points = [];

    if (this.value.length) {
      let geoJsonCoords = this.wktToGeoJson(this.value).coordinates;
      points = geoJsonCoords.map(item => [item[1], item[0]]);
    }

    if (markers.length) {
      markers.each((_, v) => {
        let coords = $(v).data('location-data');
        points.push([coords.lat, coords.lng]);

        this.routeMarkers.push(
          new L.Marker($P(coords.lat, coords.lng), {
            draggable: false,
            icon: L.icon({
              iconUrl: this.iconPaths.default,
              iconAnchor: [16, 32]
            })
          }).addTo(this.map.leaflet)
        );
      });
    }

    if (points.length) this.map.leaflet.fitBounds(points, { padding: [50, 50] });
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
      (this.afterValue !== undefined && this.afterValue.length) ||
      (this.beforeValue !== undefined && this.beforeValue.length)
    ) {
      let points = [];
      if (this.afterValue !== undefined && this.afterValue.length > 0) {
        let coords = this.wktToGeoJson(this.afterValue).coordinates;
        let afterPoints = { lat: coords[1], lng: coords[0] };
        points.push(afterPoints);
        this.drawMarker(afterPoints, this.iconPaths.after);
      }
      if (this.beforeValue !== undefined && this.beforeValue.length > 0) {
        let coords = this.wktToGeoJson(this.beforeValue).coordinates;
        let beforePoints = { lat: coords[1], lng: coords[0] };
        points.push(beforePoints);
        this.drawMarker(beforePoints, this.iconPaths.before);
      }
      this.map.leaflet.fitBounds(points, { padding: [50, 50] });
    } else {
      let coords = this.wktToGeoJson(this.value).coordinates;
      let point = { lat: coords[1], lng: coords[0] };
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
    this.container.parent('.geographic').siblings('.map-info').first().find('.longitude input').val(coords.lng);
    this.container.parent('.geographic').siblings('.map-info').first().find('.latitude input').val(coords.lat);
    this.setHiddenFieldValue(coords);
  }
  setHiddenFieldValue(coords) {
    if (coords === undefined) {
      this.container.parent('.geographic').siblings('.location-data').first().removeAttr('value');
      this.value = undefined;
    } else {
      let parsedCoords = coords;
      if (Array.isArray(coords)) {
        parsedCoords = coords.map(item => Number(item[1].toFixed(5)) + ' ' + Number(item[0].toFixed(5)));
        this.value = coords.map(item => [item[1], item[0]]);
      } else {
        parsedCoords = [Number(coords.lng.toFixed(5)) + ' ' + Number(coords.lat.toFixed(5))];
        this.value = [coords.lat, coords.lng];
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

    this.container.closest('.geographic.form-element').siblings('.form-element.length').find(':input').val(length);
  }
  setRouteDataFieldValue(data) {
    if (data === undefined) data = {};

    if (this.routeDataField === undefined || !this.routeDataField.length) {
      let routeField = '<input type="hidden" name="thing[datahash][route_data]">';
      this.routeDataField = $(routeField).appendTo(this.container.closest('.geographic.form-element'));
    }

    this.routeDataField.val(JSON.stringify(data));
  }
  wktToGeoJson(wkt) {
    return wkx.Geometry.parse(wkt).toGeoJSON();
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
        } else if (data && data.length == 2 && this.marker !== undefined) {
          this.marker.setLatLng({ lng: data[0], lat: data[1] });
          this.map.leaflet.setView(this.marker.getLatLng());
          this.setCoordinates(this.marker.getLatLng());
        } else if (data && data.length == 2 && this.marker === undefined) {
          this.drawMarker({ lng: data[0], lat: data[1] });
          this.map.leaflet.setView(this.marker.getLatLng());
          this.setCoordinates(this.marker.getLatLng());
        }
      })
      .fail((jqxhr, textStatus, error) => {
        console.log(textStatus + ', ' + error);
      })
      .always(() => {
        $(event.currentTarget).find('i.fa').remove();
      });
  }
}

module.exports = TourSprungEditor;

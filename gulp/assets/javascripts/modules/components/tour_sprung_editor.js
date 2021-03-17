var OpenLayersEditor = require('./open_layers_editor');
var wkx = require('wkx');

class TourSprungEditor extends OpenLayersEditor {
  constructor(container) {
    super(container);

    this.credentials = this.mapOptions.credentials;
    this.drawableEvent;
    this.routeMarkers = [];
    this.map;
    this.toursrpungIcons = {
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
    };
  }
  setup() {
    this.transformInitialValue();
    MTK.init({ apiKey: this.credentials.api_key });
    this.initMap();
    this.initEventHandlers();
  }
  initMap() {
    let defaultMapPosition = this.calculateCenter();
    let controls = [];

    if (this.isLineString()) {
      let editor = this.configureEditor();
      if (editor !== undefined) controls.push(editor);
    }

    MTK.createMap(
      this.containerId,
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
  transformInitialValue() {
    if (!this.value && !this.value.length) this.value = null;
    else {
      let geoJson = this.wktToGeoJson(this.value);
      if (geoJson.coordinates && geoJson.coordinates.length) this.value = geoJson;
    }
  }
  initEventHandlers() {
    this.$container.on('dc:import:data', this.importData.bind(this));

    if (this.isPoint()) {
      if (this.$geoCodeButton) this.$geoCodeButton.on('click', this.initGeoCodingActions.bind(this));

      this.$latitudeField.on('change', this.updateMapMarker.bind(this));
      this.$longitudeField.on('change', this.updateMapMarker.bind(this));
    }
  }
  updateMapMarker(_event) {
    let valid = true;
    let geoJson = this.getGeoJsonFromInputs();
    geoJson.coordinates.forEach(element => {
      valid = valid && !isNaN(element);
    });

    if (valid && this.feature) {
      this.feature.setLatLng(L.GeoJSON.coordsToLatLng(geoJson.coordinates));
    } else if (valid && !this.feature) {
      this.drawMarker(L.GeoJSON.coordsToLatLng(geoJson.coordinates));
      MTK.event.removeListener(this.drawableEvent);
    } else if (this.feature) {
      this.feature.remove();
      this.feature = undefined;
      this.drawableMarker();
    }

    this.setNewCoordinates();
  }
  configureMap(map) {
    this.map = map;

    if (this.isPoint() && this.value) this.drawInitialMarker();
    else if (this.isPoint()) this.drawableMarker();
    else if (this.isLineString()) {
      if (this.value) this.drawInitialRoute();

      MTK.event.addListener(this.map.editor, 'update', data => {
        let coords = this.reverseCoordinates(data.routeVertices);
        this.setHiddenFieldValue({ type: 'MultiLineString', coordinates: coords });
      });
    }

    if (this.additionalValues && this.additionalValues.length) this.drawAdditionalFeatures();
  }
  reverseCoordinates(coords) {
    for (let i = 0; i < coords.length; i++) {
      if (Array.isArray(coords[i]) && coords[i].length == 2 && !Array.isArray(coords[i][0])) coords[i].reverse();
      else if (Array.isArray(coords[i])) coords[i] = this.reverseCoordinates(coords[i]);
      else coords[i] = Number(coords[i].toFixed(5));
    }

    return coords;
  }
  drawableMarker() {
    this.drawableEvent = MTK.event.addListener(this.map, 'click', event => {
      event.preventDefault();

      MTK.event.removeListener(this.drawableEvent);
      this.drawableEvent = undefined;

      this.drawMarker(event.latlng);
      this.setNewCoordinates();
    });
  }
  drawInitialMarker() {
    let coords = L.GeoJSON.coordsToLatLng(this.value.coordinates);
    this.drawMarker(coords);
    this.map.leaflet.fitBounds([coords], { padding: [50, 50], maxZoom: 15 });
  }
  drawInitialRoute() {
    let coords = L.GeoJSON.coordsToLatLngs(this.value.coordinates, this.value.type.startsWith('Multi') ? 1 : 0);
    this.map.editor.setSerializedData({ routeVertices: coords });
    this.map.leaflet.fitBounds(coords, { padding: [50, 50], maxZoom: 15 });
  }
  drawMarker(coords) {
    this.feature = new L.Marker($P(coords.lat, coords.lng), {
      draggable: true,
      icon: L.icon({
        iconUrl: this.icons.default.interpolate({ markerColor: escape(this.markerColors['default']) }),
        iconAnchor: [16, 32]
      })
    })
      .addTo(this.map.leaflet)
      .on('dragend', () => {
        this.setNewCoordinates();
      });
  }
  drawFeature(geoJson) {
    L.geoJSON(geoJson, {
      style: {
        color: '#1779ba'
      },
      pointToLayer: (_feature, latlng) => {
        return new L.Marker(latlng, {
          draggable: false,
          icon: L.icon({
            iconUrl: this.icons.default.interpolate({ markerColor: escape(this.markerColors['default']) }),
            iconAnchor: [16, 32]
          })
        });
      }
    }).addTo(this.map.leaflet);
  }
  drawAdditionalFeatures() {
    this.additionalValues.forEach(additionalFeature => {
      this.drawFeature(this.wktToGeoJson(additionalFeature));
    });
  }
  configureEditor() {
    if (this.isLineString()) {
      return new MTK.Control.Editor({
        undo: true,
        upload: this.uploadable,
        poi: false,
        wikipedia: false,
        elevationProfile: false,
        icons: this.toursrpungIcons
      });
    }
  }
  calculateCenter() {
    if (this.defaultPosition && this.defaultPosition.longitude && this.defaultPosition.latitude) {
      return {
        center: $P(this.defaultPosition.latitude, this.defaultPosition.longitude),
        zoom: this.defaultPosition.zoom || 10
      };
    }
  }
  getFeatureLatLon() {
    let coords = this.feature.getLatLng();
    return this.shortenCoordinates([coords.lng, coords.lat]);
  }
  getGeoJsonFromFeature() {
    if (!this.feature) return;

    return {
      type: this.type,
      coordinates: this.getFeatureLatLon()
    };
  }
  setNewCoordinates() {
    this.setCoordinates();
    this.setHiddenFieldValue(this.getGeoJsonFromFeature());

    if (this.feature) this.map.leaflet.setView(this.feature.getLatLng());
  }
  setCoordinates() {
    if (!this.feature || this.type != 'Point') return;

    const latLon = this.getFeatureLatLon();
    this.$latitudeField.val(latLon[1]);
    this.$longitudeField.val(latLon[0]);
  }
  setHiddenFieldValue(geoJSON) {
    this.value = geoJSON;
    super.setHiddenFieldValue(geoJSON);
  }
  setLengthFieldValue(length) {
    if (length === undefined) length = 0;
    else length = Number(length.toFixed(0));

    this.$container.closest('.geographic.form-element').siblings('.form-element.length').find(':input').val(length);
  }
  wktToGeoJson(wkt) {
    return wkx.Geometry.parse(wkt).toGeoJSON();
  }
  setGeocodedValue(data) {
    if (!this.feature) this.drawMarker({ lng: data[0], lat: data[1] });
    else this.feature.setLatLng({ lng: data[0], lat: data[1] });

    this.setNewCoordinates();
  }
}

module.exports = TourSprungEditor;

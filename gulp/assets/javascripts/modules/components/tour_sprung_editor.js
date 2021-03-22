const OpenLayersEditor = require('./open_layers_editor');

class TourSprungEditor extends OpenLayersEditor {
  constructor(container) {
    super(container);

    this.credentials = this.mapOptions.credentials;
    this.drawableEvent;
    this.routeMarkers = [];
    this.map;
    this.toursrpungIcons = {
      start: {
        iconUrl: this.icons.start.interpolate({ color: escape(this.colors.default) }),
        iconSize: [21, 33],
        iconAnchor: [10, 33]
      },
      end: {
        iconUrl: this.icons.end.interpolate({ color: escape(this.colors.default) }),
        iconSize: [21, 33],
        iconAnchor: [10, 33]
      },
      vertex: {
        iconUrl:
          'data:image/svg+xml;utf8,<svg width="0" height="0" version="1.1" viewBox="0 0 0 0" xmlns="http://www.w3.org/2000/svg"></svg>'
      }
    };
  }
  setup() {
    MTK.init({ apiKey: this.credentials.api_key });
    this.initMap();
    this.initEventHandlers();
  }
  initMap() {
    let controls = [];

    if (this.isLineString()) {
      let editor = this.configureEditor();
      if (editor !== undefined) controls.push(editor);
    }

    MTK.createMap(
      this.containerId,
      {
        map: {
          location: this.defaultView(),
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
    this.$container.on('dc:import:data', this.importData.bind(this));

    if (this.isPoint()) {
      if (this.$geoCodeButton) this.$geoCodeButton.on('click', this.geoCodeAddress.bind(this));

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
      this.drawMarkerFeature(L.GeoJSON.coordsToLatLng(geoJson.coordinates));
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

      this.initMtkEvents();
    }

    if (this.additionalValues && this.additionalValues.length) this.drawAdditionalFeatures();
    this.updateMapPosition();
  }
  initMtkEvents() {
    MTK.event.addListener(this.map.editor, 'update', data => {
      this.setMtkLineStyle();
      this.feature = this.map.editor._polyline();
      let coords = this.reverseCoordinates(data.routeVertices);
      this.setHiddenFieldValue({ type: 'MultiLineString', coordinates: coords });
    });
  }
  setMtkLineStyle() {
    this.map.editor._polyline().setStyle({
      color: this.colors.default,
      opacity: 1,
      weight: 5
    });
  }
  reverseCoordinates(coords, removeZAt = 2) {
    for (let i = 0; i < coords.length; i++) {
      if (Array.isArray(coords[i]) && coords[i].length == 2 && !Array.isArray(coords[i][0])) coords[i].reverse();
      else if (Array.isArray(coords[i]) && coords[i].length == 3 && !Array.isArray(coords[i][0])) {
        coords[i].splice(removeZAt, 1);
        coords[i].reverse();
      } else if (Array.isArray(coords[i])) coords[i] = this.reverseCoordinates(coords[i]);
      else coords[i] = Number(coords[i].toFixed(this.precision));
    }

    return coords;
  }
  drawableMarker() {
    this.drawableEvent = MTK.event.addListener(this.map, 'click', event => {
      event.preventDefault();

      MTK.event.removeListener(this.drawableEvent);
      this.drawableEvent = undefined;

      this.drawMarkerFeature(event.latlng);
      this.setNewCoordinates();
    });
  }
  drawInitialMarker() {
    let coords = L.GeoJSON.coordsToLatLng(this.value.geometry.coordinates);
    this.drawMarkerFeature(coords);
  }
  drawInitialRoute() {
    let coords = L.GeoJSON.coordsToLatLngs(
      this.value.geometry.coordinates,
      this.value.geometry.type.startsWith('Multi') ? 1 : 0
    );
    this.map.editor.setSerializedData({ routeVertices: coords });
    this.setMtkLineStyle();
    this.feature = this.map.editor._polyline();
  }
  drawMarkerFeature(coords) {
    this.feature = this.singleMarker(coords, true)
      .addTo(this.map.leaflet)
      .on('dragend', () => {
        this.setNewCoordinates();
      });
  }
  singleMarker(latlng, draggable = false) {
    return new L.Marker(latlng, {
      draggable: draggable,
      icon: L.icon({
        iconUrl: this.icons.default.interpolate({ color: escape(this.colors.default) }),
        iconAnchor: [16, 32],
        popupAnchor: [0, 38]
      })
    });
  }
  drawFeatureFromGeoJson(geoJson) {
    return L.geoJSON(geoJson, {
      style: {
        color: this.colors.default,
        opacity: 1,
        weight: 5
      },
      pointToLayer: (_feature, latlng) => this.singleMarker(latlng),
      onEachFeature: (feature, layer) => {
        this.additionalFeatures.push(layer);
        if (feature && feature.properties && feature.properties.thingPath)
          layer.bindPopup(this.showInfoOverlay.bind(this));
      }
    }).addTo(this.map.leaflet);
  }
  showInfoOverlay(layer) {
    return this.infoOverlayHtml(layer.feature.properties);
  }
  drawAdditionalFeatures() {
    this.drawFeatureFromGeoJson({
      type: 'FeatureCollection',
      features: this.additionalValues
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
  defaultView() {
    const viewOptions = {
      zoom: 7,
      center: [47.69642, 13.34576]
    };

    if (this.defaultPosition && this.defaultPosition.zoom) viewOptions.zoom = this.defaultPosition.zoom;
    if (this.defaultPosition && this.defaultPosition.longitude && this.defaultPosition.latitude)
      viewOptions.center = [this.defaultPosition.latitude, this.defaultPosition.longitude];

    return viewOptions;
  }
  getFeatureLatLon() {
    let coords = this.feature.getLatLng();
    return this.shortenCoordinates([coords.lng, coords.lat]);
  }
  getGeoJsonFromFeature() {
    if (!this.feature) return;

    let geometry = this.feature.toGeoJSON(this.precision).geometry;
    geometry.coordinates = this.shortenCoordinates(geometry.coordinates);

    return geometry;
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
  setHiddenFieldValue(geometry) {
    this.value = geometry;
    super.setHiddenFieldValue(geometry);
  }
  setGeocodedValue(data) {
    if (!this.feature) this.drawMarkerFeature({ lng: data[0], lat: data[1] });
    else this.feature.setLatLng({ lng: data[0], lat: data[1] });

    this.setNewCoordinates();
  }
  updateMapPosition() {
    let featureGroup = L.featureGroup();
    if (this.feature) featureGroup.addLayer(this.feature);
    if (this.additionalFeatures && this.additionalFeatures.length)
      this.additionalFeatures.forEach(feature => featureGroup.addLayer(feature));

    if (featureGroup.getLayers().length)
      this.map.leaflet.fitBounds(featureGroup.getBounds(), { padding: [50, 50], maxZoom: 15 });
  }
}

module.exports = TourSprungEditor;
